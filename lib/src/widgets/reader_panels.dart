import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/reader_models.dart';
import '../services/translation_services.dart';
import '../theme/app_colors.dart';
import 'reader_toolbar.dart' show PageStepper;
import 'shortcut_tooltip.dart';
import 'themed_context_menu.dart';

const double kReaderPanelWidth = 272;
const double kSingleThumbnailPanelWidth = 152;
const EdgeInsets kThumbnailGridPadding = EdgeInsets.fromLTRB(14, 8, 14, 18);
const double kThumbnailGridGap = 12;

class ReaderPanel extends StatelessWidget {
  const ReaderPanel({
    required this.mode,
    required this.document,
    required this.outline,
    required this.notes,
    required this.highlights,
    required this.selectedNoteId,
    required this.viewportPreviews,
    required this.twoColumnThumbnails,
    required this.thumbnailAnchorPage,
    required this.currentPage,
    required this.pageCount,
    required this.jumpController,
    required this.recent,
    required this.selectedRecentIndex,
    required this.loadingLibrary,
    required this.textSearcher,
    required this.shortcutBindings,
    required this.onOpen,
    required this.onOpenRecent,
    required this.onDeleteRecent,
    required this.onClearRecent,
    required this.onPdfContextMenu,
    required this.onPdf2zhAction,
    required this.onGoToPage,
    required this.onGoToNote,
    required this.onEditNote,
    required this.onUpdateNoteText,
    required this.onGoToNextNote,
    required this.onGoToPreviousNote,
    required this.onGoToOutline,
    required this.onGoToSearchMatch,
    required this.onDeleteNote,
    required this.onAddNote,
    required this.onThumbnailLayoutChanged,
    required this.onThumbnailAnchorPageChanged,
    required this.onJumpSubmitted,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onQuickExportPage,
    required this.onExportPage,
    this.translationSourceText,
    this.translationResult,
    this.onCollapse,
    super.key,
  });

  final PanelMode mode;
  final PdfDocument? document;
  final List<PdfOutlineNode> outline;
  final List<PageNote> notes;
  final List<TextHighlight> highlights;
  final String? selectedNoteId;
  final List<PageViewportPreview> viewportPreviews;
  final bool twoColumnThumbnails;
  final int thumbnailAnchorPage;
  final int currentPage;
  final int pageCount;
  final TextEditingController jumpController;
  final List<RecentDocument> recent;
  final int selectedRecentIndex;
  final bool loadingLibrary;
  final PdfTextSearcher? textSearcher;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;
  final VoidCallback onOpen;
  final ValueChanged<RecentDocument> onOpenRecent;
  final ValueChanged<RecentDocument> onDeleteRecent;
  final VoidCallback onClearRecent;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;
  final void Function(PdfSource source, Pdf2zhAction action) onPdf2zhAction;
  final ValueChanged<int> onGoToPage;
  final ValueChanged<PageNote> onGoToNote;
  final ValueChanged<PageNote> onEditNote;
  final void Function(PageNote note, String text) onUpdateNoteText;
  final VoidCallback onGoToNextNote;
  final VoidCallback onGoToPreviousNote;
  final ValueChanged<PdfDest> onGoToOutline;
  final ValueChanged<int> onGoToSearchMatch;
  final ValueChanged<PageNote> onDeleteNote;
  final VoidCallback onAddNote;
  final ValueChanged<bool> onThumbnailLayoutChanged;
  final ValueChanged<int> onThumbnailAnchorPageChanged;
  final VoidCallback onJumpSubmitted;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onQuickExportPage;
  final ValueChanged<int> onExportPage;
  final String? translationSourceText;
  final SelectionTranslationResult? translationResult;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final width = mode == PanelMode.pages && !twoColumnThumbnails
        ? kSingleThumbnailPanelWidth
        : kReaderPanelWidth;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: switch (mode) {
          PanelMode.library => LibraryPanel(
            recent: recent,
            selectedRecentIndex: selectedRecentIndex,
            loading: loadingLibrary,
            shortcutBindings: shortcutBindings,
            onOpen: onOpen,
            onOpenRecent: onOpenRecent,
            onDeleteRecent: onDeleteRecent,
            onClearRecent: onClearRecent,
            onPdfContextMenu: onPdfContextMenu,
            onPdf2zhAction: onPdf2zhAction,
            onCollapse: onCollapse,
          ),
          PanelMode.pages => PagesPanel(
            document: document,
            viewportPreviews: viewportPreviews,
            twoColumn: twoColumnThumbnails,
            initialThumbnailPage: thumbnailAnchorPage,
            currentPage: currentPage,
            pageCount: pageCount,
            jumpController: jumpController,
            onLayoutChanged: onThumbnailLayoutChanged,
            onVisibleThumbnailPageChanged: onThumbnailAnchorPageChanged,
            onJumpSubmitted: onJumpSubmitted,
            onPreviousPage: onPreviousPage,
            onNextPage: onNextPage,
            onGoToPage: onGoToPage,
            onQuickExportPage: onQuickExportPage,
            onExportPage: onExportPage,
            shortcutBindings: shortcutBindings,
            onCollapse: onCollapse,
          ),
          PanelMode.outline => OutlinePanel(
            outline: outline,
            currentPage: currentPage,
            onGoToDest: onGoToOutline,
            onCollapse: onCollapse,
          ),
          PanelMode.search => SearchPanel(
            textSearcher: textSearcher,
            onGoToSearchMatch: onGoToSearchMatch,
            onCollapse: onCollapse,
          ),
          PanelMode.notes => NotesPanel(
            notes: notes,
            highlights: highlights,
            selectedNoteId: selectedNoteId,
            onGoToNote: onGoToNote,
            onEditNote: onEditNote,
            onUpdateNoteText: onUpdateNoteText,
            onGoToNextNote: onGoToNextNote,
            onGoToPreviousNote: onGoToPreviousNote,
            onDeleteNote: onDeleteNote,
            onAddNote: onAddNote,
            shortcutBindings: shortcutBindings,
            onCollapse: onCollapse,
          ),
          PanelMode.translate => SelectionTranslatePanel(
            sourceText: translationSourceText,
            result: translationResult,
            onCollapse: onCollapse,
          ),
        },
      ),
    );
  }
}

class LibraryPanel extends StatefulWidget {
  const LibraryPanel({
    required this.recent,
    required this.selectedRecentIndex,
    required this.loading,
    required this.shortcutBindings,
    required this.onOpen,
    required this.onOpenRecent,
    required this.onDeleteRecent,
    required this.onClearRecent,
    required this.onPdfContextMenu,
    required this.onPdf2zhAction,
    this.onCollapse,
    super.key,
  });

  final List<RecentDocument> recent;
  final int selectedRecentIndex;
  final bool loading;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;
  final VoidCallback onOpen;
  final ValueChanged<RecentDocument> onOpenRecent;
  final ValueChanged<RecentDocument> onDeleteRecent;
  final VoidCallback onClearRecent;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;
  final void Function(PdfSource source, Pdf2zhAction action) onPdf2zhAction;
  final VoidCallback? onCollapse;

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  Offset? _lastFileSecondaryTapPosition;
  DateTime? _lastFileSecondaryTapAt;

  void _markFileSecondaryTap(Offset position) {
    _lastFileSecondaryTapPosition = position;
    _lastFileSecondaryTapAt = DateTime.now();
  }

