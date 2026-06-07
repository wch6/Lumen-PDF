import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/src/models/reader_models.dart';
import 'package:pdf_reader/src/services/pdf_hash_service.dart';
import 'package:pdf_reader/src/services/reader_database.dart';
import 'package:pdf_reader/src/services/reader_repository.dart';

void main() {
  test('hash service matches bytes and file content', () async {
    const hashService = PdfHashService();
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final dir = await Directory.systemTemp.createTemp('pdf-reader-hash-');
    final file = File('${dir.path}${Platform.pathSeparator}sample.pdf');
    await file.writeAsBytes(bytes);
    addTearDown(() => dir.delete(recursive: true));

    expect(await hashService.hashFile(file.path), hashService.hashBytes(bytes));
  });

  test('hash service reports missing files', () async {
    const hashService = PdfHashService();

    await expectLater(
      hashService.hashFile('Z:\\missing\\file.pdf'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('repository loads annotations by PDF hash across paths', () async {
    final repository = ReaderRepository(database: ReaderDatabase.inMemory());
    addTearDown(repository.dispose);
    final bytes = Uint8List.fromList([7, 8, 9]);

    final first = await repository.openSource(
      PdfSource(name: 'original.pdf', bytes: bytes, size: bytes.length),
      initialPage: 2,
    );
    final note = PageNote(
      id: 'note-1',
      page: 2,
      text: 'Remember this',
      createdAt: DateTime(2026),
    );
    final highlight = TextHighlight(
      id: 'highlight-1',
      page: 2,
      text: 'marked',
      rects: const [HighlightRect(left: 1, top: 2, right: 3, bottom: 4)],
      createdAt: DateTime(2026),
      colorValue: 0x66FFE066,
    );
    await repository.saveNotes(first.source, [note]);
    await repository.saveHighlights(first.source, [highlight]);

    final second = await repository.openSource(
      PdfSource(name: 'copy.pdf', bytes: bytes, size: bytes.length),
      initialPage: 1,
    );

    expect(second.source.hash, first.source.hash);
    expect(second.notes.single.text, note.text);
    expect(second.highlights.single.rects.single.left, 1);
  });

  test('same path with different hash does not reuse annotations', () async {
    final repository = ReaderRepository(database: ReaderDatabase.inMemory());
    addTearDown(repository.dispose);
    final dir = await Directory.systemTemp.createTemp('pdf-reader-repo-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}same.pdf');

    await file.writeAsBytes([1, 1, 1]);
    final first = await repository.openSource(
      PdfSource(name: 'same.pdf', path: file.path, size: await file.length()),
      initialPage: 1,
    );
    await repository.saveNotes(first.source, [
      PageNote(
        id: 'note-1',
        page: 1,
        text: 'old file',
        createdAt: DateTime(2026),
      ),
    ]);

    await file.writeAsBytes([2, 2, 2]);
    final second = await repository.openSource(
      PdfSource(name: 'same.pdf', path: file.path, size: await file.length()),
      initialPage: 1,
    );

    expect(second.source.hash, isNot(first.source.hash));
    expect(second.notes, isEmpty);
  });

  test(
    'repository note saves update existing rows and remove stale rows',
    () async {
      final repository = ReaderRepository(database: ReaderDatabase.inMemory());
      addTearDown(repository.dispose);
      final bytes = Uint8List.fromList([3, 4, 5]);

      final opened = await repository.openSource(
        PdfSource(name: 'notes.pdf', bytes: bytes, size: bytes.length),
        initialPage: 1,
      );
      final firstNote = PageNote(
        id: 'note-1',
        page: 1,
        text: 'first',
        createdAt: DateTime(2026),
      );
      final secondNote = PageNote(
        id: 'note-2',
        page: 1,
        text: 'second',
        createdAt: DateTime(2026),
      );

      await repository.saveNotes(opened.source, [firstNote, secondNote]);
      await repository.saveNotes(opened.source, [
        secondNote.copyWith(text: 'updated', updatedAt: DateTime(2026, 2)),
      ]);

      final reloaded = await repository.openSource(
        PdfSource(name: 'notes-copy.pdf', bytes: bytes, size: bytes.length),
        initialPage: 1,
      );

      expect(reloaded.notes, hasLength(1));
      expect(reloaded.notes.single.id, 'note-2');
      expect(reloaded.notes.single.text, 'updated');
    },
  );
}
