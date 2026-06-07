import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

enum PanelMode { library, pages, outline, search, notes, translate }

enum ReaderAccent { rose, purple, green }

enum DefaultPageLayout { fitWidth, fitPage }

enum ResolutionMode { defaultSetting, systemSetting }

enum ExportImageFormat { png, jpg }

enum PronunciationAutoPlay { us, off, uk }

enum ReaderShortcutAction {
  openFile,
  search,
  clearSearch,
  openRecentFiles,
  selectHighlightColor,
  openLibraryPanel,
  openPagesPanel,
  toggleThumbnailLayout,
  openOutlinePanel,
  openNotesPanel,
  openSettings,
  addNote,
  undoNoteChange,
  redoNoteChange,
  previousPage,
  nextPage,
  fitWidth,
  fitPage,
  toggleTheme,
}

const kDefaultShortcutBindings = <ReaderShortcutAction, ReaderShortcutBinding>{
  ReaderShortcutAction.openFile: ReaderShortcutBinding(
    keyId: 0x000000000000006F,
    control: true,
  ),
  ReaderShortcutAction.search: ReaderShortcutBinding(
    keyId: 0x0000000000000066,
    control: true,
  ),
  ReaderShortcutAction.clearSearch: ReaderShortcutBinding(keyId: 0x0010000001b),
  ReaderShortcutAction.openRecentFiles: ReaderShortcutBinding(
    keyId: 0x00100000009,
    control: true,
  ),
  ReaderShortcutAction.selectHighlightColor: ReaderShortcutBinding(
    keyId: 0x0000000000000068,
    control: true,
  ),
  ReaderShortcutAction.openLibraryPanel: ReaderShortcutBinding(
    keyId: 0x000000000000006c,
    control: true,
  ),
  ReaderShortcutAction.openPagesPanel: ReaderShortcutBinding(
    keyId: 0x0000000000000074,
    control: true,
  ),
  ReaderShortcutAction.toggleThumbnailLayout: ReaderShortcutBinding(
    keyId: 0x00100000009,
    shift: true,
  ),
  ReaderShortcutAction.openOutlinePanel: ReaderShortcutBinding(
    keyId: 0x0000000000000062,
    control: true,
  ),
  ReaderShortcutAction.openNotesPanel: ReaderShortcutBinding(
    keyId: 0x000000000000006e,
    control: true,
  ),
  ReaderShortcutAction.openSettings: ReaderShortcutBinding(
    keyId: 0x0000000000000022,
    control: true,
  ),
  ReaderShortcutAction.addNote: ReaderShortcutBinding(
    keyId: 0x000000000000006e,
    control: true,
    shift: true,
  ),
  ReaderShortcutAction.undoNoteChange: ReaderShortcutBinding(
    keyId: 0x000000000000007a,
    control: true,
  ),
  ReaderShortcutAction.redoNoteChange: ReaderShortcutBinding(
    keyId: 0x0000000000000079,
    control: true,
  ),
  ReaderShortcutAction.previousPage: ReaderShortcutBinding(
    keyId: 0x00100000308,
  ),
  ReaderShortcutAction.nextPage: ReaderShortcutBinding(keyId: 0x00100000307),
  ReaderShortcutAction.fitWidth: ReaderShortcutBinding(
    keyId: 0x0000000000000077,
    control: true,
  ),
  ReaderShortcutAction.fitPage: ReaderShortcutBinding(
    keyId: 0x0000000000000070,
    control: true,
  ),
  ReaderShortcutAction.toggleTheme: ReaderShortcutBinding(
    keyId: 0x000000000000006c,
    control: true,
    shift: true,
  ),
};

const _legacyFitWidthShortcutBinding = ReaderShortcutBinding(
  keyId: 0x0000000000000030,
  control: true,
);
const _legacyFitPageShortcutBinding = ReaderShortcutBinding(
  keyId: 0x0000000000000031,
  control: true,
);
const _legacyOpenSettingsShortcutBinding = ReaderShortcutBinding(
  keyId: 0x0000000000000027,
  control: true,
);

extension ReaderShortcutActionLabel on ReaderShortcutAction {
  String get label {
    return switch (this) {
      ReaderShortcutAction.openFile => '打开 PDF',
      ReaderShortcutAction.search => '搜索内容',
      ReaderShortcutAction.clearSearch => '清除搜索/隐藏侧边栏',
      ReaderShortcutAction.openRecentFiles => '打开最近文件',
      ReaderShortcutAction.selectHighlightColor => '选择高亮颜色',
      ReaderShortcutAction.openLibraryPanel => '打开资料库',
      ReaderShortcutAction.openPagesPanel => '打开缩略图',
      ReaderShortcutAction.toggleThumbnailLayout => '切换缩略图单/双页',
      ReaderShortcutAction.openOutlinePanel => '打开目录',
      ReaderShortcutAction.openNotesPanel => '打开笔记',
      ReaderShortcutAction.openSettings => '打开设置',
      ReaderShortcutAction.addNote => '新建便签',
      ReaderShortcutAction.undoNoteChange => '撤回笔记更改',
      ReaderShortcutAction.redoNoteChange => '重做笔记更改',
      ReaderShortcutAction.previousPage => '上一页',
      ReaderShortcutAction.nextPage => '下一页',
      ReaderShortcutAction.fitWidth => '适合宽度',
      ReaderShortcutAction.fitPage => '适合页面',
      ReaderShortcutAction.toggleTheme => '切换日夜模式',
    };
  }
}

extension ReaderAccentLabel on ReaderAccent {
  String get label {
    return switch (this) {
      ReaderAccent.rose => '玫瑰红',
      ReaderAccent.purple => '暗夜紫',
      ReaderAccent.green => '薄荷绿',
    };
  }
}

