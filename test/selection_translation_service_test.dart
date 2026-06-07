import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/src/services/translation_services.dart';

void main() {
  group('SelectionTranslationService.normalizeSelectionText', () {
    test('removes surrounding punctuation from dictionary terms', () {
      expect(
        SelectionTranslationService.normalizeSelectionText('(black'),
        'black',
      );
      expect(
        SelectionTranslationService.normalizeSelectionText(
          '“state-of-the-art,”',
        ),
        'state-of-the-art',
      );
      expect(
        SelectionTranslationService.normalizeSelectionText("don't."),
        "don't",
      );
      expect(
        SelectionTranslationService.normalizeSelectionText('equation15'),
        'equation',
      );
    });

    test('keeps longer selected text intact', () {
      const sentence = '(black coating samples are shown in this figure.)';
      expect(
        SelectionTranslationService.normalizeSelectionText(sentence),
        sentence,
      );
    });
  });

  group('SelectionTranslationService.dictionaryLookupTerm', () {
    test('accepts cleaned short terms only', () {
      expect(
        SelectionTranslationService.dictionaryLookupTerm('(black'),
        'black',
      );
      expect(
        SelectionTranslationService.dictionaryLookupTerm('black coating model'),
        'black coating model',
      );
      expect(
        SelectionTranslationService.dictionaryLookupTerm(
          'black coating model with extra words',
        ),
        isNull,
      );
    });
  });
}
