import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reader_models.dart';
import '../pdf/pdf_viewer_behaviors.dart';
import '../theme/app_colors.dart';

const int _progressivePreviewThresholdBytes = 12 * 1024 * 1024;
const int _heavyScanPreviewThresholdBytes = 64 * 1024 * 1024;
const int _bytesPerMegabyte = 1024 * 1024;
const double _noteSelectionStrokeWidth = 1.12;
const double _highlightSelectionOutlineInset = 4.0;
const double _markerSelectionOutlineInset = 3.0;

class ReaderStage extends StatefulWidget {
  const ReaderStage({
    required this.source,
    required this.status,
    required this.nightMode,
    required this.settings,
    required this.systemResolution,
    required this.controller,
    required this.textSearcher,
    required this.notes,
    required this.highlights,
    required this.selectedNoteId,
    required this.onOpen,
    required this.onAddHighlight,
    required this.onEditNote,
    required this.onSelectNote,
    required this.onClearNoteSelection,
    required this.onMoveNote,
    required this.onEditHighlightNote,
    required this.onTranslateSelection,
    required this.onViewerReady,
    required this.onPageChanged,
    required this.passwordProvider,
    super.key,
  });

  final PdfSource? source;
  final String? status;
  final bool nightMode;
  final ReaderSettings settings;
  final int systemResolution;
  final PdfViewerController controller;
  final PdfTextSearcher? textSearcher;
  final List<PageNote> notes;
  final List<TextHighlight> highlights;
  final String? selectedNoteId;
  final VoidCallback onOpen;
  final ValueChanged<List<PdfPageTextRange>> onAddHighlight;
  final ValueChanged<PageNote> onEditNote;
  final ValueChanged<PageNote> onSelectNote;
  final VoidCallback onClearNoteSelection;
  final void Function(PageNote note, Offset? pdfPosition, bool commit)
  onMoveNote;
  final void Function(TextHighlight highlight, Offset? anchor)
  onEditHighlightNote;
  final ValueChanged<String> onTranslateSelection;
  final void Function(PdfDocument document, PdfViewerController controller)
  onViewerReady;
  final ValueChanged<int?> onPageChanged;
  final Future<String?> Function() passwordProvider;

  @override
  State<ReaderStage> createState() => _ReaderStageState();
}

class _ReaderStageState extends State<ReaderStage> {
  bool _showScrollThumb = false;

