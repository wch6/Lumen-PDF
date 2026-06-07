import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/main.dart';
import 'package:pdf_reader/src/services/reader_database.dart';
import 'package:pdf_reader/src/services/reader_repository.dart';
import 'package:pdf_reader/src/services/reader_settings_store.dart';
import 'package:pdf_reader/src/theme/app_colors.dart';

void main() {
  test('highlight palette provides ten distinct colors', () {
    expect(AppColors.highlightPalette.length, 10);
    expect(
      AppColors.highlightPalette.map((color) => color.toARGB32()).toSet(),
      hasLength(10),
    );
  });

  testWidgets('shows the PDF reader empty state', (tester) async {
    final repository = ReaderRepository(database: ReaderDatabase.inMemory());

    await tester.pumpWidget(
      PdfReaderApp(
        repositoryFuture: Future.value(repository),
        settingsStore: InMemoryReaderSettingsStore(),
      ),
    );

    expect(find.text('Lumen PDF'), findsNothing);
    expect(find.text('打开 PDF 开始阅读'), findsOneWidget);
    expect(find.byTooltip('打开 PDF'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_rounded), findsWidgets);
  });
}
