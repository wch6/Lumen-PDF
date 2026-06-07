import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../models/reader_models.dart';
import 'app_data_paths.dart';

class ReaderDatabase {
  ReaderDatabase(this._appDb, this._fileDb) {
    _initializeAppCache();
    _initializeFileData();
  }

  factory ReaderDatabase.inMemory() {
    return ReaderDatabase(sqlite3.openInMemory(), sqlite3.openInMemory());
  }

  static Future<ReaderDatabase> openDefault() async {
    final appDir = await AppDataPaths.appDirectory();
    return ReaderDatabase(
      sqlite3.open(p.join(appDir.path, 'software_cache.sqlite')),
      sqlite3.open(p.join(appDir.path, 'file_data.sqlite')),
    );
  }

  final Database _appDb;
  final Database _fileDb;

  void dispose() {
    _appDb.close();
    _fileDb.close();
  }

  void _configure(Database db) {
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA foreign_keys = ON;');
  }

  void _initializeAppCache() {
    _configure(_appDb);
    _appDb.execute('''
CREATE TABLE IF NOT EXISTS recent_files (
  path TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  file_hash TEXT,
  size INTEGER,
  last_page INTEGER NOT NULL DEFAULT 1,
  position_json TEXT,
  opened_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recent_files_opened_at
  ON recent_files(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_recent_files_file_hash
  ON recent_files(file_hash);
''');
    _ensureColumn(_appDb, 'recent_files', 'position_json', 'TEXT');
  }

  void _initializeFileData() {
    _configure(_fileDb);
    _fileDb.execute('''
CREATE TABLE IF NOT EXISTS documents (
  hash TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  last_path TEXT,
  size INTEGER,
  page_count INTEGER,
  last_page INTEGER NOT NULL DEFAULT 1,
  position_json TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  file_hash TEXT NOT NULL,
  page INTEGER NOT NULL,
  text TEXT NOT NULL,
  x REAL,
  y REAL,
  highlight_id TEXT,
  color_value INTEGER NOT NULL DEFAULT 1728046172,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(file_hash) REFERENCES documents(hash) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS highlights (
  id TEXT PRIMARY KEY,
  file_hash TEXT NOT NULL,
  page INTEGER NOT NULL,
  text TEXT NOT NULL,
  color_value INTEGER NOT NULL,
  rects_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(file_hash) REFERENCES documents(hash) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notes_file_hash
  ON notes(file_hash, page);
CREATE INDEX IF NOT EXISTS idx_notes_file_hash_highlight_id
  ON notes(file_hash, highlight_id)
  WHERE highlight_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_highlights_file_hash
  ON highlights(file_hash, page);
CREATE INDEX IF NOT EXISTS idx_documents_updated_at
  ON documents(updated_at DESC);
''');
    _ensureColumn(_fileDb, 'documents', 'position_json', 'TEXT');
    _ensureColumn(_fileDb, 'notes', 'x', 'REAL');
    _ensureColumn(_fileDb, 'notes', 'y', 'REAL');
    _ensureColumn(_fileDb, 'notes', 'highlight_id', 'TEXT');
    _ensureColumn(
      _fileDb,
      'notes',
      'color_value',
      'INTEGER NOT NULL DEFAULT 1728046172',
    );
  }