  @override
  Widget build(BuildContext context) {
    final docSource = widget.source;
    return MouseRegion(
      onEnter: (_) => setState(() => _showScrollThumb = true),
      onExit: (_) => setState(() => _showScrollThumb = false),
      child: Container(
        color: widget.nightMode ? AppColors.nightCanvas : AppColors.canvas,
        child: docSource == null
            ? EmptyStage(onOpen: widget.onOpen)
            : Stack(
                children: [
                  Positioned.fill(
                    child: PdfViewerView(
                      source: docSource,
                      controller: widget.controller,
                      textSearcher: widget.textSearcher,
                      notes: widget.notes,
                      highlights: widget.highlights,
                      selectedNoteId: widget.selectedNoteId,
                      nightMode: widget.nightMode,
                      settings: widget.settings,
                      systemResolution: widget.systemResolution,
                      onAddHighlight: widget.onAddHighlight,
                      onEditNote: widget.onEditNote,
                      onSelectNote: widget.onSelectNote,
                      onClearNoteSelection: widget.onClearNoteSelection,
                      onMoveNote: widget.onMoveNote,
                      onEditHighlightNote: widget.onEditHighlightNote,
                      onTranslateSelection: widget.onTranslateSelection,
                      onViewerReady: widget.onViewerReady,
                      onPageChanged: widget.onPageChanged,
                      passwordProvider: widget.passwordProvider,
                    ),
                  ),
                  if (_showScrollThumb)
                    Positioned.fill(
                      child: StageScrollThumb(
                        controller: widget.controller,
                        nightMode: widget.nightMode,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class PdfViewerView extends StatelessWidget {
  const PdfViewerView({
    required this.source,
    required this.controller,
    required this.textSearcher,
    required this.notes,
    required this.highlights,
    required this.selectedNoteId,
    required this.nightMode,
    required this.settings,
    required this.systemResolution,
    required this.onAddHighlight,
    required this.onEditNote,
    required this.onSelectNote,
    required this.onClearNoteSelection,
    required this.onMoveNote,
    required this.onEditHighlightNote,
    required this.onTranslateSelection,
    required this.onViewerReady,
    required this.onPageChanged,
    required this.passwordProvider,
    super.key,
  });

  final PdfSource source;
  final PdfViewerController controller;
  final PdfTextSearcher? textSearcher;
  final List<PageNote> notes;
  final List<TextHighlight> highlights;
  final String? selectedNoteId;
  final bool nightMode;
  final ReaderSettings settings;
  final int systemResolution;
  final ValueChanged<List<PdfPageTextRange>> onAddHighlight;
  final ValueChanged<PageNote> onEditNote;
  final ValueChanged<PageNote> onSelectNote;
  final VoidCallback onClearNoteSelection;
  final void Function(PageNote note, Offset? pdfPosition, bool commit)
  onMoveNote;
  final void Function(TextHighlight highlight, Offset? anchor)
  onEditHighlightNote;
  final ValueChanged<String> onTranslateSelection;
  final void Function(PdfDocument document, PdfViewerController controller)
  onViewerReady;
  final ValueChanged<int?> onPageChanged;
  final Future<String?> Function() passwordProvider;

  @override
  Widget build(BuildContext context) {
    final useLowResolutionPreview = _shouldUseLowResolutionPreview();
    final effectiveResolution = settings.effectiveResolutionForSystemResolution(
      systemResolution,
    );
    final params = PdfViewerParams(
      backgroundColor: AppColors.pageSeparator,
      matchTextColor: AppColors.highlight,
      activeMatchTextColor: AppColors.accent.withValues(alpha: 0.44),
      margin: 0,
      layoutPages: continuousPageLayout,
      limitRenderingCache: false,
      pageDropShadow: const BoxShadow(color: Colors.transparent),
      sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
        minScale: 0.25,
        maxScale: 6,
        useAlternativeFitScaleAsMinScale: false,
        onePassRenderingScaleThreshold: _onePassRenderingScaleThreshold(
          effectiveResolution,
        ),
        calculateInitialZoom: (document, controller, fitZoom, coverZoom) {
          return coverZoom;
        },
      ),
      onViewerReady: onViewerReady,
      onPageChanged: onPageChanged,
      panEnabled: false,
      enableKeyboardNavigation: false,
      scrollByMouseWheel: _wheelScrollAmount,
      scrollHorizontallyByMouseWheel: false,
      scaleByPointerScale: _pointerScaleSensitivity,
      getPageRenderingScale: _getPageRenderingScale,
      interactionDelegateProvider: VelocityScrollInteractionDelegateProvider(
        panFriction: 16,
        zoomFriction: 16,
        velocityScale: 1160 - _normalizedSensitivity * 135,
        maxVelocityMultiplier: 2.1 + _normalizedSensitivity * 0.72,
      ),
      onePassRenderingSizeThreshold: _onePassRenderingSizeThreshold,
      behaviorControlParams: PdfViewerBehaviorControlParams(
        trailingPageLoadingDelay: Duration.zero,
        enableLowResolutionPagePreview: useLowResolutionPreview,
        pageImageCachingDelay: Duration.zero,
        partialImageLoadingDelay: Duration.zero,
      ),
      maxImageBytesCachedOnMemory: _imageCacheBytes(useLowResolutionPreview),
      horizontalCacheExtent: _horizontalCacheExtent,
      verticalCacheExtent: _verticalCacheExtent,
      textSelectionParams: const PdfTextSelectionParams(
        enabled: true,
        showContextMenuAutomatically: false,
      ),
      buildContextMenu: _buildContextMenu,
      onGeneralTap: _handleGeneralTap,
      onViewSizeChanged: _handleViewSizeChanged,
      linkHandlerParams: PdfLinkHandlerParams(
        onLinkTap: _handleLinkTap,
        customPainter: _paintNoLinkHighlights,
        enableAutoLinkDetection: true,
      ),
      pagePaintCallbacks: [
        _paintHighlights,
        _paintSelectedNoteOutline,
        if (textSearcher != null) textSearcher!.pageTextMatchPaintCallback,
      ],
      pageOverlaysBuilder: (context, pageRect, page) {
        final pageNotes =
            notes.where((note) => note.page == page.pageNumber).toList()
              ..sort(PageNote.compareByPosition);
        final pageHighlights = highlights.where(
          (highlight) => highlight.page == page.pageNumber,
        );
        final pageHighlightsById = {
          for (final highlight in pageHighlights) highlight.id: highlight,
        };
        final noteHighlightIds = {
          for (final note in pageNotes)
            if (note.highlightId != null) note.highlightId!,
        };
        final notesByHighlightId = {
          for (final note in pageNotes)
            if (note.highlightId != null) note.highlightId!: note,
        };
        return [
          for (final highlight in pageHighlights)
            for (final rect in _mergeHighlightRects(
              highlight.rects,
              page,
              pageRect,
            ))
              Positioned.fromRect(
                rect: _highlightBandRect(rect),
                child: PdfOverlayInteractionRegion(
                  onTap: noteHighlightIds.contains(highlight.id)
                      ? (details) {
                          final note = notesByHighlightId[highlight.id];
                          if (note != null) {
                            onSelectNote(note);
                          }
                          return true;
                        }
                      : null,
                  onSecondaryTap: (details) {
                    onEditHighlightNote(highlight, details.globalPosition);
                    return true;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
          for (final note in pageNotes)
            if (note.highlightId == null || note.text.trim().isNotEmpty)
              _PdfNoteMarker(
                key: ValueKey('note-marker-${note.id}'),
                note: note,
                highlight: note.highlightId == null
                    ? null
                    : pageHighlightsById[note.highlightId],
                page: page,
                pageRect: pageRect,
                selected: selectedNoteId == note.id,
                onEdit: onEditNote,
                onSelect: onSelectNote,
                onMove: onMoveNote,
                onPointerSignal: _handleOverlayPointerSignal,
              ),
        ];
      },
    );

    final viewer = source.path != null
        ? PdfViewer.file(
            source.path!,
            key: ValueKey('pdf-${source.id}-$effectiveResolution'),
            controller: controller,
            params: params,
            passwordProvider: passwordProvider,
          )
        : PdfViewer.data(
            source.bytes!,
            key: ValueKey('pdf-${source.id}-$effectiveResolution'),
            sourceName: source.name,
            controller: controller,
            params: params,
            passwordProvider: passwordProvider,
          );

    return Listener(
      onPointerPanZoomUpdate: (event) {
        if (event.kind == PointerDeviceKind.trackpad && controller.isReady) {
          _applyDocumentPan(event.panDelta, trackpad: true);
        }
      },
      child: viewer,
    );
  }

  void _handleOverlayPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !controller.isReady) {
      return;
    }

    if (HardwareKeyboard.instance.isControlPressed) {
      final localPosition = controller.globalToLocal(event.position);
      if (localPosition == null) {
        return;
      }
      final zoomFactor = -(event.scrollDelta.dx + event.scrollDelta.dy) / 120.0;
      final rawScaleFactor = math.pow(1.2, zoomFactor).toDouble();
      final scaleFactor =
          (rawScaleFactor - 1.0) * _pointerScaleSensitivity + 1.0;
      unawaited(
        controller.zoomOnLocalPosition(
          localPosition: localPosition,
          newZoom: (controller.currentZoom * scaleFactor).clamp(
            controller.minScale,
            controller.maxScale,
          ),
          duration: Duration.zero,
        ),
      );
      return;
    }

    var rawDx = -event.scrollDelta.dx;
    var rawDy = -event.scrollDelta.dy;
    if (HardwareKeyboard.instance.isShiftPressed && rawDy != 0 && rawDx == 0) {
      rawDx = rawDy;
      rawDy = 0;
    }

    _translateDocument(Offset(rawDx, rawDy) * _wheelScrollAmount);
  }

  bool _handleGeneralTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (selectedNoteId != null) {
      onClearNoteSelection();
    }
    if (details.type != PdfViewerGeneralTapType.doubleTap ||
        details.tapOn != PdfViewerPart.nonSelectedText) {
      return false;
    }

    unawaited(
      _selectWordAtDocumentPosition(controller, details.documentPosition),
    );
    return true;
  }

  Future<void> _selectWordAtDocumentPosition(
    PdfViewerController controller,
    Offset documentPosition,
  ) async {
    final delegate = controller.textSelectionDelegate;
    await delegate.selectWord(documentPosition);

    final selection = await _wordSelectionAt(controller, documentPosition);
    if (selection != null) {
      await delegate.setTextSelectionPointRange(selection.range);
      onTranslateSelection(selection.text);
    }
  }

  Future<({PdfTextSelectionRange range, String text})?> _wordSelectionAt(
    PdfViewerController controller,
    Offset documentPosition,
  ) async {
    if (!controller.isReady) {
      return null;
    }

    final document = controller.document;
    final layout = controller.layout;
    for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex++) {
      final pageRect = layout.pageLayouts[pageIndex];
      if (!pageRect.contains(documentPosition)) {
        continue;
      }

      final page = document.pages[pageIndex];
      final pageText = await page.loadStructuredText();
      if (pageText.fullText.isEmpty || pageText.charRects.isEmpty) {
        return null;
      }

      final pagePoint = documentPosition
          .translate(-pageRect.left, -pageRect.top)
          .toPdfPoint(page: page, scaledPageSize: pageRect.size);
      final charIndex = _nearestWordCharIndex(pageText, pagePoint);
      if (charIndex == null) {
        return null;
      }

      final wordRange = _wordCodeUnitRange(pageText.fullText, charIndex);
      if (wordRange == null || wordRange.start >= wordRange.end) {
        return null;
      }

      return (
        range: PdfTextSelectionRange.fromPoints(
          PdfTextSelectionPoint(pageText, wordRange.start),
          PdfTextSelectionPoint(pageText, wordRange.end - 1),
        ),
        text: pageText.fullText.substring(wordRange.start, wordRange.end),
      );
    }
    return null;
  }

  int? _nearestWordCharIndex(PdfPageText pageText, PdfPoint point) {
    int? nearestIndex;
    double nearestDistance = double.infinity;
    double nearestScale = 0;
    final count = math.min(pageText.fullText.length, pageText.charRects.length);
    for (var i = 0; i < count; i++) {
      final codeUnit = pageText.fullText.codeUnitAt(i);
      if (!_isSelectableWordCodeUnit(codeUnit)) {
        continue;
      }
      final rect = pageText.charRects[i];
      final scale = math.max(rect.width, rect.height);
      if (rect.containsPoint(point, margin: scale * 0.18)) {
        return i;
      }
      final distance = rect.distanceSquaredTo(point);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
        nearestScale = scale;
      }
    }

    if (nearestIndex == null || nearestScale <= 0) {
      return null;
    }
    return nearestDistance <= nearestScale * nearestScale * 1.6
        ? nearestIndex
        : null;
  }

  ({int start, int end})? _wordCodeUnitRange(String text, int index) {
    if (index < 0 ||
        index >= text.length ||
        !_isSelectableWordCodeUnit(text.codeUnitAt(index))) {
      return null;
    }

    var start = index;
    var end = index + 1;
    while (start > 0 && _isSelectableWordCodeUnit(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length &&
        _isSelectableWordCodeUnit(text.codeUnitAt(end))) {
      end++;
    }

    while (start < end && !_isWordCoreCodeUnit(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start && !_isWordCoreCodeUnit(text.codeUnitAt(end - 1))) {
      end--;
    }
    return start < end ? (start: start, end: end) : null;
  }

  bool _isSelectableWordCodeUnit(int codeUnit) {
    return _isWordCoreCodeUnit(codeUnit) ||
        codeUnit == 0x27 ||
        codeUnit == 0x2019 ||
        codeUnit == 0x2d ||
        codeUnit == 0x2010 ||
        codeUnit == 0x2011 ||
        codeUnit == 0x2012 ||
        codeUnit == 0x2013;
  }

  bool _isWordCoreCodeUnit(int codeUnit) {
    return (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
        (codeUnit >= 0x4e00 && codeUnit <= 0x9fff);
  }

  void _handleViewSizeChanged(
    Size viewSize,
    Size? oldViewSize,
    PdfViewerController controller,
  ) {
    if (oldViewSize == null ||
        !controller.isReady ||
        (viewSize.width - oldViewSize.width).abs() < 1) {
      return;
    }

    final anchorTop = controller.visibleRect.top;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.isReady) {
        _fitWidth(anchorTop: anchorTop);
      }
    });
  }

  bool _shouldUseLowResolutionPreview() {
    return true;
  }

  double get _normalizedSensitivity {
    return settings.scrollSensitivity.clamp(1.0, 5.0);
  }

  double get _wheelScrollAmount {
    return 0.26 + _normalizedSensitivity * 0.08;
  }

  double get _pointerScaleSensitivity {
    return 0.78 + _normalizedSensitivity * 0.04;
  }

  double _onePassRenderingScaleThreshold(int effectiveResolution) {
    return math.max(effectiveResolution / 72.0, 480 / 72.0);
  }

  double get _onePassRenderingSizeThreshold {
    return (7200 + _normalizedSensitivity * 420).clamp(7620.0, 9300.0);
  }

  int _imageCacheBytes(bool lowResolutionPreview) {
    final megabytes =
        2048 +
        _normalizedSensitivity * 512 +
        (lowResolutionPreview ? 1024 : 512);
    return megabytes.round().clamp(3072, 8192) * _bytesPerMegabyte;
  }

  double get _horizontalCacheExtent {
    final sensitivity = _normalizedSensitivity;
    return (2.0 + sensitivity * 0.35).clamp(2.35, 4.0);
  }

  double get _verticalCacheExtent {
    final sensitivity = _normalizedSensitivity;
    return (24.0 + sensitivity * 4.0).clamp(28.0, 44.0);
  }

  void _applyDocumentPan(Offset delta, {bool trackpad = false}) {
    if (delta == Offset.zero) {
      return;
    }
    final sensitivity = trackpad
        ? 0.74 + _normalizedSensitivity * 0.09
        : _wheelScrollAmount;
    _translateDocument(delta * sensitivity);
  }

  void _translateDocument(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    final next = controller.value.clone()
      ..translateByDouble(delta.dx, delta.dy, 0, 1);
    controller.value = controller.makeMatrixInSafeRange(next, forceClamp: true);
  }

  void _fitWidth({double? anchorTop}) {
    final pageNumber = controller.pageNumber;
    if (!controller.isReady ||
        pageNumber == null ||
        pageNumber < 1 ||
        pageNumber > controller.layout.pageLayouts.length) {
      return;
    }
    final pageRect = controller.layout.pageLayouts[pageNumber - 1];
    final visibleTop = anchorTop ?? controller.visibleRect.top;
    final zoom = (controller.viewSize.width / pageRect.width)
        .clamp(controller.minScale, controller.maxScale)
        .toDouble();
    final centerY = visibleTop + controller.viewSize.height / (2 * zoom);
    unawaited(
      controller.goTo(
        controller.calcMatrixFor(
          Offset(pageRect.center.dx, centerY),
          zoom: zoom,
        ),
        duration: Duration.zero,
      ),
    );
  }

  double _getPageRenderingScale(
    BuildContext context,
    PdfPage page,
    PdfViewerController controller,
    double estimatedScale,
  ) {
    final size = source.size ?? 0;
    final configuredScale =
        settings.effectiveResolutionForSystemResolution(systemResolution) /
        72.0;
    final previewTarget = size >= _heavyScanPreviewThresholdBytes
        ? 3.60
        : size >= _progressivePreviewThresholdBytes
        ? 5.05
        : 5.65;
    final renderCeiling = math.max(configuredScale, previewTarget);
    final previewCap = size >= _heavyScanPreviewThresholdBytes
        ? 3.60
        : size >= _progressivePreviewThresholdBytes
        ? 5.05
        : renderCeiling;
    final longestSide = math.max(page.width, page.height);
    final maxPixels = size >= _heavyScanPreviewThresholdBytes ? 6000.0 : 7200.0;
    final maxSafeScale = math.max(1.0, math.min(6.0, maxPixels / longestSide));
    final previewScale = math.min(
      renderCeiling,
      math.min(previewCap, maxSafeScale),
    );
    final currentPageScale = _currentPageRenderingScale(context, page);
    if (!_displayedPageOverflowsViewportInBothAxes(page, controller)) {
      return math.max(previewScale, currentPageScale);
    }
    return math.min(estimatedScale, previewScale);
  }

  double _currentPageRenderingScale(BuildContext context, PdfPage page) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final pageIndex = page.pageNumber - 1;
    if (pageIndex < 0 || pageIndex >= controller.layout.pageLayouts.length) {
      return controller.currentZoom * devicePixelRatio;
    }
    final pageRect = controller.layout.pageLayouts[pageIndex];
    final layoutScale = math.max(
      page.width <= 0 ? 1.0 : pageRect.width / page.width,
      page.height <= 0 ? 1.0 : pageRect.height / page.height,
    );
    return controller.currentZoom * devicePixelRatio * layoutScale;
  }

  bool _displayedPageOverflowsViewportInBothAxes(
    PdfPage page,
    PdfViewerController controller,
  ) {
    final pageIndex = page.pageNumber - 1;
    if (pageIndex < 0 || pageIndex >= controller.layout.pageLayouts.length) {
      return false;
    }
    final pageRect = controller.layout.pageLayouts[pageIndex];
    final viewSize = controller.viewSize;
    final displayedWidth = pageRect.width * controller.currentZoom;
    final displayedHeight = pageRect.height * controller.currentZoom;
    const tolerance = 1.0;
    return displayedWidth > viewSize.width + tolerance &&
        displayedHeight > viewSize.height + tolerance;
  }

  void _handleLinkTap(PdfLink link) {
    final dest = link.dest;
    if (dest != null) {
      unawaited(controller.goToDest(dest));
      return;
    }

    final url = link.url;
    if (url == null) {
      return;
    }
    unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
  }

  Widget? _buildContextMenu(
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    final delegate = params.textSelectionDelegate;
    if (!params.isTextSelectionEnabled || !delegate.hasSelectedText) {
      return null;
    }

    final buttons = <Widget>[
      _ReaderContextMenuButton(
        icon: Icons.translate_rounded,
        label: '翻译',
        onPressed: () {
          unawaited(() async {
            final ranges = await delegate.getSelectedTextRanges();
            final text = ranges.map((range) => range.text.trim()).join('\n');
            params.dismissContextMenu();
            onTranslateSelection(text);
          }());
        },
      ),
      _ReaderContextMenuButton(
        icon: Icons.border_color_rounded,
        label: '高亮',
        onPressed: () {
          unawaited(() async {
            final ranges = await delegate.getSelectedTextRanges();
            params.dismissContextMenu();
            await delegate.clearTextSelection();
            onAddHighlight(ranges);
          }());
        },
      ),
      if (delegate.isCopyAllowed)
        _ReaderContextMenuButton(
          icon: Icons.copy_rounded,
          label: '复制',
          onPressed: () {
            unawaited(delegate.copyTextSelection());
            params.dismissContextMenu();
          },
        ),
    ];
    return Material(
      color: AppColors.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
        ),
      ),
    );
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final pageHighlights = highlights.where(
      (highlight) => highlight.page == page.pageNumber,
    );
    for (final highlight in pageHighlights) {
      final color = Color(highlight.colorValue);
      final alpha = ((color.toARGB32() >> 24) & 0xff) / 255.0;
      final paint = Paint()
        ..color = color.withValues(alpha: math.max(alpha, 0.54))
        ..blendMode = BlendMode.multiply
        ..style = PaintingStyle.fill;
      for (final localRect in _mergeHighlightRects(
        highlight.rects,
        page,
        pageRect,
      )) {
        canvas.drawRect(
          _highlightBandRect(localRect).translate(pageRect.left, pageRect.top),
          paint,
        );
      }
    }
  }

  void _paintSelectedNoteOutline(Canvas canvas, Rect pageRect, PdfPage page) {
    final noteId = selectedNoteId;
    if (noteId == null) {
      return;
    }
    PageNote? selectedNote;
    for (final note in notes) {
      if (note.id == noteId && note.page == page.pageNumber) {
        selectedNote = note;
        break;
      }
    }
    if (selectedNote == null) {
      return;
    }

    Rect? outlineRect;
    var outlineInset = _markerSelectionOutlineInset;
    final highlightId = selectedNote.highlightId;
    if (highlightId != null) {
      outlineInset = _highlightSelectionOutlineInset;
      TextHighlight? selectedHighlight;
      for (final highlight in highlights) {
        if (highlight.id == highlightId && highlight.page == page.pageNumber) {
          selectedHighlight = highlight;
          break;
        }
      }
      if (selectedHighlight == null) {
        return;
      }
      for (final rect in _mergeHighlightRects(
        selectedHighlight.rects,
        page,
        pageRect,
      )) {
        final band = _highlightBandRect(rect);
        outlineRect = outlineRect == null
            ? band
            : outlineRect.expandToInclude(band);
      }
    } else {
      outlineRect = _standaloneNoteMarkerRect(selectedNote, page, pageRect);
    }
    if (outlineRect == null) {
      return;
    }

    final paint = Paint()
      ..color = AppColors.selection.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _noteSelectionStrokeWidth;
    _drawDashedRect(
      canvas,
      outlineRect.inflate(outlineInset).translate(pageRect.left, pageRect.top),
      paint,
    );
  }

  Rect? _standaloneNoteMarkerRect(PageNote note, PdfPage page, Rect pageRect) {
    final x = note.x;
    final y = note.y;
    if (x == null || y == null || page.width <= 0 || page.height <= 0) {
      return null;
    }
    final scale = pageRect.width / page.width;
    final size = scale * 28.0;
    final pagePoint = Offset(
      x.clamp(0.0, page.width).toDouble() / page.width * pageRect.width,
      y.clamp(0.0, page.height).toDouble() / page.height * pageRect.height,
    );
    final left = (pagePoint.dx - size * 0.78).clamp(
      0.0,
      math.max(0.0, pageRect.width - size),
    );
    final top = (pagePoint.dy - size * 0.78).clamp(
      0.0,
      math.max(0.0, pageRect.height - size),
    );
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), size, size);
  }