class ReaderShortcutBinding {
  const ReaderShortcutBinding({
    required this.keyId,
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });

  final int keyId;
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  LogicalKeyboardKey get logicalKey => LogicalKeyboardKey(keyId);

  bool hasSameKeys(ReaderShortcutBinding other) {
    return keyId == other.keyId &&
        control == other.control &&
        shift == other.shift &&
        alt == other.alt &&
        meta == other.meta;
  }

  String get label {
    final parts = <String>[
      if (control) 'Ctrl',
      if (shift) 'Shift',
      if (alt) 'Alt',
      if (meta) 'Win',
      _keyLabel,
    ];
    return parts.join('+');
  }

  String get _keyLabel {
    if (keyId == LogicalKeyboardKey.keyA.keyId) return 'A';
    if (keyId == LogicalKeyboardKey.keyB.keyId) return 'B';
    if (keyId == LogicalKeyboardKey.keyC.keyId) return 'C';
    if (keyId == LogicalKeyboardKey.keyD.keyId) return 'D';
    if (keyId == LogicalKeyboardKey.keyE.keyId) return 'E';
    if (keyId == LogicalKeyboardKey.keyF.keyId) return 'F';
    if (keyId == LogicalKeyboardKey.keyG.keyId) return 'G';
    if (keyId == LogicalKeyboardKey.keyH.keyId) return 'H';
    if (keyId == LogicalKeyboardKey.keyI.keyId) return 'I';
    if (keyId == LogicalKeyboardKey.keyJ.keyId) return 'J';
    if (keyId == LogicalKeyboardKey.keyK.keyId) return 'K';
    if (keyId == LogicalKeyboardKey.keyL.keyId) return 'L';
    if (keyId == LogicalKeyboardKey.keyM.keyId) return 'M';
    if (keyId == LogicalKeyboardKey.keyN.keyId) return 'N';
    if (keyId == LogicalKeyboardKey.keyO.keyId) return 'O';
    if (keyId == LogicalKeyboardKey.keyP.keyId) return 'P';
    if (keyId == LogicalKeyboardKey.keyQ.keyId) return 'Q';
    if (keyId == LogicalKeyboardKey.keyR.keyId) return 'R';
    if (keyId == LogicalKeyboardKey.keyS.keyId) return 'S';
    if (keyId == LogicalKeyboardKey.keyT.keyId) return 'T';
    if (keyId == LogicalKeyboardKey.keyU.keyId) return 'U';
    if (keyId == LogicalKeyboardKey.keyV.keyId) return 'V';
    if (keyId == LogicalKeyboardKey.keyW.keyId) return 'W';
    if (keyId == LogicalKeyboardKey.keyX.keyId) return 'X';
    if (keyId == LogicalKeyboardKey.keyY.keyId) return 'Y';
    if (keyId == LogicalKeyboardKey.keyZ.keyId) return 'Z';
    if (keyId == LogicalKeyboardKey.digit0.keyId) return '0';
    if (keyId == LogicalKeyboardKey.digit1.keyId) return '1';
    if (keyId == LogicalKeyboardKey.digit2.keyId) return '2';
    if (keyId == LogicalKeyboardKey.digit3.keyId) return '3';
    if (keyId == LogicalKeyboardKey.digit4.keyId) return '4';
    if (keyId == LogicalKeyboardKey.digit5.keyId) return '5';
    if (keyId == LogicalKeyboardKey.digit6.keyId) return '6';
    if (keyId == LogicalKeyboardKey.digit7.keyId) return '7';
    if (keyId == LogicalKeyboardKey.digit8.keyId) return '8';
    if (keyId == LogicalKeyboardKey.digit9.keyId) return '9';
    if (keyId == LogicalKeyboardKey.equal.keyId) return '=';
    if (keyId == LogicalKeyboardKey.minus.keyId) return '-';
    if (keyId == LogicalKeyboardKey.quote.keyId) return "'";
    if (keyId == LogicalKeyboardKey.quoteSingle.keyId) return "'";
    if (keyId == LogicalKeyboardKey.pageUp.keyId) return 'Page Up';
    if (keyId == LogicalKeyboardKey.pageDown.keyId) return 'Page Down';
    if (keyId == LogicalKeyboardKey.arrowLeft.keyId) return '←';
    if (keyId == LogicalKeyboardKey.arrowRight.keyId) return '→';
    if (keyId == LogicalKeyboardKey.arrowUp.keyId) return '↑';
    if (keyId == LogicalKeyboardKey.arrowDown.keyId) return '↓';
    if (keyId == LogicalKeyboardKey.escape.keyId) return 'Esc';
    if (keyId == LogicalKeyboardKey.tab.keyId) return 'Tab';
    if (keyId == LogicalKeyboardKey.enter.keyId) return 'Enter';
    final label = logicalKey.keyLabel;
    return label.isEmpty ? 'Key ${keyId.toRadixString(16)}' : label;
  }

  Map<String, Object?> toJson() {
    return {
      'keyId': keyId,
      'control': control,
      'shift': shift,
      'alt': alt,
      'meta': meta,
    };
  }

