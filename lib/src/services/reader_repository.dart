import '../models/reader_models.dart';
import 'pdf_hash_service.dart';
import 'reader_database.dart';

class OpenedPdfState {
  const OpenedPdfState({
    required this.source,
    required this.recent,
    required this.notes,
    required this.highlights,
    required this.page,
    this.position,
    this.firstPagePreview,
  });

  final PdfSource source;
  final List<RecentDocument> recent;
  final List<PageNote> notes;
  final List<TextHighlight> highlights;
  final int page;
  final ReaderPosition? position;
  final PdfFirstPagePreviewData? firstPagePreview;
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

  Future<List<RecentDocument>> loadRecent({int limit = 9}) {
    return database.loadRecent(limit: limit);
  }

  Future<OpenedPdfState> openSource(
    PdfSource source, {
    required int initialPage,
    int? pageCount,
    ReaderPosition? position,
  }) async {
    final fileHash = await hashService.hashSource(source);
    final resolved = source.copyWith(hash: fileHash);
    final storedPosition = await database.loadDocumentPosition(fileHash);
    final effectivePosition = position ?? storedPosition;
    final effectivePage = effectivePosition?.page ?? initialPage;
    await database.recordOpen(
      source: resolved,
      fileHash: fileHash,
      page: effectivePage,
      pageCount: pageCount,
      position: effectivePosition,
    );
    return OpenedPdfState(
      source: resolved,
      recent: await database.loadRecent(),
      notes: await database.loadNotes(fileHash),
      highlights: await database.loadHighlights(fileHash),
      page: effectivePage,
      position: effectivePosition,
      firstPagePreview: await database.loadFirstPagePreview(fileHash),
    );
  }

  Future<void> updateReadPosition(
    PdfSource source, {
    required int page,
    int? pageCount,
    ReaderPosition? position,
  }) {
    return database.updateReadPosition(
      source: source,
      page: page,
      pageCount: pageCount,
      position: position,
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

  Future<void> deleteRecent(String path) => database.deleteRecent(path);

  Future<PdfFirstPagePreviewData?> loadFirstPagePreview(String fileHash) {
    return database.loadFirstPagePreview(fileHash);
  }

  Future<Map<String, PdfFirstPagePreviewData>> loadFirstPagePreviews(
    Iterable<String> fileHashes,
  ) {
    return database.loadFirstPagePreviews(fileHashes);
  }

  Future<void> saveFirstPagePreview(
    String fileHash,
    PdfFirstPagePreviewData preview,
  ) {
    return database.saveFirstPagePreview(fileHash, preview);
  }

  Future<void> clearRecent() => database.clearRecent();

  Future<List<FileDataSummary>> listFileData() => database.listFileData();

  Future<void> clearFileData() => database.clearFileData();

  Future<void> deleteFileDataByHashes(Set<String> hashes) {
    return database.deleteFileDataByHashes(hashes);
  }
}