  Rect _highlightBandRect(Rect rect) {
    final topInset = rect.height * 0.06;
    final bottomInset = rect.height * 0.02;
    return Rect.fromLTRB(
      rect.left - 0.8,
      rect.top + topInset,
      rect.right + 0.8,
      rect.bottom - bottomInset,
    );
  }

  List<Rect> _mergeHighlightRects(
    List<HighlightRect> rects,
    PdfPage page,
    Rect pageRect,
  ) {
    final sorted =
        rects
            .map(
              (rect) => rect.toPdfRect().toRect(
                page: page,
                scaledPageSize: pageRect.size,
              ),
            )
            .where((rect) => rect.width > 0.2 && rect.height > 0.2)
            .toList()
          ..sort((a, b) {
            final vertical = a.top.compareTo(b.top);
            return vertical == 0 ? a.left.compareTo(b.left) : vertical;
          });

    final merged = <Rect>[];
    for (final rect in sorted) {
      var absorbed = false;
      for (var i = 0; i < merged.length; i++) {
        final current = merged[i];
        if (_sameTextLine(current, rect) &&
            _horizontalGap(current, rect) <=
                math.max(18, math.min(current.height, rect.height) * 2.8)) {
          merged[i] = current.expandToInclude(rect);
          absorbed = true;
          break;
        }
      }
      if (!absorbed) {
        merged.add(rect);
      }
    }

    return merged..sort((a, b) {
      final vertical = a.top.compareTo(b.top);
      return vertical == 0 ? a.left.compareTo(b.left) : vertical;
    });
  }