  static ReaderShortcutBinding? tryDecode(Object? raw) {
    try {
      final data = raw as Map<String, dynamic>;
      final keyId = data['keyId'];
      if (keyId is! int || keyId == 0) {
        return null;
      }
      return ReaderShortcutBinding(
        keyId: keyId,
        control: data['control'] as bool? ?? false,
        shift: data['shift'] as bool? ?? false,
        alt: data['alt'] as bool? ?? false,
        meta: data['meta'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static ReaderShortcutBinding? fromKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _isModifierKey(event.logicalKey)) {
      return null;
    }
    final keyboard = HardwareKeyboard.instance;
    return ReaderShortcutBinding(
      keyId: event.logicalKey.keyId,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }
}

extension DefaultPageLayoutLabel on DefaultPageLayout {
  String get label {
    return switch (this) {
      DefaultPageLayout.fitWidth => '适合宽度',
      DefaultPageLayout.fitPage => '适合页面',
    };
  }
}

extension ResolutionModeLabel on ResolutionMode {
  String get label {
    return switch (this) {
      ResolutionMode.defaultSetting => '使用默认设置',
      ResolutionMode.systemSetting => '使用系统设置',
    };
  }
}

extension ExportImageFormatLabel on ExportImageFormat {
  String get label {
    return switch (this) {
      ExportImageFormat.png => 'PNG',
      ExportImageFormat.jpg => 'JPG',
    };
  }

  String get extension {
    return switch (this) {
      ExportImageFormat.png => 'png',
      ExportImageFormat.jpg => 'jpg',
    };
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.accent = ReaderAccent.purple,
    this.defaultPageLayout = DefaultPageLayout.fitWidth,
    this.alwaysOpenWithDefaultLayout = true,
    this.rememberWindowSize = true,
    this.rememberedWindowWidth,
    this.rememberedWindowHeight,
    this.thumbnailTwoColumn = false,
    this.thumbnailAnchorPage = 1,
    this.resolutionMode = ResolutionMode.defaultSetting,
    this.scrollSensitivity = 3,
    this.quickExportResolution = 192,
    this.quickExportFormat = ExportImageFormat.png,
    this.quickExportNamePattern = '{document}_P{page}',
    this.quickExportFolder,
    this.pdf2zhServiceUrl = 'http://localhost:8890',
    this.pdf2zhEngine = 'pdf2zh_next',
    this.pdf2zhService = 'bing',
    this.pdf2zhNextService = 'siliconflowfree',
    this.pdf2zhSourceLanguage = 'en',
    this.pdf2zhTargetLanguage = 'zh-CN',
    this.pdf2zhThreadCount = 4,
    this.pdf2zhQps = 10,
    this.pdf2zhSkipLastPages = 0,
    this.pdf2zhPoolSize = 0,
    this.pdf2zhRename = true,
    this.pdf2zhSkipSubsetFonts = false,
    this.pdf2zhBabeldoc = false,
    this.pdf2zhFontFamily = 'auto',
    this.pdf2zhDualMode = 'LR',
    this.pdf2zhTransFirst = true,
    this.pdf2zhOcr = false,
    this.pdf2zhAutoOcr = true,
    this.pdf2zhNoWatermark = true,
    this.pdf2zhEnhanceCompatibility = false,
    this.pdf2zhTranslateTableText = false,
    this.selectionTranslateService = 'bing',
    this.selectionTranslateSourceLanguage = 'en-US',
    this.selectionTranslateTargetLanguage = 'zh-CN',
    this.selectionTranslatePopup = true,
    this.selectionTranslateAutoDetectLanguage = true,
    this.selectionTranslateSecret = '',
    this.selectionTranslateSecrets = const {},
    this.selectionTranslateEndpoint = '',
    this.selectionDictionaryEnabled = true,
    this.selectionDictionaryService = 'haicidict',
    this.selectionDictionarySecret = '',
    this.selectionShowPronunciation = true,
    this.selectionAutoPlayPronunciation = PronunciationAutoPlay.off,
    this.shortcutBindings = kDefaultShortcutBindings,
  });

  final ReaderAccent accent;
  final DefaultPageLayout defaultPageLayout;
  final bool alwaysOpenWithDefaultLayout;
  final bool rememberWindowSize;
  final int? rememberedWindowWidth;
  final int? rememberedWindowHeight;
  final bool thumbnailTwoColumn;
  final int thumbnailAnchorPage;
  final ResolutionMode resolutionMode;
  final double scrollSensitivity;
  final int quickExportResolution;
  final ExportImageFormat quickExportFormat;
  final String quickExportNamePattern;
  final String? quickExportFolder;
  final String pdf2zhServiceUrl;
  final String pdf2zhEngine;
  final String pdf2zhService;
  final String pdf2zhNextService;
  final String pdf2zhSourceLanguage;
  final String pdf2zhTargetLanguage;
  final int pdf2zhThreadCount;
  final int pdf2zhQps;
  final int pdf2zhSkipLastPages;
  final int pdf2zhPoolSize;
  final bool pdf2zhRename;
  final bool pdf2zhSkipSubsetFonts;
  final bool pdf2zhBabeldoc;
  final String pdf2zhFontFamily;
  final String pdf2zhDualMode;
  final bool pdf2zhTransFirst;
  final bool pdf2zhOcr;
  final bool pdf2zhAutoOcr;
  final bool pdf2zhNoWatermark;
  final bool pdf2zhEnhanceCompatibility;
  final bool pdf2zhTranslateTableText;
  final String selectionTranslateService;
  final String selectionTranslateSourceLanguage;
  final String selectionTranslateTargetLanguage;
  final bool selectionTranslatePopup;
  final bool selectionTranslateAutoDetectLanguage;
  final String selectionTranslateSecret;
  final Map<String, String> selectionTranslateSecrets;
  final String selectionTranslateEndpoint;
  final bool selectionDictionaryEnabled;
  final String selectionDictionaryService;
  final String selectionDictionarySecret;
  final bool selectionShowPronunciation;
  final PronunciationAutoPlay selectionAutoPlayPronunciation;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;

  static const defaultResolution = 96;

  static int? _normalizedWindowDimension(Object? value, int minimum) {
    final raw = switch (value) {
      int() => value,
      num() => value.round(),
      _ => null,
    };
    if (raw == null) {
      return null;
    }
    return raw.clamp(minimum, 10000).toInt();
  }

  static int systemResolutionFor(double devicePixelRatio) {
    return (devicePixelRatio * 96).round().clamp(96, 600);
  }

  static int normalizedSystemResolution(int resolution) {
    return resolution.clamp(96, 600);
  }

  int effectiveResolutionFor(double devicePixelRatio) {
    return effectiveResolutionForSystemResolution(
      systemResolutionFor(devicePixelRatio),
    );
  }

  int effectiveResolutionForSystemResolution(int systemResolution) {
    return switch (resolutionMode) {
      ResolutionMode.defaultSetting => defaultResolution,
      ResolutionMode.systemSetting => normalizedSystemResolution(
        systemResolution,
      ),
    };
  }

  ReaderSettings copyWith({
    ReaderAccent? accent,
    DefaultPageLayout? defaultPageLayout,
    bool? alwaysOpenWithDefaultLayout,
    bool? rememberWindowSize,
    int? rememberedWindowWidth,
    int? rememberedWindowHeight,
    bool? thumbnailTwoColumn,
    int? thumbnailAnchorPage,
    ResolutionMode? resolutionMode,
    double? scrollSensitivity,
    int? quickExportResolution,
    ExportImageFormat? quickExportFormat,
    String? quickExportNamePattern,
    Object? quickExportFolder = _sentinel,
    String? pdf2zhServiceUrl,
    String? pdf2zhEngine,
    String? pdf2zhService,
    String? pdf2zhNextService,
    String? pdf2zhSourceLanguage,
    String? pdf2zhTargetLanguage,
    int? pdf2zhThreadCount,
    int? pdf2zhQps,
    int? pdf2zhSkipLastPages,
    int? pdf2zhPoolSize,
    bool? pdf2zhRename,
    bool? pdf2zhSkipSubsetFonts,
    bool? pdf2zhBabeldoc,
    String? pdf2zhFontFamily,
    String? pdf2zhDualMode,
    bool? pdf2zhTransFirst,
    bool? pdf2zhOcr,
    bool? pdf2zhAutoOcr,
    bool? pdf2zhNoWatermark,
    bool? pdf2zhEnhanceCompatibility,
    bool? pdf2zhTranslateTableText,
    String? selectionTranslateService,
    String? selectionTranslateSourceLanguage,
    String? selectionTranslateTargetLanguage,
    bool? selectionTranslatePopup,
    bool? selectionTranslateAutoDetectLanguage,
    String? selectionTranslateSecret,
    Map<String, String>? selectionTranslateSecrets,
    String? selectionTranslateEndpoint,
    bool? selectionDictionaryEnabled,
    String? selectionDictionaryService,
    String? selectionDictionarySecret,
    bool? selectionShowPronunciation,
    PronunciationAutoPlay? selectionAutoPlayPronunciation,
    Map<ReaderShortcutAction, ReaderShortcutBinding>? shortcutBindings,
  }) {
    return ReaderSettings(
      accent: accent ?? this.accent,
      defaultPageLayout: defaultPageLayout ?? this.defaultPageLayout,
      alwaysOpenWithDefaultLayout:
          alwaysOpenWithDefaultLayout ?? this.alwaysOpenWithDefaultLayout,
      rememberWindowSize: rememberWindowSize ?? this.rememberWindowSize,
      rememberedWindowWidth: _normalizedWindowDimension(
        rememberedWindowWidth ?? this.rememberedWindowWidth,
        720,
      ),
      rememberedWindowHeight: _normalizedWindowDimension(
        rememberedWindowHeight ?? this.rememberedWindowHeight,
        640,
      ),
      thumbnailTwoColumn: thumbnailTwoColumn ?? this.thumbnailTwoColumn,
      thumbnailAnchorPage: math.max(
        1,
        thumbnailAnchorPage ?? this.thumbnailAnchorPage,
      ),
      resolutionMode: resolutionMode ?? this.resolutionMode,
      scrollSensitivity: (scrollSensitivity ?? this.scrollSensitivity).clamp(
        1.0,
        5.0,
      ),
      quickExportResolution:
          (quickExportResolution ?? this.quickExportResolution).clamp(72, 600),
      quickExportFormat: quickExportFormat ?? this.quickExportFormat,
      quickExportNamePattern:
          quickExportNamePattern ?? this.quickExportNamePattern,
      quickExportFolder: identical(quickExportFolder, _sentinel)
          ? this.quickExportFolder
          : quickExportFolder as String?,
      pdf2zhServiceUrl: pdf2zhServiceUrl ?? this.pdf2zhServiceUrl,
      pdf2zhEngine: pdf2zhEngine ?? this.pdf2zhEngine,
      pdf2zhService: pdf2zhService ?? this.pdf2zhService,
      pdf2zhNextService: pdf2zhNextService ?? this.pdf2zhNextService,
      pdf2zhSourceLanguage: pdf2zhSourceLanguage ?? this.pdf2zhSourceLanguage,
      pdf2zhTargetLanguage: pdf2zhTargetLanguage ?? this.pdf2zhTargetLanguage,
      pdf2zhThreadCount: (pdf2zhThreadCount ?? this.pdf2zhThreadCount).clamp(
        1,
        32,
      ),
      pdf2zhQps: (pdf2zhQps ?? this.pdf2zhQps).clamp(1, 120),
      pdf2zhSkipLastPages: (pdf2zhSkipLastPages ?? this.pdf2zhSkipLastPages)
          .clamp(0, 99),
      pdf2zhPoolSize: (pdf2zhPoolSize ?? this.pdf2zhPoolSize).clamp(0, 64),
      pdf2zhRename: pdf2zhRename ?? this.pdf2zhRename,
      pdf2zhSkipSubsetFonts:
          pdf2zhSkipSubsetFonts ?? this.pdf2zhSkipSubsetFonts,
      pdf2zhBabeldoc: pdf2zhBabeldoc ?? this.pdf2zhBabeldoc,
      pdf2zhFontFamily: pdf2zhFontFamily ?? this.pdf2zhFontFamily,
      pdf2zhDualMode: pdf2zhDualMode ?? this.pdf2zhDualMode,
      pdf2zhTransFirst: pdf2zhTransFirst ?? this.pdf2zhTransFirst,
      pdf2zhOcr: pdf2zhOcr ?? this.pdf2zhOcr,
      pdf2zhAutoOcr: pdf2zhAutoOcr ?? this.pdf2zhAutoOcr,
      pdf2zhNoWatermark: pdf2zhNoWatermark ?? this.pdf2zhNoWatermark,
      pdf2zhEnhanceCompatibility:
          pdf2zhEnhanceCompatibility ?? this.pdf2zhEnhanceCompatibility,
      pdf2zhTranslateTableText:
          pdf2zhTranslateTableText ?? this.pdf2zhTranslateTableText,
      selectionTranslateService: _decodeTranslateService(
        selectionTranslateService ?? this.selectionTranslateService,
      ),
      selectionTranslateSourceLanguage:
          selectionTranslateSourceLanguage ??
          this.selectionTranslateSourceLanguage,
      selectionTranslateTargetLanguage:
          selectionTranslateTargetLanguage ??
          this.selectionTranslateTargetLanguage,
      selectionTranslatePopup:
          selectionTranslatePopup ?? this.selectionTranslatePopup,
      selectionTranslateAutoDetectLanguage:
          selectionTranslateAutoDetectLanguage ??
          this.selectionTranslateAutoDetectLanguage,
      selectionTranslateSecret:
          selectionTranslateSecret ?? this.selectionTranslateSecret,
      selectionTranslateSecrets: Map.unmodifiable(
        selectionTranslateSecrets ?? this.selectionTranslateSecrets,
      ),
      selectionTranslateEndpoint:
          selectionTranslateEndpoint ?? this.selectionTranslateEndpoint,
      selectionDictionaryEnabled:
          selectionDictionaryEnabled ?? this.selectionDictionaryEnabled,
      selectionDictionaryService: _decodeDictionaryService(
        selectionDictionaryService ?? this.selectionDictionaryService,
      ),
      selectionDictionarySecret:
          selectionDictionarySecret ?? this.selectionDictionarySecret,
      selectionShowPronunciation:
          selectionShowPronunciation ?? this.selectionShowPronunciation,
      selectionAutoPlayPronunciation:
          selectionAutoPlayPronunciation ?? this.selectionAutoPlayPronunciation,
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accent': accent.name,
      'defaultPageLayout': defaultPageLayout.name,
      'alwaysOpenWithDefaultLayout': alwaysOpenWithDefaultLayout,
      'rememberWindowSize': rememberWindowSize,
      'rememberedWindowWidth': rememberedWindowWidth,
      'rememberedWindowHeight': rememberedWindowHeight,
      'thumbnailTwoColumn': thumbnailTwoColumn,
      'thumbnailAnchorPage': thumbnailAnchorPage,
      'resolutionMode': resolutionMode.name,
      'scrollSensitivity': scrollSensitivity,
      'quickExportResolution': quickExportResolution,
      'quickExportFormat': quickExportFormat.name,
      'quickExportNamePattern': quickExportNamePattern,
      'quickExportFolder': quickExportFolder,
      'pdf2zhServiceUrl': pdf2zhServiceUrl,
      'pdf2zhEngine': pdf2zhEngine,
      'pdf2zhService': pdf2zhService,
      'pdf2zhNextService': pdf2zhNextService,
      'pdf2zhSourceLanguage': pdf2zhSourceLanguage,
      'pdf2zhTargetLanguage': pdf2zhTargetLanguage,
      'pdf2zhThreadCount': pdf2zhThreadCount,
      'pdf2zhQps': pdf2zhQps,
      'pdf2zhSkipLastPages': pdf2zhSkipLastPages,
      'pdf2zhPoolSize': pdf2zhPoolSize,
      'pdf2zhRename': pdf2zhRename,
      'pdf2zhSkipSubsetFonts': pdf2zhSkipSubsetFonts,
      'pdf2zhBabeldoc': pdf2zhBabeldoc,
      'pdf2zhFontFamily': pdf2zhFontFamily,
      'pdf2zhDualMode': pdf2zhDualMode,
      'pdf2zhTransFirst': pdf2zhTransFirst,
      'pdf2zhOcr': pdf2zhOcr,
      'pdf2zhAutoOcr': pdf2zhAutoOcr,
      'pdf2zhNoWatermark': pdf2zhNoWatermark,
      'pdf2zhEnhanceCompatibility': pdf2zhEnhanceCompatibility,
      'pdf2zhTranslateTableText': pdf2zhTranslateTableText,
      'selectionTranslateService': selectionTranslateService,
      'selectionTranslateSourceLanguage': selectionTranslateSourceLanguage,
      'selectionTranslateTargetLanguage': selectionTranslateTargetLanguage,
      'selectionTranslatePopup': selectionTranslatePopup,
      'selectionTranslateAutoDetectLanguage':
          selectionTranslateAutoDetectLanguage,
      'selectionTranslateSecret': selectionTranslateSecret,
      'selectionTranslateSecrets': selectionTranslateSecrets,
      'selectionTranslateEndpoint': selectionTranslateEndpoint,
      'selectionDictionaryEnabled': selectionDictionaryEnabled,
      'selectionDictionaryService': selectionDictionaryService,
      'selectionDictionarySecret': selectionDictionarySecret,
      'selectionShowPronunciation': selectionShowPronunciation,
      'selectionAutoPlayPronunciation': selectionAutoPlayPronunciation.name,
      'shortcutBindings': {
        for (final entry in shortcutBindings.entries)
          entry.key.name: entry.value.toJson(),
      },
    };
  }

  static ReaderSettings tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const ReaderSettings();
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final accentName = data['accent'] as String?;
      final layoutName = data['defaultPageLayout'] as String?;
      final resolutionModeName = data['resolutionMode'] as String?;
      final exportFormatName = data['quickExportFormat'] as String?;
      final shortcuts = Map<ReaderShortcutAction, ReaderShortcutBinding>.of(
        kDefaultShortcutBindings,
      );
      final shortcutData = data['shortcutBindings'];
      if (shortcutData is Map) {
        for (final action in ReaderShortcutAction.values) {
          final binding = ReaderShortcutBinding.tryDecode(
            shortcutData[action.name],
          );
          if (binding != null) {
            shortcuts[action] = binding;
          }
        }
        _migrateLegacyShortcut(
          shortcuts,
          ReaderShortcutAction.fitWidth,
          _legacyFitWidthShortcutBinding,
        );
        _migrateLegacyShortcut(
          shortcuts,
          ReaderShortcutAction.fitPage,
          _legacyFitPageShortcutBinding,
        );
        _migrateLegacyShortcut(
          shortcuts,
          ReaderShortcutAction.openSettings,
          _legacyOpenSettingsShortcutBinding,
        );
      }
      return ReaderSettings(
        accent: ReaderAccent.values.firstWhere(
          (item) => item.name == accentName,
          orElse: () => ReaderAccent.purple,
        ),
        defaultPageLayout: DefaultPageLayout.values.firstWhere(
          (item) => item.name == layoutName,
          orElse: () => DefaultPageLayout.fitWidth,
        ),
        alwaysOpenWithDefaultLayout:
            data['alwaysOpenWithDefaultLayout'] as bool? ?? true,
        rememberWindowSize: data['rememberWindowSize'] as bool? ?? true,
        rememberedWindowWidth: _normalizedWindowDimension(
          data['rememberedWindowWidth'],
          720,
        ),
        rememberedWindowHeight: _normalizedWindowDimension(
          data['rememberedWindowHeight'],
          640,
        ),
        thumbnailTwoColumn: data['thumbnailTwoColumn'] as bool? ?? false,
        thumbnailAnchorPage: math.max(
          1,
          data['thumbnailAnchorPage'] as int? ?? 1,
        ),
        resolutionMode: ResolutionMode.values.firstWhere(
          (item) => item.name == resolutionModeName,
          orElse: () => ResolutionMode.defaultSetting,
        ),
        scrollSensitivity: (data['scrollSensitivity'] as num?)?.toDouble() ?? 3,
        quickExportResolution: data['quickExportResolution'] as int? ?? 192,
        quickExportFormat: ExportImageFormat.values.firstWhere(
          (item) => item.name == exportFormatName,
          orElse: () => ExportImageFormat.png,
        ),
        quickExportNamePattern:
            data['quickExportNamePattern'] as String? ?? '{document}_P{page}',
        quickExportFolder: data['quickExportFolder'] as String?,
        pdf2zhServiceUrl:
            data['pdf2zhServiceUrl'] as String? ?? 'http://localhost:8890',
        pdf2zhEngine: data['pdf2zhEngine'] as String? ?? 'pdf2zh_next',
        pdf2zhService: data['pdf2zhService'] as String? ?? 'bing',
        pdf2zhNextService:
            data['pdf2zhNextService'] as String? ?? 'siliconflowfree',
        pdf2zhSourceLanguage: data['pdf2zhSourceLanguage'] as String? ?? 'en',
        pdf2zhTargetLanguage:
            data['pdf2zhTargetLanguage'] as String? ?? 'zh-CN',
        pdf2zhThreadCount: data['pdf2zhThreadCount'] as int? ?? 4,
        pdf2zhQps: data['pdf2zhQps'] as int? ?? 10,
        pdf2zhSkipLastPages: data['pdf2zhSkipLastPages'] as int? ?? 0,
        pdf2zhPoolSize: data['pdf2zhPoolSize'] as int? ?? 0,
        pdf2zhRename: data['pdf2zhRename'] as bool? ?? true,
        pdf2zhSkipSubsetFonts: data['pdf2zhSkipSubsetFonts'] as bool? ?? false,
        pdf2zhBabeldoc: data['pdf2zhBabeldoc'] as bool? ?? false,
        pdf2zhFontFamily: data['pdf2zhFontFamily'] as String? ?? 'auto',
        pdf2zhDualMode: data['pdf2zhDualMode'] as String? ?? 'LR',
        pdf2zhTransFirst: data['pdf2zhTransFirst'] as bool? ?? true,
        pdf2zhOcr: data['pdf2zhOcr'] as bool? ?? false,
        pdf2zhAutoOcr: data['pdf2zhAutoOcr'] as bool? ?? true,
        pdf2zhNoWatermark: data['pdf2zhNoWatermark'] as bool? ?? true,
        pdf2zhEnhanceCompatibility:
            data['pdf2zhEnhanceCompatibility'] as bool? ?? false,
        pdf2zhTranslateTableText:
            data['pdf2zhTranslateTableText'] as bool? ?? false,
        selectionTranslateService: _decodeTranslateService(
          data['selectionTranslateService'],
        ),
        selectionTranslateSourceLanguage:
            data['selectionTranslateSourceLanguage'] as String? ?? 'en-US',
        selectionTranslateTargetLanguage:
            data['selectionTranslateTargetLanguage'] as String? ?? 'zh-CN',
        selectionTranslatePopup:
            data['selectionTranslatePopup'] as bool? ?? true,
        selectionTranslateAutoDetectLanguage:
            data['selectionTranslateAutoDetectLanguage'] as bool? ?? true,
        selectionTranslateSecret:
            data['selectionTranslateSecret'] as String? ?? '',
        selectionTranslateSecrets: _decodeTranslateSecretMap(
          data['selectionTranslateSecrets'],
        ),
        selectionTranslateEndpoint:
            data['selectionTranslateEndpoint'] as String? ?? '',
        selectionDictionaryEnabled:
            data['selectionDictionaryEnabled'] as bool? ?? true,
        selectionDictionaryService: _decodeDictionaryService(
          data['selectionDictionaryService'],
        ),
        selectionDictionarySecret:
            data['selectionDictionarySecret'] as String? ?? '',
        selectionShowPronunciation:
            data['selectionShowPronunciation'] as bool? ?? true,
        selectionAutoPlayPronunciation: _decodePronunciationAutoPlay(
          data['selectionAutoPlayPronunciation'],
        ),
        shortcutBindings: shortcuts,
      );
    } catch (_) {
      return const ReaderSettings();
    }
  }

