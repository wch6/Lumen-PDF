import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/main.dart';
import 'package:pdf_reader/src/services/reader_database.dart';
import 'package:pdf_reader/src/services/reader_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets('shows the PDF reader empty state', (tester) async {
    final repository = ReaderRepository(database: ReaderDatabase.inMemory());

    await tester.pumpWidget(
      PdfReaderApp(repositoryFuture: Future.value(repository)),
    );

    expect(find.text('Lumen PDF'), findsNothing);
    expect(find.text('打开 PDF 开始阅读'), findsOneWidget);
    expect(find.byTooltip('打开 PDF'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_rounded), findsWidgets);
  });
}