  bool _sameTextLine(Rect a, Rect b) {
    final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    final minHeight = math.min(a.height, b.height);
    final centerDelta = (a.center.dy - b.center.dy).abs();
    return overlap > minHeight * 0.42 || centerDelta < minHeight * 0.58;
  }

  double _horizontalGap(Rect a, Rect b) {
    if (a.right < b.left) {
      return b.left - a.right;
    }
    if (b.right < a.left) {
      return a.left - b.right;
    }
    return 0;
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    double dash = 2.4,
    double gap = 1.4,
  }) {
    void drawLine(Offset start, Offset end) {
      final vector = end - start;
      final length = vector.distance;
      if (length == 0) {
        return;
      }
      final direction = vector / length;
      var distance = 0.0;
      while (distance < length) {
        final segment = math.min(dash, length - distance);
        final a = start + direction * distance;
        final b = start + direction * (distance + segment);
        canvas.drawLine(a, b, paint);
        distance += dash + gap;
      }
    }

    drawLine(rect.topLeft, rect.topRight);
    drawLine(rect.topRight, rect.bottomRight);
    drawLine(rect.bottomRight, rect.bottomLeft);
    drawLine(rect.bottomLeft, rect.topLeft);
  }
}

void _paintNoLinkHighlights(
  Canvas canvas,
  Rect pageRect,
  PdfPage page,
  List<PdfLink> links,
) {}