  String selectionTranslateSecretFor(String service) {
    final scoped = selectionTranslateSecrets[service]?.trim();
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }
    return selectionTranslateSecret.trim();
  }

  static PronunciationAutoPlay _decodePronunciationAutoPlay(Object? raw) {
    if (raw is bool) {
      return raw ? PronunciationAutoPlay.us : PronunciationAutoPlay.off;
    }
    if (raw is String) {
      return PronunciationAutoPlay.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => PronunciationAutoPlay.off,
      );
    }
    return PronunciationAutoPlay.off;
  }

  static String _decodeTranslateService(Object? raw) {
    final value = raw is String ? raw : 'bing';
    if (value == 'googleapi') {
      return 'google';
    }
    if (value == 'deeplfree') {
      return 'deeplx';
    }
    return const {
          'youdao',
          'bing',
          'cnki',
          'google',
          'haici',
          'huoshanweb',
          'tencenttransmart',
          'deeplx',
          'baidu',
          'aliyun',
          'tencent',
        }.contains(value)
        ? value
        : 'bing';
  }

  static String _decodeDictionaryService(Object? raw) {
    final value = raw is String ? raw : 'haicidict';
    return const {
          'haicidict',
          'youdaodict',
          'bingdict',
          'cambridgedict',
          'freedictionaryapi',
        }.contains(value)
        ? value
        : 'haicidict';
  }

  static Map<String, String> _decodeTranslateSecretMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    const allowedServices = {'baidu', 'aliyun', 'tencent'};
    return {
      for (final entry in raw.entries)
        if (entry.key != null &&
            entry.value != null &&
            allowedServices.contains(entry.key.toString()))
          entry.key.toString(): entry.value.toString(),
    };
  }
}

