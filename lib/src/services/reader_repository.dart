import '../models/reader_models.dart';
import 'pdf_hash_service.dart';
import 'reader_database.dart';

class OpenedPdfState {
  const OpenedPdfState({
    required this.source,
    required this.recent,
    required this.notes,
    required this.highlights,
  });

  final PdfSource source;
  final List<RecentDocument> recent;
  final List<PageNote> notes;
  final List<TextHighlight> highlights;
}

class ReaderRepository {
  ReaderRepository({
    required this.database,
    this.hashService = const PdfHashService(),
  });

  static Future<ReaderRepository> open() async {
    return ReaderRepository(database: await ReaderDatabase.openDefault());
  }

  final ReaderDatabase database;
  final PdfHashService hashService;

  void dispose() {
    database.dispose();
  }

  Future<List<RecentDocument>> loadRecent({int limit = 8}) {
    return database.loadRecent(limit: limit);
  }

  Future<OpenedPdfState> openSource(
    PdfSource source, {
    required int initialPage,
    int? pageCount,
  }) async {
    final fileHash = await hashService.hashSource(source);
    final resolved = source.copyWith(hash: fileHash);
    await database.recordOpen(
      source: resolved,
      fileHash: fileHash,
      page: initialPage,
      pageCount: pageCount,
    );
    return OpenedPdfState(
      source: resolved,
      recent: await database.loadRecent(),
      notes: await database.loadNotes(fileHash),
      highlights: await database.loadHighlights(fileHash),
    );
  }

  Future<void> updateReadPosition(
    PdfSource source, {
    required int page,
    int? pageCount,
  }) {
    return database.updateReadPosition(
      source: source,
      page: page,
      pageCount: pageCount,
    );
  }

  Future<void> saveNotes(PdfSource source, List<PageNote> notes) {
    final hash = source.hash;
    if (hash == null || hash.isEmpty) {
      return Future.value();
    }
    return database.saveNotes(hash, notes);
  }

  Future<void> saveHighlights(
    PdfSource source,
    List<TextHighlight> highlights,
  ) {
    final hash = source.hash;
    if (hash == null || hash.isEmpty) {
      return Future.value();
    }
    return database.saveHighlights(hash, highlights);
  }

  Future<void> clearUserData() {
    return database.clearUserData();
  }
}