class _ReaderContextMenuButton extends StatelessWidget {
  const _ReaderContextMenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
  }
}

class _PdfNoteMarker extends StatefulWidget {
  const _PdfNoteMarker({
    required this.note,
    required this.highlight,
    required this.page,
    required this.pageRect,
    required this.selected,
    required this.onEdit,
    required this.onSelect,
    required this.onMove,
    required this.onPointerSignal,
    super.key,
  });

  final PageNote note;
  final TextHighlight? highlight;
  final PdfPage page;
  final Rect pageRect;
  final bool selected;
  final ValueChanged<PageNote> onEdit;
  final ValueChanged<PageNote> onSelect;
  final void Function(PageNote note, Offset? pdfPosition, bool commit) onMove;
  final ValueChanged<PointerSignalEvent> onPointerSignal;

  @override
  State<_PdfNoteMarker> createState() => _PdfNoteMarkerState();
}

class _PdfNoteMarkerState extends State<_PdfNoteMarker> {
  Offset? _dragPoint;

  Offset get _pdfPoint {
    final page = widget.page;
    final note = widget.note;
    final highlightPoint = _highlightPoint;
    if (highlightPoint != null) {
      return highlightPoint;
    }
    final x = note.x ?? (page.width - 34).clamp(0.0, page.width);
    final y = note.y ?? 24.0.clamp(0.0, page.height);
    return Offset(x.toDouble(), y.toDouble());
  }

