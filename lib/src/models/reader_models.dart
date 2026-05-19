import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

enum PanelMode { library, pages, outline, search, notes }

enum ReaderAccent { rose, purple, green }

enum DefaultPageLayout { fitWidth, fitPage }

enum ResolutionMode { defaultSetting, systemSetting }

enum ExportImageFormat { png, jpg }

enum ReaderShortcutAction {
  openFile,
  search,
  clearSearch,
  addNote,
  previousPage,
  nextPage,
  zoomIn,
  zoomOut,
  fitWidth,
  fitPage,
  toggleTheme,
  undoHighlight,
  redoHighlight,
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
  ReaderShortcutAction.addNote: ReaderShortcutBinding(
    keyId: 0x000000000000006e,
    control: true,
    shift: true,
  ),
  ReaderShortcutAction.previousPage: ReaderShortcutBinding(
    keyId: 0x00100000308,
  ),
  ReaderShortcutAction.nextPage: ReaderShortcutBinding(keyId: 0x00100000307),
  ReaderShortcutAction.zoomIn: ReaderShortcutBinding(
    keyId: 0x000000000000003D,
    control: true,
  ),
  ReaderShortcutAction.zoomOut: ReaderShortcutBinding(
    keyId: 0x000000000000002D,
    control: true,
  ),
  ReaderShortcutAction.fitWidth: ReaderShortcutBinding(
    keyId: 0x0000000000000030,
    control: true,
  ),
  ReaderShortcutAction.fitPage: ReaderShortcutBinding(
    keyId: 0x0000000000000031,
    control: true,
  ),
  ReaderShortcutAction.toggleTheme: ReaderShortcutBinding(
    keyId: 0x000000000000006c,
    control: true,
    shift: true,
  ),
  ReaderShortcutAction.undoHighlight: ReaderShortcutBinding(
    keyId: 0x000000000000007A,
    control: true,
  ),
  ReaderShortcutAction.redoHighlight: ReaderShortcutBinding(
    keyId: 0x0000000000000079,
    control: true,
  ),
};

extension ReaderShortcutActionLabel on ReaderShortcutAction {
  String get label {
    return switch (this) {
      ReaderShortcutAction.openFile => '打开 PDF',
      ReaderShortcutAction.search => '搜索内容',
      ReaderShortcutAction.clearSearch => '清除搜索',
      ReaderShortcutAction.addNote => '新建便签',
      ReaderShortcutAction.previousPage => '上一页',
      ReaderShortcutAction.nextPage => '下一页',
      ReaderShortcutAction.zoomIn => '放大',
      ReaderShortcutAction.zoomOut => '缩小',
      ReaderShortcutAction.fitWidth => '适合宽度',
      ReaderShortcutAction.fitPage => '适合页面',
      ReaderShortcutAction.toggleTheme => '切换日夜模式',
      ReaderShortcutAction.undoHighlight => '撤回高亮',
      ReaderShortcutAction.redoHighlight => '重做高亮',
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
    if (keyId == LogicalKeyboardKey.pageUp.keyId) return 'Page Up';
    if (keyId == LogicalKeyboardKey.pageDown.keyId) return 'Page Down';
    if (keyId == LogicalKeyboardKey.arrowLeft.keyId) return '←';
    if (keyId == LogicalKeyboardKey.arrowRight.keyId) return '→';
    if (keyId == LogicalKeyboardKey.arrowUp.keyId) return '↑';
    if (keyId == LogicalKeyboardKey.arrowDown.keyId) return '↓';
    if (keyId == LogicalKeyboardKey.escape.keyId) return 'Esc';
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
    this.resolutionMode = ResolutionMode.defaultSetting,
    this.scrollSensitivity = 3,
    this.quickExportResolution = 192,
    this.quickExportFormat = ExportImageFormat.png,
    this.quickExportNamePattern = '{document}_P{page}',
    this.quickExportFolder,
    this.shortcutBindings = kDefaultShortcutBindings,
  });

  final ReaderAccent accent;
  final DefaultPageLayout defaultPageLayout;
  final bool alwaysOpenWithDefaultLayout;
  final ResolutionMode resolutionMode;
  final double scrollSensitivity;
  final int quickExportResolution;
  final ExportImageFormat quickExportFormat;
  final String quickExportNamePattern;
  final String? quickExportFolder;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;

  static const defaultResolution = 96;

  static int systemResolutionFor(double devicePixelRatio) {
    return (devicePixelRatio * 96).round().clamp(96, 600);
  }