const Object _sentinel = Object();

void _migrateLegacyShortcut(
  Map<ReaderShortcutAction, ReaderShortcutBinding> shortcuts,
  ReaderShortcutAction action,
  ReaderShortcutBinding legacyBinding,
) {
  final current = shortcuts[action];
  final updatedDefault = kDefaultShortcutBindings[action];
  if (current == null || updatedDefault == null) {
    return;
  }
  if (_sameShortcutBinding(current, legacyBinding)) {
    shortcuts[action] = updatedDefault;
  }
}

bool _sameShortcutBinding(
  ReaderShortcutBinding first,
  ReaderShortcutBinding second,
) {
  return first.hasSameKeys(second);
}

class PageExportOptions {
  const PageExportOptions({
    required this.resolution,
    required this.format,
    required this.namePattern,
    this.folder,
  });

  final int resolution;
  final ExportImageFormat format;
  final String namePattern;
  final String? folder;

  PageExportOptions copyWith({
    int? resolution,
    ExportImageFormat? format,
    String? namePattern,
    Object? folder = _sentinel,
  }) {
    return PageExportOptions(
      resolution: (resolution ?? this.resolution).clamp(72, 600),
      format: format ?? this.format,
      namePattern: namePattern ?? this.namePattern,
      folder: identical(folder, _sentinel) ? this.folder : folder as String?,
    );
  }
}