  Offset? get _highlightPoint {
    final rect = _firstHighlightLocalRect;
    if (rect == null) {
      return null;
    }
    return Offset(
      (rect.left / widget.pageRect.width * widget.page.width).clamp(
        0.0,
        widget.page.width,
      ),
      (rect.top / widget.pageRect.height * widget.page.height).clamp(
        0.0,
        widget.page.height,
      ),
    );
  }

  Rect? get _firstHighlightLocalRect {
    final highlight = widget.highlight;
    if (highlight == null || highlight.rects.isEmpty) {
      return null;
    }
    final rects =
        highlight.rects
            .map(
              (rect) => rect.toPdfRect().toRect(
                page: widget.page,
                scaledPageSize: widget.pageRect.size,
              ),
            )
            .where((rect) => rect.width > 0.2 && rect.height > 0.2)
            .toList()
          ..sort((a, b) {
            final top = a.top.compareTo(b.top);
            return top == 0 ? a.left.compareTo(b.left) : top;
          });
    return rects.isEmpty ? null : rects.first;
  }

  double _markerSize({required bool highlightNote}) {
    final lineHeight = _firstHighlightLocalRect?.height;
    if (highlightNote) {
      if (lineHeight == null || lineHeight <= 0) {
        return _pageScale * 13.0;
      }
      return lineHeight * 0.72;
    }
    return _pageScale * 28.0;
  }

