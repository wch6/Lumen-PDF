import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/src/models/reader_models.dart';
import 'package:pdf_reader/src/services/translation_services.dart';

void main() {
  test('legacy pronunciation autoplay settings migrate to three states', () {
    final legacyOn = ReaderSettings.tryDecode(
      jsonEncode({'selectionAutoPlayPronunciation': true}),
    );
    final legacyOff = ReaderSettings.tryDecode(
      jsonEncode({'selectionAutoPlayPronunciation': false}),
    );
    final explicitUk = ReaderSettings.tryDecode(
      jsonEncode({'selectionAutoPlayPronunciation': 'uk'}),
    );

    expect(legacyOn.selectionAutoPlayPronunciation, PronunciationAutoPlay.us);
    expect(legacyOff.selectionAutoPlayPronunciation, PronunciationAutoPlay.off);
    expect(explicitUk.selectionAutoPlayPronunciation, PronunciationAutoPlay.uk);
  });

  test('selection dictionary defaults to Haici after migration', () {
    expect(const ReaderSettings().selectionDictionaryService, 'haicidict');
    expect(
      ReaderSettings.tryDecode('{}').selectionDictionaryService,
      'haicidict',
    );
    for (final removed in ['cnkidict', 'collinsdict', 'webliodict']) {
      expect(
        ReaderSettings.tryDecode(
          jsonEncode({'selectionDictionaryService': removed}),
        ).selectionDictionaryService,
        'haicidict',
      );
    }
  });

  test(
    'selection translation service removes Google API and normalizes IDs',
    () {
      expect(
        ReaderSettings.tryDecode(
          jsonEncode({'selectionTranslateService': 'googleapi'}),
        ).selectionTranslateService,
        'google',
      );
      expect(
        ReaderSettings.tryDecode(
          jsonEncode({'selectionTranslateService': 'removed-service'}),
        ).selectionTranslateService,
        'bing',
      );
      expect(
        const ReaderSettings()
            .copyWith(selectionTranslateService: 'googleapi')
            .selectionTranslateService,
        'google',
      );
      expect(
        ReaderSettings.tryDecode(
          jsonEncode({'selectionTranslateService': 'deeplfree'}),
        ).selectionTranslateService,
        'deeplx',
      );
      expect(
        ReaderSettings.tryDecode(
          jsonEncode({
            'selectionTranslateSecrets': {
              'deeplfree': 'legacy-key',
              'baidu': 'appid#key',
            },
          }),
        ).selectionTranslateSecrets,
        {'baidu': 'appid#key'},
      );
    },
  );

  test('system resolution uses the current display dpi directly', () {
    const defaultSettings = ReaderSettings();
    const systemSettings = ReaderSettings(
      resolutionMode: ResolutionMode.systemSetting,
    );

    expect(defaultSettings.effectiveResolutionForSystemResolution(192), 96);
    expect(systemSettings.effectiveResolutionForSystemResolution(192), 192);
    expect(systemSettings.effectiveResolutionForSystemResolution(72), 96);
    expect(systemSettings.effectiveResolutionForSystemResolution(720), 600);
  });

  test('thumbnail sidebar settings persist and normalize anchor page', () {
    final decoded = ReaderSettings.tryDecode(
      jsonEncode({'thumbnailTwoColumn': true, 'thumbnailAnchorPage': 12}),
    );

    expect(decoded.thumbnailTwoColumn, isTrue);
    expect(decoded.thumbnailAnchorPage, 12);
    expect(decoded.copyWith(thumbnailAnchorPage: -4).thumbnailAnchorPage, 1);
  });

  test('shortcut defaults include highlight colors and migrated fit keys', () {
    final defaults = const ReaderSettings().shortcutBindings;

    expect(defaults[ReaderShortcutAction.openRecentFiles]!.label, 'Ctrl+Tab');
    expect(
      defaults[ReaderShortcutAction.selectHighlightColor]!.label,
      'Ctrl+H',
    );
    expect(defaults[ReaderShortcutAction.openLibraryPanel]!.label, 'Ctrl+L');
    expect(defaults[ReaderShortcutAction.openPagesPanel]!.label, 'Ctrl+T');
    expect(
      defaults[ReaderShortcutAction.toggleThumbnailLayout]!.label,
      'Shift+Tab',
    );
    expect(defaults[ReaderShortcutAction.openOutlinePanel]!.label, 'Ctrl+B');
    expect(defaults[ReaderShortcutAction.openNotesPanel]!.label, 'Ctrl+N');
    expect(defaults[ReaderShortcutAction.openSettings]!.label, "Ctrl+'");
    expect(
      defaults[ReaderShortcutAction.openSettings]!.keyId,
      LogicalKeyboardKey.quote.keyId,
    );
    expect(defaults[ReaderShortcutAction.fitWidth]!.label, 'Ctrl+W');
    expect(defaults[ReaderShortcutAction.fitPage]!.label, 'Ctrl+P');

    final migrated = ReaderSettings.tryDecode(
      jsonEncode({
        'shortcutBindings': {
          'fitWidth': const ReaderShortcutBinding(
            keyId: 0x0000000000000030,
            control: true,
          ).toJson(),
          'fitPage': const ReaderShortcutBinding(
            keyId: 0x0000000000000031,
            control: true,
          ).toJson(),
          'openSettings': const ReaderShortcutBinding(
            keyId: 0x0000000000000027,
            control: true,
          ).toJson(),
        },
      }),
    );
    expect(
      migrated.shortcutBindings[ReaderShortcutAction.fitWidth]!.label,
      'Ctrl+W',
    );
    expect(
      migrated.shortcutBindings[ReaderShortcutAction.fitPage]!.label,
      'Ctrl+P',
    );
    expect(
      migrated.shortcutBindings[ReaderShortcutAction.openSettings]!.keyId,
      LogicalKeyboardKey.quote.keyId,
    );
  });

  test('pronunciation audio text is labelled by accent', () {
    expect(
      const PronunciationAudio(
        accent: PronunciationAccent.uk,
        phonetic: '/blak/',
        url: 'https://example.test/uk.mp3',
      ).text,
      '英式 /blak/',
    );
    expect(
      const PronunciationAudio(
        accent: PronunciationAccent.us,
        url: 'https://example.test/us.mp3',
      ).text,
      '美式',
    );
  });
}