class PdfSource {
  const PdfSource({
    required this.name,
    this.path,
    this.bytes,
    this.size,
    this.hash,
  }) : assert(path != null || bytes != null);

  final String name;
  final String? path;
  final Uint8List? bytes;
  final int? size;
  final String? hash;

  String get id => hash ?? path ?? 'memory:$name:$size';

  PdfSource copyWith({
    String? name,
    String? path,
    Uint8List? bytes,
    int? size,
    String? hash,
  }) {
    return PdfSource(
      name: name ?? this.name,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      size: size ?? this.size,
      hash: hash ?? this.hash,
    );
  }

  String get prettySize {
    final value = size;
    if (value == null || value <= 0) {
      return 'PDF';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / 1024).ceil()} KB';
  }
}

class RecentDocument {
  const RecentDocument({
    required this.name,
    required this.path,
    required this.openedAt,
    this.size,
    this.page = 1,
    this.fileHash,
    this.position,
  });

  final String name;
  final String path;
  final int? size;
  final int page;
  final DateTime openedAt;
  final String? fileHash;
  final ReaderPosition? position;

  RecentDocument copyWith({
    int? page,
    DateTime? openedAt,
    Object? fileHash = _sentinel,
    Object? position = _sentinel,
  }) {
    return RecentDocument(
      name: name,
      path: path,
      size: size,
      page: page ?? this.page,
      openedAt: openedAt ?? this.openedAt,
      fileHash: identical(fileHash, _sentinel)
          ? this.fileHash
          : fileHash as String?,
      position: identical(position, _sentinel)
          ? this.position
          : position as ReaderPosition?,
    );
  }
}