  double get _pageScale {
    if (widget.page.width <= 0) {
      return 1.0;
    }
    return widget.pageRect.width / widget.page.width;
  }

  Offset _pagePoint(Offset pdfPoint) {
    final page = widget.page;
    final pageRect = widget.pageRect;
    final x = (pdfPoint.dx / page.width) * pageRect.width;
    final y = (pdfPoint.dy / page.height) * pageRect.height;
    return Offset(x, y);
  }

  Offset _pdfDelta(DragUpdateDetails details) {
    final page = widget.page;
    final pageRect = widget.pageRect;
    final dx = details.delta.dx / pageRect.width * page.width;
    final dy = details.delta.dy / pageRect.height * page.height;
    return Offset(dx, dy);
  }

  Offset _clampPdfPoint(Offset point) {
    final page = widget.page;
    return Offset(
      point.dx.clamp(0.0, page.width),
      point.dy.clamp(0.0, page.height),
    );
  }

  Rect _markerRectFor(Offset pdfPoint, {required bool highlightNote}) {
    final pageRect = widget.pageRect;
    final size = _markerSize(highlightNote: highlightNote);
    final pagePoint = _pagePoint(pdfPoint);
    final left =
        (highlightNote
                ? pagePoint.dx - size * 0.32
                : pagePoint.dx - size * 0.78)
            .clamp(0.0, pageRect.width - size);
    final top =
        (highlightNote
                ? pagePoint.dy - size * 0.42
                : pagePoint.dy - size * 0.78)
            .clamp(0.0, pageRect.height - size);
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), size, size);
  }

  @override
  Widget build(BuildContext context) {
    final point = _dragPoint ?? _pdfPoint;
    final highlightNote = widget.highlight != null;
    final rect = _markerRectFor(point, highlightNote: highlightNote);
    final color = Color(widget.note.colorValue).withValues(alpha: 1);
    final marker = CustomPaint(
      painter: _NoteMarkerPainter(
        color: color,
        dragging: _dragPoint != null,
        selected: false,
        borderColor: highlightNote
            ? const Color(0xFF777777).withValues(alpha: 0.72)
            : Colors.black.withValues(alpha: 0.86),
        opacity: highlightNote ? 0.52 : 0.96,
      ),
    );
    if (highlightNote) {
      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: PdfOverlayInteractionRegion(
          onTap: (_) {
            widget.onSelect(widget.note);
            return true;
          },
          onSecondaryTap: (details) {
            widget.onEdit(widget.note);
            return true;
          },
          child: marker,
        ),
      );
    }

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Tooltip(
        message: widget.note.text,
        waitDuration: const Duration(milliseconds: 350),
        child: Listener(
          onPointerSignal: widget.onPointerSignal,
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(widget.note),
              onDoubleTap: () => widget.onEdit(widget.note),
              onSecondaryTap: () => widget.onEdit(widget.note),
              onPanStart: (_) => setState(() => _dragPoint = _pdfPoint),
              onPanUpdate: (details) {
                setState(() {
                  _dragPoint = _clampPdfPoint(
                    (_dragPoint ?? _pdfPoint) + _pdfDelta(details),
                  );
                });
              },
              onPanCancel: () => setState(() => _dragPoint = null),
              onPanEnd: (_) {
                final next = _dragPoint;
                setState(() => _dragPoint = null);
                if (next != null) {
                  widget.onMove(widget.note, next, true);
                }
              },
              child: marker,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteMarkerPainter extends CustomPainter {
  const _NoteMarkerPainter({
    required this.color,
    required this.dragging,
    required this.selected,
    required this.borderColor,
    required this.opacity,
  });

  final Color color;
  final bool dragging;
  final bool selected;
  final Color borderColor;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color.withValues(alpha: dragging ? 0.9 : opacity)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.055)
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.butt;
    final fold = Paint()
      ..color = Color.lerp(
        color,
        AppColors.noteFoldSurface,
        0.58,
      )!.withValues(alpha: dragging ? 0.9 : math.min(1.0, opacity + 0.1))
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
    final outline = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(foldX, h)
      ..lineTo(0, foldY)
      ..close();
    final crease = Path()
      ..moveTo(inset, foldY)
      ..lineTo(foldX, foldY)
      ..lineTo(foldX, h - inset);
    canvas.drawPath(page, fill);
    canvas.drawPath(foldPath, fold);
    canvas.drawPath(outline, border);
    canvas.drawPath(crease, border);
  }

  @override
  bool shouldRepaint(covariant _NoteMarkerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dragging != dragging ||
        oldDelegate.selected != selected ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.opacity != opacity;
  }
}

