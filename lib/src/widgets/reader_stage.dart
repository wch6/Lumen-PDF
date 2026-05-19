import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reader_models.dart';
import '../pdf/pdf_viewer_behaviors.dart';
import '../theme/app_colors.dart';

const int _progressivePreviewThresholdBytes = 4 * 1024 * 1024;
const int _heavyScanPreviewThresholdBytes = 64 * 1024 * 1024;

class ReaderStage extends StatefulWidget {
  const ReaderStage({
    required this.source,
    required this.status,
    required this.nightMode,
    required this.settings,
    required this.controller,
    required this.textSearcher,
    required this.notes,
    required this.highlights,
    required this.onOpen,
    required this.onAddHighlight,
    required this.onViewerReady,
    required this.onPageChanged,
    required this.passwordProvider,
    super.key,
  });

  final PdfSource? source;
  final String? status;
  final bool nightMode;
  final ReaderSettings settings;
  final PdfViewerController controller;
  final PdfTextSearcher? textSearcher;
  final List<PageNote> notes;
  final List<TextHighlight> highlights;
  final VoidCallback onOpen;
  final ValueChanged<List<PdfPageTextRange>> onAddHighlight;
  final void Function(PdfDocument document, PdfViewerController controller)
  onViewerReady;
  final ValueChanged<int?> onPageChanged;
  final Future<String?> Function() passwordProvider;

  @override
  State<ReaderStage> createState() => _ReaderStageState();
}

