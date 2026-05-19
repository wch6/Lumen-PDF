import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/reader_models.dart';

class ReaderDatabase {
  ReaderDatabase(this._db) {
    _initialize();
  }

  factory ReaderDatabase.inMemory() {
    return ReaderDatabase(sqlite3.openInMemory());
  }

  static Future<ReaderDatabase> openDefault() async {
    final supportDir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(supportDir.path, 'pdf_reader'));
    await appDir.create(recursive: true);
    return ReaderDatabase(sqlite3.open(p.join(appDir.path, 'reader.sqlite')));
  }

  final Database _db;

  void dispose() {
    _db.close();
  }

  void _initialize() {
    _db.execute('PRAGMA journal_mode = WAL;');
    _db.execute('PRAGMA synchronous = NORMAL;');
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('''
CREATE TABLE IF NOT EXISTS documents (
  hash TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  last_path TEXT,
  size INTEGER,
  page_count INTEGER,
  last_page INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS recent_files (
  path TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  file_hash TEXT,
  size INTEGER,
  last_page INTEGER NOT NULL DEFAULT 1,
  opened_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  file_hash TEXT NOT NULL,
  page INTEGER NOT NULL,
  text TEXT NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_recent_files_opened_at
  ON recent_files(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_file_hash
  ON notes(file_hash, page);
CREATE INDEX IF NOT EXISTS idx_highlights_file_hash
  ON highlights(file_hash, page);
''');
  }

  Future<List<RecentDocument>> loadRecent({int limit = 8}) async {
    final rows = _db.select(
      '''
SELECT path, name, file_hash, size, last_page, opened_at
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
        ),
    ];
  }

  Future<void> recordOpen({
    required PdfSource source,
    required String fileHash,
    required int page,
    int? pageCount,
  }) async {
    final now = _now();
    _db.execute('BEGIN IMMEDIATE;');
    try {
      _db.execute(
        '''
INSERT INTO documents (
  hash, name, last_path, size, page_count, last_page, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(hash) DO UPDATE SET
  name = excluded.name,
  last_path = excluded.last_path,
  size = excluded.size,
  page_count = COALESCE(excluded.page_count, documents.page_count),
  last_page = excluded.last_page,
  updated_at = excluded.updated_at
''',
        [
          fileHash,
          source.name,
          source.path,
          source.size,
          pageCount,
          page,
          now,
          now,
        ],
      );

      final path = source.path;
      if (path != null && path.isNotEmpty) {
        _db.execute(
          '''
INSERT INTO recent_files (
  path, name, file_hash, size, last_page, opened_at
) VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(path) DO UPDATE SET
  name = excluded.name,
  file_hash = excluded.file_hash,
  size = excluded.size,
  last_page = excluded.last_page,
  opened_at = excluded.opened_at
''',
          [path, source.name, fileHash, source.size, page, now],
        );
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<void> updateReadPosition({
    required PdfSource source,
    required int page,
    int? pageCount,
  }) async {
    final fileHash = source.hash;
    if (fileHash == null || fileHash.isEmpty) {
      return;
    }
    final now = _now();
    _db.execute(
      '''
UPDATE documents
SET last_page = ?, page_count = COALESCE(?, page_count), updated_at = ?
WHERE hash = ?
''',
      [page, pageCount, now, fileHash],
    );
    final path = source.path;
    if (path != null && path.isNotEmpty) {
      _db.execute(
        '''
UPDATE recent_files
SET last_page = ?, opened_at = ?, file_hash = ?
WHERE path = ?
''',
        [page, now, fileHash, path],
      );
    }
  }

  Future<List<PageNote>> loadNotes(String fileHash) async {
    final rows = _db.select(
      '''
SELECT id, page, text, created_at
FROM notes
WHERE file_hash = ?
ORDER BY created_at DESC
''',
      [fileHash],
    );
    return [
      for (final row in rows)
        PageNote(
          id: row['id'] as String,
          page: row['page'] as int? ?? 1,
          text: row['text'] as String,
          createdAt: _fromMillis(row['created_at']),
        ),
    ];
  }

  Future<void> saveNotes(String fileHash, List<PageNote> notes) async {
    _db.execute('BEGIN IMMEDIATE;');
    final statement = _db.prepare('''
INSERT INTO notes (
  id, file_hash, page, text, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?)
''');
    try {
      _db.execute('DELETE FROM notes WHERE file_hash = ?', [fileHash]);
      for (final note in notes) {
        final createdAt = note.createdAt.millisecondsSinceEpoch;
        statement.execute([
          note.id,
          fileHash,
          note.page,
          note.text,
          createdAt,
          createdAt,
        ]);
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    } finally {
      statement.close();
    }
  }

  Future<List<TextHighlight>> loadHighlights(String fileHash) async {
    final rows = _db.select(
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
          colorValue: row['color_value'] as int? ?? 0x66FFE066,
          rects: _decodeRects(row['rects_json'] as String? ?? '[]'),
          createdAt: _fromMillis(row['created_at']),
        ),
    ].where((item) => item.rects.isNotEmpty).toList();
  }

  Future<void> saveHighlights(
    String fileHash,
    List<TextHighlight> highlights,
  ) async {
    _db.execute('BEGIN IMMEDIATE;');
    final statement = _db.prepare('''
INSERT INTO highlights (
  id, file_hash, page, text, color_value, rects_json, created_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
''');
    try {
      _db.execute('DELETE FROM highlights WHERE file_hash = ?', [fileHash]);
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
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    } finally {
      statement.close();
    }
  }

  Future<void> clearUserData() async {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      _db.execute('DELETE FROM highlights;');
      _db.execute('DELETE FROM notes;');
      _db.execute('DELETE FROM recent_files;');
      _db.execute('DELETE FROM documents;');
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
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

  int _now() => DateTime.now().millisecondsSinceEpoch;

  DateTime _fromMillis(Object? raw) {
    final millis = raw is int ? raw : 0;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