class StageScrollThumb extends StatelessWidget {
  const StageScrollThumb({
    required this.controller,
    required this.nightMode,
    super.key,
  });

  final PdfViewerController controller;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isReady) {
            return const SizedBox.shrink();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final document = controller.documentSize;
              final visible = controller.visibleRect;
              if (document.height <= 0 ||
                  visible.height <= 0 ||
                  document.height <= visible.height) {
                return const SizedBox.shrink();
              }
              const thumbHeight = 58.0;
              const thumbWidth = 8.0;
              final trackHeight = math.max(
                0.0,
                constraints.maxHeight - thumbHeight - 12,
              );
              final progress =
                  (visible.top /
                          math.max(1.0, document.height - visible.height))
                      .clamp(0.0, 1.0);
              final top = 6 + trackHeight * progress;
              return Stack(
                children: [
                  Positioned(
                    top: top,
                    right: 6,
                    width: thumbWidth,
                    height: thumbHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: nightMode
                            ? Colors.white.withValues(alpha: 0.58)
                            : Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class EmptyStage extends StatelessWidget {
  const EmptyStage({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight > 56
            ? constraints.maxHeight - 56
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight, maxWidth: 560),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 136,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18242121),
                          blurRadius: 28,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 46,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '打开 PDF 开始阅读',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '支持本机文件、页面缩略图、大纲跳转、全文搜索、缩放和本地页面笔记。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.subtle,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Tooltip(
                    message: '打开 PDF 文件',
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: Icon(Icons.folder_open_rounded),
                      label: const Text('选择 PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StageStatus extends StatelessWidget {
  const StageStatus({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13242121),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          status,
          style: TextStyle(
            color: AppColors.subtle,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