class _ReaderStageState extends State<ReaderStage> {
  bool _showScrollThumb = false;
  bool _viewportMoving = false;
  Timer? _viewportIdleTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onViewportChanged);
  }

  @override
  void didUpdateWidget(covariant ReaderStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onViewportChanged);
      widget.controller.addListener(_onViewportChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onViewportChanged);
    _viewportIdleTimer?.cancel();
    super.dispose();
  }

  void _onViewportChanged() {
    if (!mounted || !widget.controller.isReady) {
      return;
    }
    if (!_viewportMoving) {
      setState(() => _viewportMoving = true);
    }
    _viewportIdleTimer?.cancel();
    _viewportIdleTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted && _viewportMoving) {
        setState(() => _viewportMoving = false);
      }
    });
  }

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
                      nightMode: widget.nightMode,
                      settings: widget.settings,
                      viewportMoving: _viewportMoving,
                      onAddHighlight: widget.onAddHighlight,
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
    required this.nightMode,
    required this.settings,
    required this.viewportMoving,
    required this.onAddHighlight,
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
  final bool nightMode;
  final ReaderSettings settings;
  final bool viewportMoving;
  final ValueChanged<List<PdfPageTextRange>> onAddHighlight;
  final void Function(PdfDocument document, PdfViewerController controller)
  onViewerReady;
  final ValueChanged<int?> onPageChanged;
  final Future<String?> Function() passwordProvider;

  @override
  Widget build(BuildContext context) {
    final useLowResolutionPreview = _shouldUseLowResolutionPreview();
    final effectiveResolution = settings.effectiveResolutionFor(
      MediaQuery.devicePixelRatioOf(context),
    );
    final params = PdfViewerParams(
      backgroundColor: AppColors.pageSeparator,
      margin: 0,
      layoutPages: continuousPageLayout,
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
        pageImageCachingDelay: useLowResolutionPreview
            ? Duration(milliseconds: viewportMoving ? 8 : 0)
            : Duration.zero,
        partialImageLoadingDelay: Duration(
          milliseconds: viewportMoving ? 36 : 0,
        ),
      ),
      maxImageBytesCachedOnMemory: _imageCacheBytes(useLowResolutionPreview),
      horizontalCacheExtent: _horizontalCacheExtent,
      verticalCacheExtent: _verticalCacheExtent,
      textSelectionParams: const PdfTextSelectionParams(enabled: true),
      buildContextMenu: _buildContextMenu,
      linkHandlerParams: PdfLinkHandlerParams(
        onLinkTap: _handleLinkTap,
        customPainter: _paintNoLinkHighlights,
        enableAutoLinkDetection: true,
      ),
      pagePaintCallbacks: [
        _paintHighlights,
        if (textSearcher != null) textSearcher!.pageTextMatchPaintCallback,
      ],
      pageOverlaysBuilder: (context, pageRect, page) {
        final pageNotes = notes
            .where((note) => note.page == page.pageNumber)
            .toList();
        return [
          for (var i = 0; i < pageNotes.length && i < 4; i++)
            Positioned(
              left: pageRect.right - 48,
              top: pageRect.top + 22 + i * 32,
              child: Tooltip(
                message: pageNotes[i].text,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.note,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFFE9D689)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1C242121),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 17,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
        ];
      },
    );

    final viewer = source.path != null
        ? PdfViewer.file(
            source.path!,
            key: ValueKey(source.id),
            controller: controller,
            params: params,
            passwordProvider: passwordProvider,
          )
        : PdfViewer.data(
            source.bytes!,
            key: ValueKey(source.id),
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
    return math.max(effectiveResolution / 72.0, 240 / 72.0);
  }

  double get _onePassRenderingSizeThreshold {
    return (3600 + _normalizedSensitivity * 160).clamp(3760.0, 4400.0);
  }

  int _imageCacheBytes(bool lowResolutionPreview) {
    final megabytes =
        384 + _normalizedSensitivity * 96 + (lowResolutionPreview ? 128 : 0);
    return megabytes.round() * 1024 * 1024;
  }

  double get _horizontalCacheExtent {
    final sensitivity = _normalizedSensitivity;
    if (viewportMoving) {
      return 0.18 + sensitivity * 0.04;
    }
    return 0.48 + sensitivity * 0.1;
  }

  double get _verticalCacheExtent {
    final sensitivity = _normalizedSensitivity;
    if (viewportMoving) {
      return 1.35 + (sensitivity - 1.0) * 0.22;
    }
    return 4.8 + (sensitivity - 1.0) * 1.05;
  }

  void _applyDocumentPan(Offset delta, {bool trackpad = false}) {
    if (delta == Offset.zero) {
      return;
    }
    final sensitivity = trackpad
        ? 0.74 + _normalizedSensitivity * 0.09
        : _wheelScrollAmount;
    final next = controller.value.clone()
      ..translateByDouble(delta.dx * sensitivity, delta.dy * sensitivity, 0, 1);
    controller.value = controller.makeMatrixInSafeRange(next, forceClamp: true);
  }

  double _getPageRenderingScale(
    BuildContext context,
    PdfPage page,
    PdfViewerController controller,
    double estimatedScale,
  ) {
    final size = source.size ?? 0;
    final configuredScale =
        settings.effectiveResolutionFor(
          MediaQuery.devicePixelRatioOf(context),
        ) /
        72.0;
    final previewCap = size >= _heavyScanPreviewThresholdBytes
        ? (viewportMoving ? 1.75 : 2.05)
        : size >= _progressivePreviewThresholdBytes
        ? (viewportMoving ? 2.35 : configuredScale)
        : viewportMoving
        ? 2.45
        : configuredScale;
    final longestSide = math.max(page.width, page.height);
    final maxPixels = size >= _heavyScanPreviewThresholdBytes
        ? 3400.0
        : viewportMoving
        ? 3800.0
        : 4096.0;
    final maxSafeScale = math.max(1.0, math.min(4.0, maxPixels / longestSide));
    return math.min(
      estimatedScale,
      math.min(configuredScale, math.min(previewCap, maxSafeScale)),
    );
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
      if (delegate.isCopyAllowed)
        _ReaderContextMenuButton(
          icon: Icons.copy_rounded,
          label: '复制',
          onPressed: () {
            unawaited(delegate.copyTextSelection());
            params.dismissContextMenu();
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
    ];

    return Material(
      color: AppColors.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
        canvas.drawRect(_highlightBandRect(localRect), paint);
      }
    }
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
              (rect) => rect.toPdfRect().toRectInDocument(
                page: page,
                pageRect: pageRect,
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
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
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