  bool _isRecentFileSecondaryTap(Offset position) {
    final lastPosition = _lastFileSecondaryTapPosition;
    final lastAt = _lastFileSecondaryTapAt;
    if (lastPosition == null || lastAt == null) {
      return false;
    }
    final fresh =
        DateTime.now().difference(lastAt) < const Duration(milliseconds: 260);
    return fresh && (lastPosition - position).distance < 10;
  }

  ReaderShortcutBinding? _shortcut(ReaderShortcutAction action) {
    return widget.shortcutBindings[action] ?? kDefaultShortcutBindings[action];
  }

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      key: const ValueKey('library'),
      title: '\u8d44\u6599\u5e93',
      subtitle:
          '\u672c\u673a PDF\u3001\u6700\u8fd1\u9605\u8bfb\u548c\u5de5\u4f5c\u5165\u53e3',
      onCollapse: widget.onCollapse,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) async {
          if (_isRecentFileSecondaryTap(details.globalPosition)) {
            return;
          }
          final action = await showThemedContextMenu<_LibraryBlankAction>(
            context: context,
            position: details.globalPosition,
            items: [
              themedContextMenuItem(
                value: _LibraryBlankAction.clearRecent,
                label: '\u6e05\u7a7a\u5168\u90e8',
                danger: true,
              ),
            ],
          );
          if (!context.mounted) {
            return;
          }
          if (action == _LibraryBlankAction.clearRecent &&
              await _confirmClearRecent(context)) {
            widget.onClearRecent();
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          children: [
            ShortcutTooltip(
              label: '\u6253\u5f00 PDF \u6587\u4ef6',
              shortcut: _shortcut(ReaderShortcutAction.openFile),
              child: FilledButton.icon(
                onPressed: widget.onOpen,
                icon: Icon(Icons.folder_open_rounded),
                label: const Text('\u6253\u5f00 PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const PanelSectionTitle('\u6700\u8fd1\u6587\u4ef6'),
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.recent.isEmpty)
              const EmptyPanelMessage(
                icon: Icons.history_rounded,
                title: '\u8fd8\u6ca1\u6709\u6700\u8fd1\u6587\u4ef6',
                body:
                    '\u6253\u5f00 PDF \u540e\uff0c\u8fd9\u91cc\u4f1a\u4fdd\u7559\u9605\u8bfb\u8fdb\u5ea6\u3002',
              )
            else ...[
              for (var index = 0; index < widget.recent.length; index++)
                RecentTile(
                  selected: index == widget.selectedRecentIndex,
                  item: widget.recent[index],
                  onTap: () => widget.onOpenRecent(widget.recent[index]),
                  onDelete: () => widget.onDeleteRecent(widget.recent[index]),
                  onPdfContextMenu: widget.onPdfContextMenu,
                  onPdf2zhAction: widget.onPdf2zhAction,
                  onClearRecent: widget.onClearRecent,
                  onContextMenuStart: _markFileSecondaryTap,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _LibraryBlankAction { clearRecent }

Future<bool> _confirmClearRecent(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '\u6e05\u7a7a\u5168\u90e8\u6700\u8fd1\u6587\u4ef6',
          style: TextStyle(color: AppColors.ink),
        ),
        content: Text(
          '\u8fd9\u53ea\u4f1a\u6e05\u7a7a\u6700\u8fd1\u6587\u4ef6\u8bb0\u5f55\uff0c\u4e0d\u4f1a\u5220\u9664\u672c\u5730 PDF \u6587\u4ef6\u6216\u6587\u4ef6\u6570\u636e\u3002',
          style: TextStyle(color: AppColors.subtle, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.surface,
            ),
            child: const Text('\u6e05\u7a7a\u5168\u90e8'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

class SelectionTranslatePanel extends StatelessWidget {
  const SelectionTranslatePanel({
    required this.sourceText,
    required this.result,
    this.onCollapse,
    super.key,
  });

  final String? sourceText;
  final SelectionTranslationResult? result;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final text = sourceText?.trim();
    final translated = result?.translation.trim();
    final dictionary = result?.dictionary.trim();
    final isDictionaryTerm = _looksLikeDictionaryTerm(text);
    final showTranslation =
        !isDictionaryTerm && (translated == null || translated.isNotEmpty);
    final dictionaryText = dictionary == null || dictionary.isEmpty
        ? (result == null ? '正在查询字典...' : '未返回字典结果。')
        : dictionary;
    return PanelScaffold(
      key: const ValueKey('translate'),
      title: '\u5212\u8bcd\u7ffb\u8bd1',
      subtitle: text == null || text.isEmpty
          ? null
          : '\u5f53\u524d\u9009\u4e2d\u6587\u672c',
      onCollapse: onCollapse,
      child: text == null || text.isEmpty
          ? const EmptyPanelMessage(
              icon: Icons.translate_rounded,
              title: '\u8fd8\u6ca1\u6709\u9009\u4e2d\u6587\u672c',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              children: [
                _TranslateBlock(title: '\u539f\u6587', text: text),
                if (result != null && result!.audio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PronunciationBlock(audio: result!.audio),
                ],
                if (isDictionaryTerm) ...[
                  const SizedBox(height: 12),
                  _DictionaryBlock(text: dictionaryText),
                ],
                if (showTranslation) ...[
                  const SizedBox(height: 12),
                  _TranslateBlock(
                    title: '译文',
                    text: translated == null || translated.isEmpty
                        ? '正在翻译...'
                        : translated,
                  ),
                ],
                if (!isDictionaryTerm &&
                    dictionary != null &&
                    dictionary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DictionaryBlock(text: dictionary),
                ],
              ],
            ),
    );
  }

  bool _looksLikeDictionaryTerm(String? text) {
    return text != null &&
        SelectionTranslationService.dictionaryLookupTerm(text) != null;
  }
}

class _PronunciationBlock extends StatefulWidget {
  const _PronunciationBlock({required this.audio});

  final List<PronunciationAudio> audio;

  @override
  State<_PronunciationBlock> createState() => _PronunciationBlockState();
}

class _PronunciationBlockState extends State<_PronunciationBlock> {
  final _player = AudioPlayer();
  String? _playingUrl;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(PronunciationAudio item) async {
    setState(() => _playingUrl = item.url);
    try {
      await _player.stop();
      await _player.play(UrlSource(item.url));
    } finally {
      if (mounted) {
        setState(() => _playingUrl = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Text(
            '发音',
            style: TextStyle(
              color: AppColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in widget.audio.take(2))
                  Tooltip(
                    message: item.text.isEmpty ? '播放发音' : item.text,
                    child: IconButton.filledTonal(
                      onPressed: () => _play(item),
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Text(
                        item.accent == PronunciationAccent.uk ? '英' : '美',
                        style: TextStyle(
                          color: _playingUrl == item.url
                              ? AppColors.ink
                              : AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DictionaryBlock extends StatelessWidget {
  const _DictionaryBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final head = lines.isEmpty ? '' : lines.first;
    final body = lines.skip(head.isEmpty ? 0 : 1).join('\n');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '字典',
            style: TextStyle(
              color: AppColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (head.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              head,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              body,
              style: TextStyle(
                color: AppColors.ink,
                height: 1.42,
                fontSize: 13.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranslateBlock extends StatelessWidget {
  const _TranslateBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: TextStyle(color: AppColors.ink, height: 1.35, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class PagesPanel extends StatefulWidget {
  const PagesPanel({
    required this.document,
    required this.viewportPreviews,
    required this.twoColumn,
    required this.initialThumbnailPage,
    required this.currentPage,
    required this.pageCount,
    required this.jumpController,
    required this.onLayoutChanged,
    required this.onVisibleThumbnailPageChanged,
    required this.onJumpSubmitted,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onGoToPage,
    required this.onQuickExportPage,
    required this.onExportPage,
    required this.shortcutBindings,
    this.onCollapse,
    super.key,
  });

  final PdfDocument? document;
  final List<PageViewportPreview> viewportPreviews;
  final bool twoColumn;
  final int initialThumbnailPage;
  final int currentPage;
  final int pageCount;
  final TextEditingController jumpController;
  final ValueChanged<bool> onLayoutChanged;
  final ValueChanged<int> onVisibleThumbnailPageChanged;
  final VoidCallback onJumpSubmitted;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onGoToPage;
  final ValueChanged<int> onQuickExportPage;
  final ValueChanged<int> onExportPage;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;
  final VoidCallback? onCollapse;

  @override
  State<PagesPanel> createState() => _PagesPanelState();
}

class _PagesPanelState extends State<PagesPanel> {
  final _thumbnailScrollController = ScrollController();
  double? _gridWidth;
  bool _autoScrollScheduled = false;
  bool _restoreScrollScheduled = false;
  int _restoreAttempts = 0;
  int? _lastReportedThumbnailPage;
  double? _lastPreviewCenterY;
  int _lastPreviewDirection = 1;

  ReaderShortcutBinding? _shortcut(ReaderShortcutAction action) {
    return widget.shortcutBindings[action] ?? kDefaultShortcutBindings[action];
  }

  @override
  void initState() {
    super.initState();
    _thumbnailScrollController.addListener(_handleThumbnailScroll);
    _scheduleRestoreThumbnailPage();
  }

  @override
  void dispose() {
    _thumbnailScrollController.removeListener(_handleThumbnailScroll);
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.twoColumn != widget.twoColumn) {
      _scheduleRestoreThumbnailPage(resetAttempts: true);
    }
    if (oldWidget.viewportPreviews != widget.viewportPreviews ||
        oldWidget.twoColumn != widget.twoColumn ||
        oldWidget.document != widget.document) {
      _scheduleViewportAutoScroll();
    }
  }

  void _handleThumbnailScroll() {
    final page = _visibleThumbnailAnchorPage();
    if (page == null || page == _lastReportedThumbnailPage) {
      return;
    }
    _lastReportedThumbnailPage = page;
    widget.onVisibleThumbnailPageChanged(page);
  }

  void _handleThumbnailPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !_thumbnailScrollController.hasClients) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      _thumbnailScrollController.position.pointerScroll(
        event.scrollDelta.dy * 10,
      );
    });
  }

  void _scheduleViewportAutoScroll() {
    if (_autoScrollScheduled) {
      return;
    }
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (mounted) {
        _scrollViewportPreviewIntoView();
      }
    });
  }

  void _scheduleRestoreThumbnailPage({bool resetAttempts = false}) {
    if (resetAttempts) {
      _restoreAttempts = 0;
    }
    if (_restoreScrollScheduled) {
      return;
    }
    _restoreScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollScheduled = false;
      if (mounted) {
        final restored = _restoreThumbnailPage();
        if (!restored && _restoreAttempts < 10) {
          _restoreAttempts++;
          _scheduleRestoreThumbnailPage();
        }
      }
    });
  }

  bool _restoreThumbnailPage() {
    final document = widget.document;
    final gridWidth = _gridWidth;
    if (document == null ||
        gridWidth == null ||
        !_thumbnailScrollController.hasClients ||
        !_thumbnailScrollController.position.hasContentDimensions) {
      return false;
    }
    final target = _scrollOffsetForThumbnailPage(
      widget.initialThumbnailPage,
      document,
      gridWidth,
    );
    if (target == null) {
      return false;
    }
    final position = _thumbnailScrollController.position;
    if (target > 0 && position.maxScrollExtent <= 0) {
      return false;
    }
    _thumbnailScrollController.jumpTo(
      target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
    _handleThumbnailScroll();
    return true;
  }

  void _scrollViewportPreviewIntoView() {
    final document = widget.document;
    final gridWidth = _gridWidth;
    if (document == null ||
        widget.viewportPreviews.isEmpty ||
        gridWidth == null ||
        !_thumbnailScrollController.hasClients ||
        !_thumbnailScrollController.position.hasContentDimensions) {
      return;
    }

    final target = _autoScrollTargetForVisiblePreviews(document, gridWidth);
    if (target == null) {
      return;
    }

    final position = _thumbnailScrollController.position;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 1) {
      return;
    }
    unawaited(
      _thumbnailScrollController.animateTo(
        clamped.toDouble(),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  double? _autoScrollTargetForVisiblePreviews(
    PdfDocument document,
    double gridWidth,
  ) {
    final position = _thumbnailScrollController.position;
    final visibleTop = position.pixels + 4;
    final visibleBottom = position.pixels + position.viewportDimension - 4;
    final previewRects = _previewRectsInScrollSpace(document, gridWidth);
    if (previewRects.isEmpty) {
      return null;
    }
    final direction = _resolvePreviewDirection(previewRects);
    const hysteresis = 18.0;

    if (direction >= 0) {
      final leading = previewRects.last.rect;
      if (leading.bottom > visibleBottom + hysteresis) {
        return leading.top - kThumbnailGridPadding.top;
      }
      return null;
    }

    final leading = previewRects.first.rect;
    if (leading.top < visibleTop - hysteresis) {
      return leading.bottom -
          position.viewportDimension +
          kThumbnailGridPadding.bottom;
    }
    return null;
  }

  int _resolvePreviewDirection(List<_PreviewScrollRect> previewRects) {
    final first = previewRects.first.rect;
    final last = previewRects.last.rect;
    final center = (first.top + last.bottom) / 2;
    final previousCenter = _lastPreviewCenterY;
    _lastPreviewCenterY = center;
    if (previousCenter == null) {
      return _lastPreviewDirection;
    }
    final delta = center - previousCenter;
    if (delta.abs() < 1.5) {
      return _lastPreviewDirection;
    }
    _lastPreviewDirection = delta > 0 ? 1 : -1;
    return _lastPreviewDirection;
  }

  int? _visibleThumbnailAnchorPage() {
    final document = widget.document;
    final gridWidth = _gridWidth;
    if (document == null ||
        gridWidth == null ||
        !_thumbnailScrollController.hasClients) {
      return null;
    }
    final metrics = _thumbnailGridMetrics(gridWidth);
    if (metrics == null) {
      return null;
    }
    final firstContentY = math.max(
      0.0,
      _thumbnailScrollController.offset - kThumbnailGridPadding.top,
    );
    final row = (firstContentY / (metrics.cellHeight + kThumbnailGridGap))
        .floor();
    final page = row * metrics.crossAxisCount + 1;
    return page.clamp(1, document.pages.length);
  }

  double? _scrollOffsetForThumbnailPage(
    int page,
    PdfDocument document,
    double gridWidth,
  ) {
    final metrics = _thumbnailGridMetrics(gridWidth);
    if (metrics == null || document.pages.isEmpty) {
      return null;
    }
    final pageIndex = page.clamp(1, document.pages.length) - 1;
    final row = pageIndex ~/ metrics.crossAxisCount;
    return kThumbnailGridPadding.top +
        row * (metrics.cellHeight + kThumbnailGridGap);
  }

  List<_PreviewScrollRect> _previewRectsInScrollSpace(
    PdfDocument document,
    double gridWidth,
  ) {
    final metrics = _thumbnailGridMetrics(gridWidth);
    if (metrics == null) {
      return const [];
    }
    final rects = <_PreviewScrollRect>[];

    for (final preview in widget.viewportPreviews) {
      final pageIndex = preview.page - 1;
      if (pageIndex < 0 || pageIndex >= document.pages.length) {
        continue;
      }
      final page = document.pages[pageIndex];
      final row = pageIndex ~/ metrics.crossAxisCount;
      final column = pageIndex % metrics.crossAxisCount;
      final cellLeft =
          kThumbnailGridPadding.left +
          column * (metrics.cellWidth + kThumbnailGridGap);
      final cellTop =
          kThumbnailGridPadding.top +
          row * (metrics.cellHeight + kThumbnailGridGap);
      final pageRect = _thumbnailPagePaintRect(
        Size(metrics.cellWidth, metrics.imageHeight),
        Size(page.width, page.height),
      ).shift(Offset(cellLeft, cellTop));
      for (final rect in preview.rects) {
        rects.add(
          _PreviewScrollRect(
            page: preview.page,
            rect: Rect.fromLTRB(
              pageRect.left + rect.left.clamp(0.0, 1.0) * pageRect.width,
              pageRect.top + rect.top.clamp(0.0, 1.0) * pageRect.height,
              pageRect.left + rect.right.clamp(0.0, 1.0) * pageRect.width,
              pageRect.top + rect.bottom.clamp(0.0, 1.0) * pageRect.height,
            ),
          ),
        );
      }
    }

    rects.sort((a, b) {
      final top = a.rect.top.compareTo(b.rect.top);
      return top == 0 ? a.rect.left.compareTo(b.rect.left) : top;
    });
    return rects;
  }

  _ThumbnailGridMetrics? _thumbnailGridMetrics(double gridWidth) {
    final crossAxisCount = widget.twoColumn ? 2 : 1;
    final contentWidth =
        gridWidth - kThumbnailGridPadding.left - kThumbnailGridPadding.right;
    if (contentWidth <= 0) {
      return null;
    }
    final cellWidth =
        (contentWidth - kThumbnailGridGap * (crossAxisCount - 1)) /
        crossAxisCount;
    if (cellWidth <= 0) {
      return null;
    }
    const childAspectRatio = 0.63;
    final cellHeight = cellWidth / childAspectRatio;
    return _ThumbnailGridMetrics(
      crossAxisCount: crossAxisCount,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      imageHeight: math.max(0.0, cellHeight - 32),
    );
  }

  Rect _thumbnailPagePaintRect(Size canvasSize, Size pageSize) {
    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        pageSize.width <= 0 ||
        pageSize.height <= 0) {
      return Rect.zero;
    }
    final pageAspect = pageSize.width / pageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;
    if (canvasAspect > pageAspect) {
      final height = canvasSize.height;
      final width = height * pageAspect;
      return Rect.fromLTWH((canvasSize.width - width) / 2, 0, width, height);
    }
    final width = canvasSize.width;
    final height = width / pageAspect;
    return Rect.fromLTWH(0, (canvasSize.height - height) / 2, width, height);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final crossAxisCount = widget.twoColumn ? 2 : 1;
    final viewportPreviewByPage = {
      for (final preview in widget.viewportPreviews) preview.page: preview,
    };
    return PanelScaffold(
      key: const ValueKey('pages'),
      title: '\u9875\u9762',
      subtitle: doc == null
          ? '\u7b49\u5f85\u6587\u6863\u8f7d\u5165'
          : widget.twoColumn
          ? '\u53cc\u9875\u7f29\u7565\u56fe'
          : '\u5355\u9875',
      trailing: doc == null
          ? null
          : ThumbnailLayoutToggle(
              twoColumn: widget.twoColumn,
              compact: !widget.twoColumn,
              shortcut: _shortcut(ReaderShortcutAction.toggleThumbnailLayout),
              onChanged: widget.onLayoutChanged,
            ),
      onCollapse: widget.onCollapse,
      child: doc == null
          ? const EmptyPanelMessage(
              icon: Icons.view_module_outlined,
              title: '\u6253\u5f00 PDF \u540e\u67e5\u770b\u7f29\u7565\u56fe',
              body:
                  '\u9875\u9762\u9884\u89c8\u4f1a\u968f\u7740\u6587\u6863\u8f7d\u5165\u751f\u6210\u3002',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return PageStepper(
                        width: constraints.maxWidth,
                        dense: true,
                        narrow: !widget.twoColumn,
                        controller: widget.jumpController,
                        currentPage: widget.currentPage,
                        pageCount: widget.pageCount,
                        onSubmitted: widget.onJumpSubmitted,
                        onPrevious: widget.onPreviousPage,
                        onNext: widget.onNextPage,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final previousGridWidth = _gridWidth;
                      _gridWidth = constraints.maxWidth;
                      if (previousGridWidth == null ||
                          (previousGridWidth - constraints.maxWidth).abs() >
                              1) {
                        _scheduleRestoreThumbnailPage();
                        _scheduleViewportAutoScroll();
                      }
                      return GridView.builder(
                        controller: _thumbnailScrollController,
                        physics: const _ThumbnailScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        padding: kThumbnailGridPadding,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: kThumbnailGridGap,
                          crossAxisSpacing: kThumbnailGridGap,
                          childAspectRatio: widget.twoColumn ? 0.63 : 0.63,
                        ),
                        itemCount: doc.pages.length,
                        itemBuilder: (context, index) {
                          final page = index + 1;
                          return Listener(
                            onPointerSignal: _handleThumbnailPointerSignal,
                            child: PageThumb(
                              document: doc,
                              pageNumber: page,
                              viewportPreview: viewportPreviewByPage[page],
                              onTap: () => widget.onGoToPage(page),
                              onQuickExport: () =>
                                  widget.onQuickExportPage(page),
                              onExport: () => widget.onExportPage(page),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class ThumbnailLayoutToggle extends StatelessWidget {
  const ThumbnailLayoutToggle({
    required this.twoColumn,
    required this.compact,
    required this.shortcut,
    required this.onChanged,
    super.key,
  });

  final bool twoColumn;
  final bool compact;
  final ReaderShortcutBinding? shortcut;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ShortcutTooltip(
        label: twoColumn
            ? '\u5207\u6362\u4e3a\u5355\u9875\u7f29\u7565\u56fe'
            : '\u5207\u6362\u4e3a\u53cc\u9875\u7f29\u7565\u56fe',
        shortcut: shortcut,
        child: Switch(
          value: twoColumn,
          onChanged: onChanged,
          activeThumbColor: AppColors.accent,
          inactiveThumbColor: AppColors.subtle,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Container(
      width: 128,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _ThumbnailLayoutChoice(
            selected: !twoColumn,
            tooltip: '\u5355\u9875\u7f29\u7565\u56fe',
            icon: Icons.crop_portrait_rounded,
            showSelectedIcon: true,
            shortcut: shortcut,
            onTap: () => onChanged(false),
          ),
          Container(width: 1, height: 34, color: AppColors.line),
          _ThumbnailLayoutChoice(
            selected: twoColumn,
            tooltip: '\u53cc\u9875\u7f29\u7565\u56fe',
            icon: Icons.view_module_rounded,
            showSelectedIcon: true,
            shortcut: shortcut,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailLayoutChoice extends StatelessWidget {
  const _ThumbnailLayoutChoice({
    required this.selected,
    required this.tooltip,
    required this.icon,
    required this.showSelectedIcon,
    required this.onTap,
    this.shortcut,
  });

  final bool selected;
  final String tooltip;
  final IconData icon;
  final bool showSelectedIcon;
  final VoidCallback onTap;
  final ReaderShortcutBinding? shortcut;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ShortcutTooltip(
        label: tooltip,
        shortcut: shortcut,
        child: InkWell(
          onTap: selected ? null : onTap,
          child: ColoredBox(
            color: selected ? AppColors.accentSoft : Colors.transparent,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected && showSelectedIcon) ...[
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? AppColors.accent : AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailGridMetrics {
  const _ThumbnailGridMetrics({
    required this.crossAxisCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.imageHeight,
  });

  final int crossAxisCount;
  final double cellWidth;
  final double cellHeight;
  final double imageHeight;
}

class _PreviewScrollRect {
  const _PreviewScrollRect({required this.page, required this.rect});

  final int page;
  final Rect rect;
}

class PageThumb extends StatelessWidget {
  const PageThumb({
    required this.document,
    required this.pageNumber,
    required this.viewportPreview,
    required this.onTap,
    required this.onQuickExport,
    required this.onExport,
    super.key,
  });

  final PdfDocument document;
  final int pageNumber;
  final PageViewportPreview? viewportPreview;
  final VoidCallback onTap;
  final VoidCallback onQuickExport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ColoredBox(
                color: AppColors.surface,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PdfPageView(
                      document: document,
                      pageNumber: pageNumber,
                      alignment: Alignment.center,
                      maximumDpi: 156,
                      decoration: const BoxDecoration(color: Color(0xFFFFFCF9)),
                      backgroundColor: const Color(0xFFFFFCF9),
                    ),
                    if (viewportPreview != null && !viewportPreview!.isEmpty)
                      IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final page = document.pages[pageNumber - 1];
                            return CustomPaint(
                              painter: _PageViewportPreviewPainter(
                                pageSize: Size(page.width, page.height),
                                rects: viewportPreview!.rects,
                                color: AppColors.accent,
                              ),
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Text(
                '$pageNumber',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              PopupMenuButton<_PageThumbAction>(
                tooltip: '\u9875\u9762\u64cd\u4f5c',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 128),
                color: AppColors.surface,
                position: PopupMenuPosition.under,
                onSelected: (action) {
                  switch (action) {
                    case _PageThumbAction.quickExport:
                      onQuickExport();
                      break;
                    case _PageThumbAction.export:
                      onExport();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _PageThumbAction.quickExport,
                    child: Text('\u5feb\u901f\u5bfc\u51fa'),
                  ),
                  PopupMenuItem(
                    value: _PageThumbAction.export,
                    child: Text('\u666e\u901a\u5bfc\u51fa'),
                  ),
                ],
                child: SizedBox(
                  width: 32,
                  height: 24,
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.ink,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageViewportPreviewPainter extends CustomPainter {
  const _PageViewportPreviewPainter({
    required this.pageSize,
    required this.rects,
    required this.color,
  });

  final Size pageSize;
  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (pageSize.width <= 0 ||
        pageSize.height <= 0 ||
        size.width <= 0 ||
        size.height <= 0 ||
        rects.isEmpty) {
      return;
    }

    final pageRect = _pagePaintRect(size);
    final mappedRects = [
      for (final rect in rects) _mapNormalizedRect(rect, pageRect),
    ].where((rect) => rect.width > 0.5 && rect.height > 0.5).toList();
    if (mappedRects.isEmpty) {
      return;
    }

    final shadePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(pageRect);
    for (final rect in mappedRects) {
      shadePath.addRect(rect);
    }
    canvas.drawPath(
      shadePath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.13)
        ..style = PaintingStyle.fill,
    );

    final strokeWidth = (math.min(pageRect.width, pageRect.height) * 0.012)
        .clamp(1.4, 2.4)
        .toDouble();
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter;

    for (final rect in mappedRects) {
      final visibleRect = rect
          .intersect(pageRect)
          .deflate(math.min(strokeWidth / 2, rect.shortestSide / 4));
      if (visibleRect.width > 0 && visibleRect.height > 0) {
        canvas.drawRect(visibleRect, strokePaint);
      }
    }
  }

  Rect _pagePaintRect(Size canvasSize) {
    final pageAspect = pageSize.width / pageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;
    if (canvasAspect > pageAspect) {
      final height = canvasSize.height;
      final width = height * pageAspect;
      return Rect.fromLTWH((canvasSize.width - width) / 2, 0, width, height);
    }
    final width = canvasSize.width;
    final height = width / pageAspect;
    return Rect.fromLTWH(0, (canvasSize.height - height) / 2, width, height);
  }

  Rect _mapNormalizedRect(Rect rect, Rect pageRect) {
    final left = pageRect.left + rect.left.clamp(0.0, 1.0) * pageRect.width;
    final top = pageRect.top + rect.top.clamp(0.0, 1.0) * pageRect.height;
    final right = pageRect.left + rect.right.clamp(0.0, 1.0) * pageRect.width;
    final bottom = pageRect.top + rect.bottom.clamp(0.0, 1.0) * pageRect.height;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant _PageViewportPreviewPainter oldDelegate) {
    return oldDelegate.pageSize != pageSize ||
        oldDelegate.color != color ||
        oldDelegate.rects.length != rects.length ||
        !_rectListsEqual(oldDelegate.rects, rects);
  }

  bool _rectListsEqual(List<Rect> first, List<Rect> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) {
        return false;
      }
    }
    return true;
  }
}

enum _PageThumbAction { quickExport, export }

class _ThumbnailScrollPhysics extends ClampingScrollPhysics {
  const _ThumbnailScrollPhysics({super.parent});

  static const double _wheelMultiplier = 10;

  @override
  _ThumbnailScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ThumbnailScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super.applyPhysicsToUserOffset(position, offset * _wheelMultiplier);
  }
}

class OutlinePanel extends StatefulWidget {
  const OutlinePanel({
    required this.outline,
    required this.currentPage,
    required this.onGoToDest,
    this.onCollapse,
    super.key,
  });

  final List<PdfOutlineNode> outline;
  final int currentPage;
  final ValueChanged<PdfDest> onGoToDest;
  final VoidCallback? onCollapse;

  @override
  State<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends State<OutlinePanel> {
  final Set<String> _collapsedOutlinePaths = <String>{};
  String? _selectedOutlinePath;

  @override
  void didUpdateWidget(covariant OutlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outline != widget.outline) {
      _collapsedOutlinePaths.clear();
      _selectedOutlinePath = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roots = _displayOutlineRoots(widget.outline);
    final entries = _flattenOutlineEntries(roots);
    final activePath =
        _visibleSelectedOutlinePath(entries) ??
        _activeOutlinePath(entries, widget.currentPage);
    return PanelScaffold(
      key: const ValueKey('outline'),
      title: '\u76ee\u5f55',
      subtitle: widget.outline.isEmpty
          ? '\u672a\u68c0\u6d4b\u5230\u6587\u6863\u76ee\u5f55'
          : null,
      onCollapse: widget.onCollapse,
      child: widget.outline.isEmpty
          ? const EmptyPanelMessage(
              icon: Icons.bookmark_border_rounded,
              title: '\u6ca1\u6709\u53ef\u7528\u76ee\u5f55',
              body:
                  '\u90e8\u5206\u626b\u63cf\u4ef6\u6216\u5bfc\u51fa\u6587\u4ef6\u4e0d\u4f1a\u5305\u542b PDF \u5927\u7eb2\u3002',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(6, 8, 8, 18),
              children: [
                for (var i = 0; i < entries.length; i++)
                  _OutlineNodeTile(
                    entry: entries[i],
                    active: entries[i].path == activePath,
                    onToggle: _toggleEntry,
                    onActivate: _activateEntry,
                  ),
              ],
            ),
    );
  }

  List<PdfOutlineNode> _displayOutlineRoots(List<PdfOutlineNode> nodes) {
    if (nodes.length == 1 && nodes.first.children.isNotEmpty) {
      return nodes.first.children;
    }
    return nodes;
  }

  List<_OutlineEntry> _flattenOutlineEntries(List<PdfOutlineNode> nodes) {
    final entries = <_OutlineEntry>[];

    void walk(
      List<PdfOutlineNode> currentNodes,
      int depth,
      List<bool> ancestorHasNext,
      List<int> pathPrefix,
    ) {
      for (var i = 0; i < currentNodes.length; i++) {
        final node = currentNodes[i];
        final hasNextSibling = i < currentNodes.length - 1;
        final path = [...pathPrefix, i];
        final pathKey = path.join('.');
        final collapsed = _collapsedOutlinePaths.contains(pathKey);
        entries.add(
          _OutlineEntry(
            node: node,
            path: pathKey,
            depth: depth,
            ancestorHasNext: List<bool>.of(ancestorHasNext),
            hasNextSibling: hasNextSibling,
            collapsed: collapsed,
          ),
        );
        if (node.children.isNotEmpty && !collapsed) {
          walk(node.children, depth + 1, [
            ...ancestorHasNext,
            hasNextSibling,
          ], path);
        }
      }
    }

    walk(nodes, 0, const [], const []);
    return entries;
  }

  String? _activeOutlinePath(List<_OutlineEntry> entries, int page) {
    String? activePath;
    var activePage = -1;
    for (var i = 0; i < entries.length; i++) {
      final pageNumber = entries[i].pageNumber;
      if (pageNumber == null || pageNumber > page || pageNumber < activePage) {
        continue;
      }
      activePath = entries[i].path;
      activePage = pageNumber;
    }
    return activePath;
  }

  String? _visibleSelectedOutlinePath(List<_OutlineEntry> entries) {
    final selectedPath = _selectedOutlinePath;
    if (selectedPath == null) {
      return null;
    }
    return entries.any((entry) => entry.path == selectedPath)
        ? selectedPath
        : null;
  }

  void _toggleEntry(String path) {
    setState(() {
      if (!_collapsedOutlinePaths.add(path)) {
        _collapsedOutlinePaths.remove(path);
      }
    });
  }

  void _activateEntry(_OutlineEntry entry) {
    final dest = entry.node.dest;
    if (dest == null) {
      return;
    }
    setState(() => _selectedOutlinePath = entry.path);
    widget.onGoToDest(dest);
  }
}

class _OutlineEntry {
  const _OutlineEntry({
    required this.node,
    required this.path,
    required this.depth,
    required this.ancestorHasNext,
    required this.hasNextSibling,
    required this.collapsed,
  });

  final PdfOutlineNode node;
  final String path;
  final int depth;
  final List<bool> ancestorHasNext;
  final bool hasNextSibling;
  final bool collapsed;

  bool get hasChildren => node.children.isNotEmpty;
  int? get pageNumber => node.dest?.pageNumber;
}

class _OutlineNodeTile extends StatelessWidget {
  const _OutlineNodeTile({
    required this.entry,
    required this.active,
    required this.onToggle,
    required this.onActivate,
  });

  final _OutlineEntry entry;
  final bool active;
  final ValueChanged<String> onToggle;
  final ValueChanged<_OutlineEntry> onActivate;

  @override
  Widget build(BuildContext context) {
    final dest = entry.node.dest;
    final textColor = active ? AppColors.accent : AppColors.ink;
    final pageNumber = entry.pageNumber;
    final lineHeight = entry.depth == 0 ? 34.0 : 30.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: dest == null ? null : () => onActivate(entry),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: lineHeight,
          decoration: BoxDecoration(
            color: active ? AppColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              _OutlineTreeLead(
                entry: entry,
                active: active,
                onToggle: onToggle,
                height: lineHeight,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: entry.depth == 0 ? 13.5 : 13,
                    height: 1.15,
                    fontWeight: active
                        ? FontWeight.w800
                        : entry.depth == 0
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  pageNumber?.toString() ?? '',
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: active ? AppColors.accent : AppColors.subtle,
                    fontSize: 12.5,
                    height: 1.1,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineTreeLead extends StatelessWidget {
  const _OutlineTreeLead({
    required this.entry,
    required this.active,
    required this.onToggle,
    required this.height,
  });

  final _OutlineEntry entry;
  final bool active;
  final ValueChanged<String> onToggle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = 18.0 + entry.depth * 16.0;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _OutlineTreeLeadPainter(
                depth: entry.depth,
                ancestorHasNext: entry.ancestorHasNext,
                hasNextSibling: entry.hasNextSibling,
                color: AppColors.line,
              ),
            ),
          ),
          Positioned(
            left: entry.depth * 16.0,
            top: 0,
            bottom: 0,
            width: 18,
            child: Center(
              child: _OutlineMarker(
                entry: entry,
                active: active,
                onToggle: onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineMarker extends StatelessWidget {
  const _OutlineMarker({
    required this.entry,
    required this.active,
    required this.onToggle,
  });

  final _OutlineEntry entry;
  final bool active;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (entry.hasChildren) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggle(entry.path),
        child: SizedBox.square(
          dimension: 22,
          child: Icon(
            entry.collapsed
                ? Icons.keyboard_arrow_right_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: active ? AppColors.accent : AppColors.ink,
          ),
        ),
      );
    }
    if (active) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox(width: 7, height: 7);
  }
}

class _OutlineTreeLeadPainter extends CustomPainter {
  const _OutlineTreeLeadPainter({
    required this.depth,
    required this.ancestorHasNext,
    required this.hasNextSibling,
    required this.color,
  });

  final int depth;
  final List<bool> ancestorHasNext;
  final bool hasNextSibling;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (depth == 0) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final centerY = size.height / 2;

    for (var i = 0; i < ancestorHasNext.length; i++) {
      if (!ancestorHasNext[i]) {
        continue;
      }
      final x = i * 16.0 + 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final currentX = depth * 16.0 + 9;
    canvas.drawLine(Offset(currentX, 0), Offset(currentX, centerY), paint);
    if (hasNextSibling) {
      canvas.drawLine(
        Offset(currentX, centerY),
        Offset(currentX, size.height),
        paint,
      );
    }
    canvas.drawLine(
      Offset(currentX, centerY),
      Offset(currentX + 8, centerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlineTreeLeadPainter oldDelegate) {
    return depth != oldDelegate.depth ||
        hasNextSibling != oldDelegate.hasNextSibling ||
        color != oldDelegate.color ||
        ancestorHasNext.length != oldDelegate.ancestorHasNext.length ||
        !_sameBoolList(ancestorHasNext, oldDelegate.ancestorHasNext);
  }

  bool _sameBoolList(List<bool> a, List<bool> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

class SearchPanel extends StatelessWidget {
  const SearchPanel({
    required this.textSearcher,
    required this.onGoToSearchMatch,
    this.onCollapse,
    super.key,
  });

  final PdfTextSearcher? textSearcher;
  final ValueChanged<int> onGoToSearchMatch;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final matches = textSearcher?.matches ?? const <PdfPageTextRange>[];
    final isSearching = textSearcher?.isSearching ?? false;
    final currentIndex = textSearcher?.currentIndex;
    final total = matches.length;
    return PanelScaffold(
      key: const ValueKey('search'),
      title: '\u641c\u7d22\u7ed3\u679c',
      subtitle: isSearching
          ? '\u6b63\u5728\u626b\u63cf\u6587\u672c\u5c42'
          : '$total \u4e2a\u5339\u914d',
      onCollapse: onCollapse,
      child: total == 0
          ? EmptyPanelMessage(
              icon: Icons.search_rounded,
              title: isSearching
                  ? '\u641c\u7d22\u4e2d'
                  : '\u6682\u65e0\u7ed3\u679c',
              body: isSearching
                  ? '\u6b63\u5728\u8bfb\u53d6 PDF \u6587\u672c\u5c42\u3002'
                  : null,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              itemCount: total,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final match = matches[index];
                return SearchResultTile(
                  index: index,
                  pageNumber: match.pageNumber,
                  selected: currentIndex == index,
                  onTap: () => onGoToSearchMatch(index),
                );
              },
            ),
    );
  }
}

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    required this.index,
    required this.pageNumber,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int index;
  final int pageNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.accentSoft : AppColors.surface;
    final border = selected ? AppColors.accentLine : AppColors.line;
    final foreground = selected ? AppColors.accent : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? AppColors.surface : AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '\u7b2c $pageNumber \u9875',
                style: TextStyle(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: selected ? AppColors.accent : AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class NotesPanel extends StatelessWidget {
  const NotesPanel({
    required this.notes,
    required this.highlights,
    required this.selectedNoteId,
    required this.onGoToNote,
    required this.onEditNote,
    required this.onUpdateNoteText,
    required this.onGoToNextNote,
    required this.onGoToPreviousNote,
    required this.onDeleteNote,
    required this.onAddNote,
    required this.shortcutBindings,
    this.onCollapse,
    super.key,
  });

  final List<PageNote> notes;
  final List<TextHighlight> highlights;
  final String? selectedNoteId;
  final ValueChanged<PageNote> onGoToNote;
  final ValueChanged<PageNote> onEditNote;
  final void Function(PageNote note, String text) onUpdateNoteText;
  final VoidCallback onGoToNextNote;
  final VoidCallback onGoToPreviousNote;
  final ValueChanged<PageNote> onDeleteNote;
  final VoidCallback onAddNote;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;
  final VoidCallback? onCollapse;

  ReaderShortcutBinding? _shortcut(ReaderShortcutAction action) {
    return shortcutBindings[action] ?? kDefaultShortcutBindings[action];
  }

  @override
  Widget build(BuildContext context) {
    final highlightsById = {
      for (final highlight in highlights) highlight.id: highlight,
    };
    return PanelScaffold(
      key: const ValueKey('notes'),
      title: '\u7b14\u8bb0',
      subtitle: '${notes.length} \u6761\u672c\u5730\u9875\u9762\u7b14\u8bb0',
      onCollapse: onCollapse,
      trailing: ShortcutTooltip(
        label: '\u65b0\u5efa\u7b14\u8bb0',
        shortcut: _shortcut(ReaderShortcutAction.addNote),
        child: IconButton.filledTonal(
          onPressed: onAddNote,
          icon: Icon(Icons.add_comment_outlined),
        ),
      ),
      child: notes.isEmpty
          ? const EmptyPanelMessage(
              icon: Icons.sticky_note_2_outlined,
              title: '\u8fd8\u6ca1\u6709\u7b14\u8bb0',
              body:
                  '\u70b9\u51fb\u5de6\u4fa7\u680f\u7684\u65b0\u5efa\u4fbf\u7b7e\uff0c\u4e3a\u5f53\u524d\u9875\u6dfb\u52a0\u672c\u5730\u6279\u6ce8\u3002',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = notes[index];
                return NoteTile(
                  note: note,
                  highlight: note.highlightId == null
                      ? null
                      : highlightsById[note.highlightId],
                  selected: selectedNoteId == note.id,
                  onTap: () => onGoToNote(note),
                  onSecondaryTap: () => onEditNote(note),
                  onUpdateText: (text) => onUpdateNoteText(note, text),
                  onGoToNextNote: onGoToNextNote,
                  onGoToPreviousNote: onGoToPreviousNote,
                  onDelete: () => onDeleteNote(note),
                );
              },
            ),
    );
  }
}

class NoteTile extends StatefulWidget {
  const NoteTile({
    required this.note,
    required this.highlight,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onUpdateText,
    required this.onGoToNextNote,
    required this.onGoToPreviousNote,
    required this.onDelete,
    super.key,
  });

  final PageNote note;
  final TextHighlight? highlight;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final ValueChanged<String> onUpdateText;
  final VoidCallback onGoToNextNote;
  final VoidCallback onGoToPreviousNote;
  final VoidCallback onDelete;

  @override
  State<NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<NoteTile> {
  late final TextEditingController _controller;
  late final FocusNode _editorFocusNode;
  late final FocusNode _tileFocusNode;
  bool _editingInline = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note.text.trim());
    _editorFocusNode = FocusNode();
    _editorFocusNode.addListener(_handleEditorFocusChange);
    _tileFocusNode = FocusNode();
    _syncTileFocus();
  }

  @override
  void didUpdateWidget(covariant NoteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.note.text.trim();
    if (oldWidget.note.id != widget.note.id || _controller.text != nextText) {
      _controller.text = nextText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    if (!widget.selected || nextText.isNotEmpty) {
      _editingInline = false;
    }
    if (oldWidget.selected != widget.selected) {
      _syncTileFocus();
    }
  }

  @override
  void dispose() {
    _editorFocusNode.removeListener(_handleEditorFocusChange);
    _controller.dispose();
    _editorFocusNode.dispose();
    _tileFocusNode.dispose();
    super.dispose();
  }

  void _syncTileFocus() {
    if (!widget.selected || _editingInline) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.selected && !_editingInline) {
        _tileFocusNode.requestFocus();
      }
    });
  }

  void _handleEditorFocusChange() {
    if (!_editorFocusNode.hasFocus && _editingInline) {
      _commitText();
    }
  }

  void _startInlineEdit() {
    widget.onTap();
    setState(() => _editingInline = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingInline) {
        _editorFocusNode.requestFocus();
      }
    });
  }

  void _commitText() {
    final nextText = _controller.text.trim();
    if (nextText != widget.note.text.trim()) {
      widget.onUpdateText(nextText);
    }
    if (mounted) {
      setState(() => _editingInline = false);
    }
    _tileFocusNode.requestFocus();
  }

  void _insertNewline() {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, '\n');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final comment = note.text.trim();
    final sourceText = widget.highlight?.text.trim();
    final selected = widget.selected;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): _NextNoteIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _PreviousNoteIntent(),
      },
      child: Actions(
        actions: {
          _NextNoteIntent: CallbackAction<_NextNoteIntent>(
            onInvoke: (_) {
              widget.onGoToNextNote();
              return null;
            },
          ),
          _PreviousNoteIntent: CallbackAction<_PreviousNoteIntent>(
            onInvoke: (_) {
              widget.onGoToPreviousNote();
              return null;
            },
          ),
        },
        child: InkWell(
          focusNode: _tileFocusNode,
          onTap: widget.onTap,
          onSecondaryTap: widget.onSecondaryTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentSoft : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.accentLine : AppColors.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _NoteColorGlyph(color: Color(note.colorValue)),
                    const SizedBox(width: 8),
                    Text(
                      '\u7b2c ${note.page} \u9875',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '\u5220\u9664\u7b14\u8bb0',
                      onPressed: widget.onDelete,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 17,
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (sourceText != null && sourceText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Color(note.colorValue).withValues(alpha: 0.92),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        sourceText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.subtle,
                          fontSize: 13,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ),
                ],
                if (comment.isNotEmpty || selected) ...[
                  const SizedBox(height: 8),
                  if (comment.isEmpty)
                    if (_editingInline)
                      _InlineNoteEditor(
                        controller: _controller,
                        focusNode: _editorFocusNode,
                        onCommit: _commitText,
                        onInsertNewline: _insertNewline,
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _startInlineEdit,
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: AppColors.accent,
                            side: BorderSide(color: AppColors.accentLine),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('添加评论'),
                        ),
                      )
                  else
                    Text(
                      comment,
                      maxLines: selected ? null : 2,
                      overflow: selected
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.ink, height: 1.35),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextNoteIntent extends Intent {
  const _NextNoteIntent();
}

class _PreviousNoteIntent extends Intent {
  const _PreviousNoteIntent();
}

class _InlineNoteCommitIntent extends Intent {
  const _InlineNoteCommitIntent();
}

class _InlineNoteNewlineIntent extends Intent {
  const _InlineNoteNewlineIntent();
}

class _InlineNoteEditor extends StatelessWidget {
  const _InlineNoteEditor({
    required this.controller,
    required this.focusNode,
    required this.onCommit,
    required this.onInsertNewline,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCommit;
  final VoidCallback onInsertNewline;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): _InlineNoteCommitIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _InlineNoteNewlineIntent(),
        SingleActivator(LogicalKeyboardKey.enter, shift: true):
            _InlineNoteNewlineIntent(),
      },
      child: Actions(
        actions: {
          _InlineNoteCommitIntent: CallbackAction<_InlineNoteCommitIntent>(
            onInvoke: (_) {
              onCommit();
              return null;
            },
          ),
          _InlineNoteNewlineIntent: CallbackAction<_InlineNoteNewlineIntent>(
            onInvoke: (_) {
              onInsertNewline();
              return null;
            },
          ),
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 1,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.done,
          onTapOutside: (_) => onCommit(),
          style: TextStyle(color: AppColors.ink, height: 1.35),
          decoration: InputDecoration(
            isDense: true,
            hintText: '添加评论',
            hintStyle: TextStyle(color: AppColors.accent, height: 1.35),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.accentLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.accentLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.accent, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteColorGlyph extends StatelessWidget {
  const _NoteColorGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(20),
      painter: _NoteColorGlyphPainter(color),
    );
  }
}

class _NoteColorGlyphPainter extends CustomPainter {
  const _NoteColorGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final borderColor = AppColors.noteGlyphStroke.withValues(alpha: 0.62);
    final fill = Paint()
      ..color = color.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, size.shortestSide * 0.06)
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.butt;
    final fold = Paint()
      ..color = Color.lerp(
        color,
        AppColors.noteFoldSurface,
        0.58,
      )!.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final foldX = w * 0.5;
    final foldY = h * 0.5;
    final inset = border.strokeWidth * 0.5;
    final page = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(foldX, h)
      ..lineTo(0, foldY)
      ..close();
    final foldPath = Path()
      ..moveTo(0, foldY)
      ..lineTo(foldX, h)
      ..lineTo(foldX, foldY)
      ..close();
    final crease = Path()
      ..moveTo(inset, foldY)
      ..lineTo(foldX, foldY)
      ..lineTo(foldX, h - inset);

    canvas.drawPath(page, fill);
    canvas.drawPath(foldPath, fold);
    canvas.drawPath(page, border);
    canvas.drawPath(crease, border);
  }

  @override
  bool shouldRepaint(covariant _NoteColorGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class PanelScaffold extends StatelessWidget {
  const PanelScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.onCollapse,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 22, 14, subtitle == null ? 18 : 12),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.subtle,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.line),
        Expanded(child: child),
      ],
    );
  }
}

class PanelSectionTitle extends StatelessWidget {
  const PanelSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.subtle,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class EmptyPanelMessage extends StatelessWidget {
  const EmptyPanelMessage({
    required this.icon,
    required this.title,
    this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.subtle),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            if (body != null && body!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subtle,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RecentTile extends StatelessWidget {
  const RecentTile({
    required this.selected,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onPdfContextMenu,
    required this.onPdf2zhAction,
    required this.onClearRecent,
    required this.onContextMenuStart,
    super.key,
  });

  final bool selected;
  final RecentDocument item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;
  final void Function(PdfSource source, Pdf2zhAction action) onPdf2zhAction;
  final VoidCallback onClearRecent;
  final ValueChanged<Offset> onContextMenuStart;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.accentSoft : AppColors.surface;
    final border = selected ? AppColors.accent : AppColors.line;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kSecondaryMouseButton) != 0) {
            onContextMenuStart(event.position);
          }
        },
        child: InkWell(
          onTap: onTap,
          onSecondaryTapDown: (details) async {
            onContextMenuStart(details.globalPosition);
            final action = await showThemedContextMenu<_RecentFileAction>(
              context: context,
              position: details.globalPosition,
              minWidth: 128,
              items: [
                for (final pdfAction in Pdf2zhAction.values)
                  themedContextMenuItem(
                    value: _RecentFileAction.pdf2zh(pdfAction),
                    label: pdfAction.label,
                  ),
                themedContextMenuDivider(),
                themedContextMenuItem(
                  value: _RecentFileAction.delete,
                  label: '\u5220\u9664\u8bb0\u5f55',
                ),
                themedContextMenuItem(
                  value: _RecentFileAction.clearAll,
                  label: '\u6e05\u7a7a\u5168\u90e8',
                  danger: true,
                ),
              ],
            );
            if (!context.mounted) {
              return;
            }
            switch (action) {
              case _RecentPdf2zhFileAction(:final pdf2zhAction):
                onPdf2zhAction(
                  PdfSource(name: item.name, path: item.path, size: item.size),
                  pdf2zhAction,
                );
                break;
              case _RecentDeleteFileAction():
                onDelete();
                break;
              case _RecentClearAllFileAction():
                if (await _confirmClearRecent(context)) {
                  onClearRecent();
                }
                break;
              case null:
                break;
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: selected ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.subtle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

sealed class _RecentFileAction {
  const _RecentFileAction();

  const factory _RecentFileAction.pdf2zh(Pdf2zhAction action) =
      _RecentPdf2zhFileAction;

  static const delete = _RecentDeleteFileAction();
  static const clearAll = _RecentClearAllFileAction();
}

class _RecentPdf2zhFileAction extends _RecentFileAction {
  const _RecentPdf2zhFileAction(this.pdf2zhAction);

  final Pdf2zhAction pdf2zhAction;
}

class _RecentDeleteFileAction extends _RecentFileAction {
  const _RecentDeleteFileAction();
}

class _RecentClearAllFileAction extends _RecentFileAction {
  const _RecentClearAllFileAction();
}