class SessionDocumentTab {
  const SessionDocumentTab({
    required this.source,
    required this.page,
    required this.openedAt,
    this.position,
  });

  final PdfSource source;
  final int page;
  final DateTime openedAt;
  final ReaderPosition? position;

  String get tooltipPath => source.path ?? source.name;

  SessionDocumentTab copyWith({
    PdfSource? source,
    int? page,
    DateTime? openedAt,
    Object? position = _sentinel,
  }) {
    return SessionDocumentTab(
      source: source ?? this.source,
      page: page ?? this.page,
      openedAt: openedAt ?? this.openedAt,
      position: identical(position, _sentinel)
          ? this.position
          : position as ReaderPosition?,
    );
  }
}

class ReaderPosition {
  const ReaderPosition({required this.page, this.matrix, this.visibleRect});

  final int page;
  final List<double>? matrix;
  final Rect? visibleRect;

  Map<String, Object?> toJson() {
    return {
      'page': page,
      'matrix': matrix,
      'visibleRect': _rectToJson(visibleRect),
    };
  }

  String encode() => jsonEncode(toJson());

  static ReaderPosition? tryDecode(Object? raw) {
    try {
      final data = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      final page = data['page'] as int?;
      if (page == null || page < 1) {
        return null;
      }
      final matrixData = data['matrix'];
      final matrix = matrixData is List
          ? matrixData.whereType<num>().map((item) => item.toDouble()).toList()
          : null;
      final visibleRect = _rectFromJson(data['visibleRect']);
      return ReaderPosition(
        page: page,
        matrix: matrix != null && matrix.length == 16 ? matrix : null,
        visibleRect: visibleRect,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, double>? _rectToJson(Rect? rect) {
    if (rect == null) {
      return null;
    }
    return {
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
    };
  }

  static Rect? _rectFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    double? read(String key) {
      final value = raw[key];
      return value is num ? value.toDouble() : null;
    }

    final left = read('left');
    final top = read('top');
    final right = read('right');
    final bottom = read('bottom');
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    if (right <= left || bottom <= top) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class PageViewportPreview {
  const PageViewportPreview({required this.page, required this.rects});

  final int page;
  final List<Rect> rects;

  bool get isEmpty => rects.isEmpty;
}

class FileDataSummary {
  const FileDataSummary({
    required this.hash,
    required this.name,
    required this.type,
    required this.updatedAt,
    this.lastPath,
    this.size,
    this.pageCount,
  });

  final String hash;
  final String name;
  final String? lastPath;
  final int? size;
  final int? pageCount;
  final String type;
  final DateTime updatedAt;
}

class PageNote {
  const PageNote({
    required this.id,
    required this.page,
    required this.text,
    required this.createdAt,
    this.x,
    this.y,
    this.highlightId,
    this.colorValue = 0x66FFE45C,
    this.updatedAt,
  });

  final String id;
  final int page;
  final String text;
  final DateTime createdAt;
  final double? x;
  final double? y;
  final String? highlightId;
  final int colorValue;
  final DateTime? updatedAt;

  bool get hasPosition => x != null && y != null;

  PageNote copyWith({
    String? id,
    int? page,
    String? text,
    DateTime? createdAt,
    Object? x = _sentinel,
    Object? y = _sentinel,
    Object? highlightId = _sentinel,
    int? colorValue,
    Object? updatedAt = _sentinel,
  }) {
    return PageNote(
      id: id ?? this.id,
      page: page ?? this.page,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      x: identical(x, _sentinel) ? this.x : x as double?,
      y: identical(y, _sentinel) ? this.y : y as double?,
      highlightId: identical(highlightId, _sentinel)
          ? this.highlightId
          : highlightId as String?,
      colorValue: colorValue ?? this.colorValue,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  static int compareByPosition(PageNote a, PageNote b) {
    final page = a.page.compareTo(b.page);
    if (page != 0) {
      return page;
    }
    final y = (a.y ?? double.infinity).compareTo(b.y ?? double.infinity);
    if (y != 0) {
      return y;
    }
    final x = (a.x ?? double.infinity).compareTo(b.x ?? double.infinity);
    if (x != 0) {
      return x;
    }
    return a.createdAt.compareTo(b.createdAt);
  }
}

class TextHighlight {
  const TextHighlight({
    required this.id,
    required this.page,
    required this.text,
    required this.rects,
    required this.createdAt,
    this.colorValue = 0x66FFE066,
  });

  final String id;
  final int page;
  final String text;
  final List<HighlightRect> rects;
  final DateTime createdAt;
  final int colorValue;

  TextHighlight copyWith({
    String? id,
    int? page,
    String? text,
    List<HighlightRect>? rects,
    DateTime? createdAt,
    int? colorValue,
  }) {
    return TextHighlight(
      id: id ?? this.id,
      page: page ?? this.page,
      text: text ?? this.text,
      rects: rects ?? this.rects,
      createdAt: createdAt ?? this.createdAt,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

class HighlightRect {
  const HighlightRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory HighlightRect.fromPdfRect(PdfRect rect) {
    return HighlightRect(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
    );
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  PdfRect toPdfRect() {
    return PdfRect(left, top, right, bottom);
  }

  Map<String, double> toJson() {
    return {'left': left, 'top': top, 'right': right, 'bottom': bottom};
  }

  static HighlightRect? tryDecode(Object? raw) {
    try {
      final data = raw as Map<String, dynamic>;
      double? read(String key) {
        final value = data[key];
        if (value is num) {
          return value.toDouble();
        }
        return null;
      }

      final left = read('left');
      final top = read('top');
      final right = read('right');
      final bottom = read('bottom');
      if (left == null || top == null || right == null || bottom == null) {
        return null;
      }
      return HighlightRect(left: left, top: top, right: right, bottom: bottom);
    } catch (_) {
      return null;
    }
  }
}

class StorageKeys {
  const StorageKeys._();

  static const settings = 'lumen_pdf.settings';
}