  void _ensureColumn(
    Database db,
    String table,
    String column,
    String declaration,
  ) {
    final rows = db.select('PRAGMA table_info($table);');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      db.execute('ALTER TABLE $table ADD COLUMN $column $declaration;');
    }
  }

  Future<List<RecentDocument>> loadRecent({int limit = 8}) async {
    final rows = _appDb.select(
      '''
SELECT path, name, file_hash, size, last_page, position_json, opened_at
FROM recent_files
ORDER BY opened_at DESC
LIMIT ?
''',
      [limit],
    );
    return [
      for (final row in rows)
        RecentDocument(
          name: row['name'] as String,
          path: row['path'] as String,
          size: row['size'] as int?,
          page: row['last_page'] as int? ?? 1,
          openedAt: _fromMillis(row['opened_at']),
          fileHash: row['file_hash'] as String?,
          position: ReaderPosition.tryDecode(row['position_json']),
        ),
    ];
  }

  Future<ReaderPosition?> loadDocumentPosition(String fileHash) async {
    final rows = _fileDb.select(
      '''
SELECT last_page, position_json
FROM documents
WHERE hash = ?
LIMIT 1
''',
      [fileHash],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return ReaderPosition.tryDecode(row['position_json']) ??
        ReaderPosition(page: row['last_page'] as int? ?? 1);
  }

  Future<void> recordOpen({
    required PdfSource source,
    required String fileHash,
    required int page,
    int? pageCount,
    ReaderPosition? position,
  }) async {
    final now = _now();
    final positionJson = position?.encode();
    _fileDb.execute('BEGIN IMMEDIATE;');
    _appDb.execute('BEGIN IMMEDIATE;');
    try {
      _fileDb.execute(
        '''
INSERT INTO documents (
  hash, name, last_path, size, page_count, last_page, position_json, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(hash) DO UPDATE SET
  name = excluded.name,
  last_path = excluded.last_path,
  size = excluded.size,
  page_count = COALESCE(excluded.page_count, documents.page_count),
  last_page = excluded.last_page,
  position_json = COALESCE(excluded.position_json, documents.position_json),
  updated_at = excluded.updated_at
''',
        [
          fileHash,
          source.name,
          source.path,
          source.size,
          pageCount,
          page,
          positionJson,
          now,
          now,
        ],
      );

      final path = source.path;
      if (path != null && path.isNotEmpty) {
        _appDb.execute(
          '''
INSERT INTO recent_files (
  path, name, file_hash, size, last_page, position_json, opened_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(path) DO UPDATE SET
  name = excluded.name,
  file_hash = excluded.file_hash,
  size = excluded.size,
  last_page = excluded.last_page,
  position_json = COALESCE(excluded.position_json, recent_files.position_json),
  opened_at = excluded.opened_at
''',
          [path, source.name, fileHash, source.size, page, positionJson, now],
        );
      }
      _fileDb.execute('COMMIT;');
      _appDb.execute('COMMIT;');
    } catch (_) {
      _rollback(_fileDb);
      _rollback(_appDb);
      rethrow;
    }
  }

  Future<void> updateReadPosition({
    required PdfSource source,
    required int page,
    int? pageCount,
    ReaderPosition? position,
  }) async {
    final fileHash = source.hash;
    if (fileHash == null || fileHash.isEmpty) {
      return;
    }
    final now = _now();
    final positionJson = position?.encode();
    _fileDb.execute(
      '''
UPDATE documents
SET last_page = ?, page_count = COALESCE(?, page_count),
    position_json = COALESCE(?, position_json), updated_at = ?
WHERE hash = ?
''',
      [page, pageCount, positionJson, now, fileHash],
    );
    final path = source.path;
    if (path != null && path.isNotEmpty) {
      _appDb.execute(
        '''
UPDATE recent_files
SET last_page = ?, opened_at = ?, file_hash = ?,
    position_json = COALESCE(?, position_json)
WHERE path = ?
''',
        [page, now, fileHash, positionJson, path],
      );
    }
  }

  Future<List<FileDataSummary>> listFileData() async {
    final rows = _fileDb.select('''
SELECT hash, name, last_path, size, page_count, updated_at
FROM documents
ORDER BY updated_at DESC
''');
    return [
      for (final row in rows)
        FileDataSummary(
          hash: row['hash'] as String,
          name: row['name'] as String,
          lastPath: row['last_path'] as String?,
          size: row['size'] as int?,
          pageCount: row['page_count'] as int?,
          type: 'PDF',
          updatedAt: _fromMillis(row['updated_at']),
        ),
    ];
  }

  Future<void> deleteRecent(String path) async {
    _appDb.execute('DELETE FROM recent_files WHERE path = ?', [path]);
  }

  Future<void> clearRecent() async {
    _appDb.execute('DELETE FROM recent_files;');
  }

  Future<List<PageNote>> loadNotes(String fileHash) async {
    final rows = _fileDb.select(
      '''
SELECT id, page, text, x, y, highlight_id, color_value, created_at, updated_at
FROM notes
WHERE file_hash = ?
ORDER BY page ASC, y ASC, x ASC, created_at ASC
''',
      [fileHash],
    );
    return [
      for (final row in rows)
        PageNote(
          id: row['id'] as String,
          page: row['page'] as int? ?? 1,
          text: row['text'] as String,
          x: (row['x'] as num?)?.toDouble(),
          y: (row['y'] as num?)?.toDouble(),
          highlightId: row['highlight_id'] as String?,
          colorValue: row['color_value'] as int? ?? 0x66FFE45C,
          createdAt: _fromMillis(row['created_at']),
          updatedAt: _fromMillis(row['updated_at']),
        ),
    ];
  }

  Future<void> saveNotes(String fileHash, List<PageNote> notes) async {
    _fileDb.execute('BEGIN IMMEDIATE;');
    PreparedStatement? statement;
    try {
      final noteIds = {for (final note in notes) note.id};
      if (noteIds.isEmpty) {
        _fileDb.execute('DELETE FROM notes WHERE file_hash = ?', [fileHash]);
      } else {
        final existingRows = _fileDb.select(
          'SELECT id FROM notes WHERE file_hash = ?',
          [fileHash],
        );
        final staleIds = [
          for (final row in existingRows)
            if (!noteIds.contains(row['id'])) row['id'] as String,
        ];
        if (staleIds.isNotEmpty) {
          final placeholders = List.filled(staleIds.length, '?').join(', ');
          _fileDb.execute(
            'DELETE FROM notes WHERE file_hash = ? AND id IN ($placeholders)',
            [fileHash, ...staleIds],
          );
        }

        statement = _fileDb.prepare('''
INSERT INTO notes (
  id, file_hash, page, text, x, y, highlight_id, color_value, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  file_hash = excluded.file_hash,
  page = excluded.page,
  text = excluded.text,
  x = excluded.x,
  y = excluded.y,
  highlight_id = excluded.highlight_id,
  color_value = excluded.color_value,
  created_at = excluded.created_at,
  updated_at = excluded.updated_at
''');
        for (final note in notes) {
          final createdAt = note.createdAt.millisecondsSinceEpoch;
          final updatedAt =
              (note.updatedAt ?? note.createdAt).millisecondsSinceEpoch;
          statement.execute([
            note.id,
            fileHash,
            note.page,
            note.text,
            note.x,
            note.y,
            note.highlightId,
            note.colorValue,
            createdAt,
            updatedAt,
          ]);
        }
      }
      _fileDb.execute('COMMIT;');
    } catch (_) {
      _rollback(_fileDb);
      rethrow;
    } finally {
      statement?.close();
    }
  }

  Future<List<TextHighlight>> loadHighlights(String fileHash) async {
    final rows = _fileDb.select(
      '''
SELECT id, page, text, color_value, rects_json, created_at
FROM highlights
WHERE file_hash = ?
ORDER BY created_at DESC
''',
      [fileHash],
    );
    return [
      for (final row in rows)
        TextHighlight(
          id: row['id'] as String,
          page: row['page'] as int? ?? 1,
          text: row['text'] as String? ?? '',
          colorValue: row['color_value'] as int? ?? 0x66FFE45C,
          rects: _decodeRects(row['rects_json'] as String? ?? '[]'),
          createdAt: _fromMillis(row['created_at']),
        ),
    ].where((item) => item.rects.isNotEmpty).toList();
  }

  Future<void> saveHighlights(
    String fileHash,
    List<TextHighlight> highlights,
  ) async {
    _fileDb.execute('BEGIN IMMEDIATE;');
    final statement = _fileDb.prepare('''
INSERT INTO highlights (
  id, file_hash, page, text, color_value, rects_json, created_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
''');
    try {
      _fileDb.execute('DELETE FROM highlights WHERE file_hash = ?', [fileHash]);
      for (final highlight in highlights) {
        statement.execute([
          highlight.id,
          fileHash,
          highlight.page,
          highlight.text,
          highlight.colorValue,
          jsonEncode(highlight.rects.map((rect) => rect.toJson()).toList()),
          highlight.createdAt.millisecondsSinceEpoch,
        ]);
      }
      _fileDb.execute('COMMIT;');
    } catch (_) {
      _rollback(_fileDb);
      rethrow;
    } finally {
      statement.close();
    }
  }

  Future<void> clearFileData() async {
    _fileDb.execute('BEGIN IMMEDIATE;');
    _appDb.execute('BEGIN IMMEDIATE;');
    try {
      _fileDb.execute('DELETE FROM highlights;');
      _fileDb.execute('DELETE FROM notes;');
      _fileDb.execute('DELETE FROM documents;');
      _appDb.execute(
        'UPDATE recent_files SET file_hash = NULL, last_page = 1, position_json = NULL;',
      );
      _fileDb.execute('COMMIT;');
      _appDb.execute('COMMIT;');
    } catch (_) {
      _rollback(_fileDb);
      _rollback(_appDb);
      rethrow;
    }
  }

  Future<void> deleteFileDataByHashes(Set<String> hashes) async {
    if (hashes.isEmpty) {
      return;
    }
    final placeholders = List.filled(hashes.length, '?').join(', ');
    final args = hashes.toList();
    _fileDb.execute('BEGIN IMMEDIATE;');
    _appDb.execute('BEGIN IMMEDIATE;');
    try {
      _fileDb.execute(
        'DELETE FROM documents WHERE hash IN ($placeholders);',
        args,
      );
      _appDb.execute('''
UPDATE recent_files
SET file_hash = NULL, last_page = 1, position_json = NULL
WHERE file_hash IN ($placeholders);
''', args);
      _fileDb.execute('COMMIT;');
      _appDb.execute('COMMIT;');
    } catch (_) {
      _rollback(_fileDb);
      _rollback(_appDb);
      rethrow;
    }
  }

  List<HighlightRect> _decodeRects(String raw) {
    try {
      final data = jsonDecode(raw) as List;
      return data.map(HighlightRect.tryDecode).nonNulls.toList();
    } catch (_) {
      return const [];
    }
  }

  void _rollback(Database db) {
    try {
      db.execute('ROLLBACK;');
    } catch (_) {}
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  DateTime _fromMillis(Object? raw) {
    final millis = raw is int ? raw : 0;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