  int effectiveResolutionFor(double devicePixelRatio) {
    return switch (resolutionMode) {
      ResolutionMode.defaultSetting => defaultResolution,
      ResolutionMode.systemSetting => systemResolutionFor(devicePixelRatio),
    };
  }

  ReaderSettings copyWith({
    ReaderAccent? accent,
    DefaultPageLayout? defaultPageLayout,
    bool? alwaysOpenWithDefaultLayout,
    ResolutionMode? resolutionMode,
    double? scrollSensitivity,
    int? quickExportResolution,
    ExportImageFormat? quickExportFormat,
    String? quickExportNamePattern,
    Object? quickExportFolder = _sentinel,
    Map<ReaderShortcutAction, ReaderShortcutBinding>? shortcutBindings,
  }) {
    return ReaderSettings(
      accent: accent ?? this.accent,
      defaultPageLayout: defaultPageLayout ?? this.defaultPageLayout,
      alwaysOpenWithDefaultLayout:
          alwaysOpenWithDefaultLayout ?? this.alwaysOpenWithDefaultLayout,
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
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accent': accent.name,
      'defaultPageLayout': defaultPageLayout.name,
      'alwaysOpenWithDefaultLayout': alwaysOpenWithDefaultLayout,
      'resolutionMode': resolutionMode.name,
      'scrollSensitivity': scrollSensitivity,
      'quickExportResolution': quickExportResolution,
      'quickExportFormat': quickExportFormat.name,
      'quickExportNamePattern': quickExportNamePattern,
      'quickExportFolder': quickExportFolder,
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
        shortcutBindings: shortcuts,
      );
    } catch (_) {
      return const ReaderSettings();
    }
  }
}

const Object _sentinel = Object();

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
  });

  final String name;
  final String path;
  final int? size;
  final int page;
  final DateTime openedAt;
  final String? fileHash;

  RecentDocument copyWith({int? page, DateTime? openedAt, String? fileHash}) {
    return RecentDocument(
      name: name,
      path: path,
      size: size,
      page: page ?? this.page,
      openedAt: openedAt ?? this.openedAt,
      fileHash: fileHash ?? this.fileHash,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'page': page,
      'openedAt': openedAt.toIso8601String(),
      'fileHash': fileHash,
    };
  }

  static RecentDocument? tryDecode(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final path = data['path'] as String?;
      if (path == null || path.isEmpty) {
        return null;
      }
      return RecentDocument(
        name: data['name'] as String? ?? p.basename(path),
        path: path,
        size: data['size'] as int?,
        page: data['page'] as int? ?? 1,
        openedAt:
            DateTime.tryParse(data['openedAt'] as String? ?? '') ??
            DateTime(1970),
        fileHash: data['fileHash'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class SessionDocumentTab {
  const SessionDocumentTab({
    required this.source,
    required this.page,
    required this.openedAt,
  });

  final PdfSource source;
  final int page;
  final DateTime openedAt;

  String get tooltipPath => source.path ?? source.name;

  SessionDocumentTab copyWith({
    PdfSource? source,
    int? page,
    DateTime? openedAt,
  }) {
    return SessionDocumentTab(
      source: source ?? this.source,
      page: page ?? this.page,
      openedAt: openedAt ?? this.openedAt,
    );
  }
}

class PageNote {
  const PageNote({
    required this.id,
    required this.page,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final int page;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'page': page,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static PageNote? tryDecode(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final text = data['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        return null;
      }
      return PageNote(
        id:
            data['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        page: data['page'] as int? ?? 1,
        text: text,
        createdAt:
            DateTime.tryParse(data['createdAt'] as String? ?? '') ??
            DateTime(1970),
      );
    } catch (_) {
      return null;
    }
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

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'page': page,
      'text': text,
      'rects': rects.map((rect) => rect.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'colorValue': colorValue,
    };
  }

  static TextHighlight? tryDecode(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rects = (data['rects'] as List? ?? const [])
          .map((item) => HighlightRect.tryDecode(item))
          .nonNulls
          .toList();
      if (rects.isEmpty) {
        return null;
      }
      return TextHighlight(
        id:
            data['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        page: data['page'] as int? ?? 1,
        text: data['text'] as String? ?? '',
        rects: rects,
        createdAt:
            DateTime.tryParse(data['createdAt'] as String? ?? '') ??
            DateTime(1970),
        colorValue: data['colorValue'] as int? ?? 0x66FFE066,
      );
    } catch (_) {
      return null;
    }
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

  static const recent = 'lumen_pdf.recent';
  static const notes = 'lumen_pdf.notes';
  static const highlights = 'lumen_pdf.highlights';
  static const settings = 'lumen_pdf.settings';
}
