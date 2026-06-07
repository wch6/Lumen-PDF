import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/reader_models.dart';
import '../services/export_image_encoder.dart';
import '../services/file_saver.dart';
import '../services/reader_repository.dart';
import '../services/reader_settings_store.dart';
import '../services/translation_services.dart';
import '../theme/app_colors.dart';
import '../window/window_chrome_controller.dart';
import '../window/window_resize_edge.dart';
import '../widgets/page_export_dialog.dart';
import '../widgets/reader_panels.dart';
import '../widgets/reader_rail.dart';
import '../widgets/reader_stage.dart';
import '../widgets/reader_toolbar.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/themed_context_menu.dart';
import '../widgets/window_resize_frame.dart';
import '../widgets/window_transition_frame.dart';

class ReaderHome extends StatefulWidget {
  const ReaderHome({
    this.repositoryFuture,
    this.settingsStore = const FileReaderSettingsStore(),
    super.key,
  });

  final Future<ReaderRepository>? repositoryFuture;
  final ReaderSettingsStore settingsStore;

  @override
  State<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends State<ReaderHome> {
  final _viewerController = PdfViewerController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _jumpPageController = TextEditingController(text: '1');
  final _stageKey = GlobalKey();
  final _pdf2zhService = const Pdf2zhLocalService();
  final _selectionTranslationService = const SelectionTranslationService();
  final _selectionAudioPlayer = AudioPlayer();
  final _windowChrome = const WindowChromeController();
  late final Future<ReaderRepository> _repositoryFuture;

  PdfTextSearcher? _textSearcher;
  ReaderRepository? _repository;
  OverlayEntry? _messageEntry;
  Timer? _messageTimer;
  Timer? _positionSaveTimer;
  Timer? _windowSizeSaveTimer;
  bool? _syncedTitleBarNightMode;
  bool _pointerInsideWindow = false;
  bool _globalShortcutsSuspended = false;
  bool _noteEditorOpening = false;

  PdfSource? _source;
  PdfDocument? _document;
  List<PdfOutlineNode> _outline = const [];
  List<PageNote> _notes = const [];
  List<TextHighlight> _highlights = const [];
  List<RecentDocument> _recent = const [];
  List<SessionDocumentTab> _sessionTabs = const [];
  ReaderPosition? _pendingOpenPosition;
  String? _translationSourceText;
  SelectionTranslationResult? _translationResult;
  String? _selectedNoteId;
  int _selectedRecentIndex = 0;
  bool _searchResultsActive = false;

  PanelMode _panelMode = PanelMode.library;
  ReaderSettings _settings = const ReaderSettings();
  Color _highlightColor = AppColors.highlightPalette.first;
  int _currentPage = 1;
  bool _loadingLibrary = true;
  bool _nightMode = false;
  bool _windowMaximized = false;
  int _windowTransitionTrigger = 0;
  WindowTransitionKind _windowTransitionKind = WindowTransitionKind.resize;
  DateTime? _lastWindowTransitionAt;
  bool _compactPanelOpen = false;
  bool _openTabsMenuOpen = false;
  int _openTabsMenuTrigger = 0;
  int _closeTabsMenuTrigger = 0;
  int _highlightColorMenuTrigger = 0;
  bool _highlightColorMenuOpen = false;
  bool _panelCollapsed = false;
  bool _twoColumnThumbnails = false;
  int _thumbnailAnchorPage = 1;
  int? _systemResolution;
  List<PageViewportPreview> _viewportPreviews = const [];
  bool _viewportPreviewUpdateScheduled = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _repositoryFuture = widget.repositoryFuture ?? ReaderRepository.open();
    HardwareKeyboard.instance.addHandler(_handleWindowShortcutKeyEvent);
    _windowChrome.setMethodCallHandler(_handleWindowChromeMethod);
    _viewerController.addListener(_onViewerTransformChanged);
    unawaited(_loadSettings());
    unawaited(_loadRepository());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_syncTitleBarTheme());
        unawaited(_syncMinimumWindowSize());
        unawaited(_refreshWindowMaximized());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_refreshSystemResolution());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleWindowShortcutKeyEvent);
    _windowChrome.setMethodCallHandler(null);
    _viewerController.removeListener(_onViewerTransformChanged);
    _messageTimer?.cancel();
    _positionSaveTimer?.cancel();
    _windowSizeSaveTimer?.cancel();
    _messageEntry?.remove();
    _disposeTextSearcher();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _jumpPageController.dispose();
    _selectionAudioPlayer.dispose();
    final repository = _repository;
    if (repository == null) {
      unawaited(_repositoryFuture.then((repo) => repo.dispose()));
    } else {
      repository.dispose();
    }
    super.dispose();
  }

  void _disposeTextSearcher() {
    final textSearcher = _textSearcher;
    if (textSearcher == null) {
      return;
    }
    textSearcher.removeListener(_onSearchChanged);
    textSearcher.dispose();
    _textSearcher = null;
    _searchResultsActive = false;
  }

  PdfTextSearcher _createTextSearcher(PdfViewerController controller) {
    final textSearcher = PdfTextSearcher(controller);
    textSearcher.addListener(_onSearchChanged);
    return textSearcher;
  }

  Future<ReaderRepository> _repo() async {
    return _repository ??= await _repositoryFuture;
  }

  Future<void> _loadRepository() async {
    final repository = await _repositoryFuture;
    if (!mounted) {
      return;
    }
    _repository = repository;
    await _loadRecent();
  }

  Future<void> _loadSettings() async {
    final raw = await widget.settingsStore.read();
    if (!mounted) {
      return;
    }
    final settings = ReaderSettings.tryDecode(raw);
    setState(() {
      _settings = settings;
      _twoColumnThumbnails = settings.thumbnailTwoColumn;
      _thumbnailAnchorPage = settings.thumbnailAnchorPage;
    });
    unawaited(_restoreRememberedWindowSize(settings));
  }

  Future<void> _saveSettings() async {
    await widget.settingsStore.write(jsonEncode(_settings.toJson()));
  }

  int _fallbackSystemResolution() {
    return ReaderSettings.systemResolutionFor(
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  int _currentSystemResolution() {
    return _systemResolution ?? _fallbackSystemResolution();
  }

  int _effectiveRenderResolutionFor(ReaderSettings settings) {
    return settings.effectiveResolutionForSystemResolution(
      _currentSystemResolution(),
    );
  }

  Future<void> _loadRecent() async {
    final repository = await _repo();
    final items = await repository.loadRecent();

    if (!mounted) {
      return;
    }
    setState(() {
      _recent = items.take(8).toList();
      _selectedRecentIndex = _clampedRecentIndex(_selectedRecentIndex, _recent);
      _loadingLibrary = false;
    });
  }

  int _clampedRecentIndex(int index, List<RecentDocument> recent) {
    if (recent.isEmpty) {
      return 0;
    }
    return index.clamp(0, recent.length - 1).toInt();
  }

  Future<void> _saveNotes() async {
    final source = _source;
    if (source == null) {
      return;
    }
    await (await _repo()).saveNotes(source, _notes);
  }

  Future<void> _saveHighlights() async {
    final source = _source;
    if (source == null) {
      return;
    }
    await (await _repo()).saveHighlights(source, _highlights);
  }

  Future<void> _pickPdf() async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) {
      return;
    }

    if (file.path == null && file.bytes == null) {
      _showMessage('未能读取此文件，请选择本机或浏览器可访问的 PDF。');
      return;
    }

    final source = PdfSource(
      name: file.name,
      path: file.path,
      bytes: file.path == null ? file.bytes : null,
      size: file.size,
    );
    await _openSource(source);
  }

  Future<dynamic> _handleWindowChromeMethod(MethodCall call) async {
    switch (call.method) {
      case 'openDroppedFiles':
        final args = call.arguments;
        if (args is! List) {
          return false;
        }
        final paths = args.whereType<String>().toList(growable: false);
        await _openDroppedFiles(paths);
        return true;
      case 'windowMaximizedChanged':
        final maximized = call.arguments;
        if (maximized is! bool) {
          return false;
        }
        _setWindowMaximizedFromNative(maximized);
        return true;
      default:
        throw MissingPluginException(
          'Unknown window chrome method ${call.method}',
        );
    }
  }

  void _setWindowMaximizedFromNative(bool maximized) {
    if (!mounted || _windowMaximized == maximized) {
      return;
    }
    setState(() {
      _queueWindowTransition(WindowTransitionKind.resize);
      _windowMaximized = maximized;
    });
    if (!maximized) {
      _scheduleSaveCurrentWindowSize();
    }
  }

  Future<void> _openDroppedFiles(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    final pdfPath = paths.firstWhere(
      (path) => p.extension(path).toLowerCase() == '.pdf',
      orElse: () => '',
    );
    if (pdfPath.isEmpty) {
      _showMessage('请拖入 PDF 文件。');
      return;
    }
    await _openSource(PdfSource(name: p.basename(pdfPath), path: pdfPath));
  }

  Future<void> _openRecent(RecentDocument recent) async {
    await _openSource(
      PdfSource(name: recent.name, path: recent.path, size: recent.size),
      initialPage: recent.page,
      initialPosition: recent.position,
    );
  }

  Future<void> _openSessionTab(SessionDocumentTab tab) async {
    await _openSource(
      tab.source,
      initialPage: tab.page,
      initialPosition: tab.position,
    );
  }

  Future<void> _openSource(
    PdfSource source, {
    int initialPage = 1,
    ReaderPosition? initialPosition,
  }) async {
    setState(() => _status = '正在读取 PDF 指纹...');
    late final OpenedPdfState opened;
    try {
      opened = await (await _repo()).openSource(
        source,
        initialPage: initialPage,
        position: initialPosition,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _status = null);
        _showMessage('无法打开或识别该 PDF：$error');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final resolved = opened.source;
    final startPage = opened.page;
    final startPosition = opened.position;
    final alreadyLoaded = _isLoadedSource(resolved);
    final syncedNotes = _notesPrunedForHighlights(
      opened.notes,
      opened.highlights,
    );
    final notesNeedSync = !_noteListsEqual(opened.notes, syncedNotes);
    setState(() {
      _source = resolved;
      if (!alreadyLoaded) {
        _document = null;
        _outline = const [];
        _viewportPreviews = const [];
        _notes = syncedNotes;
        _highlights = opened.highlights;
      }
      _selectedNoteId = null;
      _pendingOpenPosition = startPosition;
      _currentPage = startPage;
      _jumpPageController.text = '$startPage';
      _status = alreadyLoaded ? '${_document!.pages.length} 页' : null;
      _panelMode = PanelMode.pages;
      _compactPanelOpen = false;
      _panelCollapsed = false;
      _recent = opened.recent;
      _selectedRecentIndex = _clampedRecentIndex(_selectedRecentIndex, _recent);
      _sessionTabs = [
        SessionDocumentTab(
          source: resolved,
          page: startPage,
          openedAt: DateTime.now(),
          position: startPosition,
        ),
        ..._sessionTabs.where((item) => item.source.id != resolved.id),
      ].take(9).toList();
    });

    _searchController.clear();
    if (alreadyLoaded) {
      _searchFocusNode.unfocus();
      _textSearcher?.resetTextSearch();
      _searchResultsActive = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_applyOpenPositionAndLayout());
        _updateViewportPreviews();
      });
    } else {
      _disposeTextSearcher();
    }
    if (notesNeedSync) {
      unawaited(_saveNotes());
    }
  }

  bool _isLoadedSource(PdfSource source) {
    final current = _source;
    if (current == null || _document == null) {
      return false;
    }
    if (current.id == source.id) {
      return true;
    }
    final currentPath = current.path;
    final nextPath = source.path;
    if (currentPath == null || nextPath == null) {
      return false;
    }
    return p.normalize(currentPath).toLowerCase() ==
        p.normalize(nextPath).toLowerCase();
  }

  Future<void> _loadOutline(PdfDocument document) async {
    try {
      final outline = await document.loadOutline();
      if (mounted && _document == document) {
        setState(() => _outline = outline);
      }
    } catch (_) {
      if (mounted && _document == document) {
        setState(() => _outline = const []);
      }
    }
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    _disposeTextSearcher();
    final textSearcher = _createTextSearcher(controller);
    setState(() {
      _document = document;
      _textSearcher = textSearcher;
      _status = '${document.pages.length} 页';
    });
    final source = _source;
    if (source != null) {
      unawaited(
        _repo().then(
          (repo) => repo.updateReadPosition(
            source,
            page: _currentPage,
            pageCount: document.pages.length,
            position: _captureReaderPosition(_currentPage),
          ),
        ),
      );
    }
    unawaited(_loadOutline(document));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateViewportPreviews();
        unawaited(_applyOpenPositionAndLayout());
      }
    });
  }

  Future<void> _applyOpenPositionAndLayout() async {
    if (!_viewerController.isReady) {
      return;
    }
    final pageCount = _document?.pages.length ?? 0;
    if (pageCount == 0) {
      return;
    }
    final targetPage = _currentPage.clamp(1, pageCount);
    final pendingRect = _pendingOpenPosition?.visibleRect;
    if (pendingRect != null) {
      _pendingOpenPosition = null;
      final zoom = (_viewerController.viewSize.width / pendingRect.width)
          .clamp(_viewerController.minScale, _viewerController.maxScale)
          .toDouble();
      await _viewerController.goToPosition(
        documentOffset: pendingRect.topLeft,
        zoom: zoom,
        duration: Duration.zero,
      );
      return;
    }
    final pendingMatrix = _pendingOpenPosition?.matrix;
    if (pendingMatrix != null && pendingMatrix.length == 16) {
      _pendingOpenPosition = null;
      await _viewerController.goTo(
        Matrix4.fromList(pendingMatrix),
        duration: Duration.zero,
      );
      return;
    }
    _pendingOpenPosition = null;
    await _viewerController.goToPage(
      pageNumber: targetPage,
      duration: Duration.zero,
    );
    if (!_settings.alwaysOpenWithDefaultLayout || !mounted) {
      return;
    }
    final matrix = switch (_settings.defaultPageLayout) {
      DefaultPageLayout.fitWidth => _viewerController.calcMatrixFitWidthForPage(
        pageNumber: targetPage,
      ),
      DefaultPageLayout.fitPage => _viewerController.calcMatrixForFit(
        pageNumber: targetPage,
      ),
    };
    await _viewerController.goTo(matrix, duration: Duration.zero);
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber == _currentPage) {
      return;
    }
    final source = _source;
    final position = _captureReaderPosition(pageNumber);
    setState(() {
      _currentPage = pageNumber;
      _jumpPageController.text = '$pageNumber';
      _applyLocalReadPosition(pageNumber, position);
    });
    if (source != null) {
      unawaited(
        _repo().then(
          (repo) => repo.updateReadPosition(
            source,
            page: pageNumber,
            pageCount: _document?.pages.length,
            position: position,
          ),
        ),
      );
    }
  }

  ReaderPosition _captureReaderPosition(int page) {
    List<double>? matrix;
    Rect? visibleRect;
    if (_viewerController.isReady) {
      matrix = _viewerController.value.storage.toList(growable: false);
      visibleRect = _viewerController.visibleRect;
    }
    return ReaderPosition(page: page, matrix: matrix, visibleRect: visibleRect);
  }

  void _onViewerTransformChanged() {
    if (!_viewerController.isReady || _source == null || _document == null) {
      return;
    }
    _scheduleViewportPreviewUpdate();
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        unawaited(_persistCurrentReaderPosition());
      }
    });
  }

  void _scheduleViewportPreviewUpdate() {
    if (_viewportPreviewUpdateScheduled) {
      return;
    }
    _viewportPreviewUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportPreviewUpdateScheduled = false;
      if (mounted) {
        _updateViewportPreviews();
      }
    });
  }

  void _updateViewportPreviews() {
    final previews = _captureViewportPreviews();
    if (_viewportPreviewsEqual(_viewportPreviews, previews)) {
      return;
    }
    setState(() => _viewportPreviews = previews);
  }

  List<PageViewportPreview> _captureViewportPreviews() {
    final document = _document;
    if (!_viewerController.isReady || document == null) {
      return const [];
    }
    final visible = _viewerController.visibleRect;
    final layouts = _viewerController.layout.pageLayouts;
    final count = math.min(document.pages.length, layouts.length);
    final previews = <PageViewportPreview>[];
    for (var index = 0; index < count; index++) {
      final pageRect = layouts[index];
      final intersection = visible.intersect(pageRect);
      if (intersection.isEmpty ||
          intersection.width <= 0.5 ||
          intersection.height <= 0.5) {
        continue;
      }
      final normalized = Rect.fromLTRB(
        ((intersection.left - pageRect.left) / pageRect.width).clamp(0.0, 1.0),
        ((intersection.top - pageRect.top) / pageRect.height).clamp(0.0, 1.0),
        ((intersection.right - pageRect.left) / pageRect.width).clamp(0.0, 1.0),
        ((intersection.bottom - pageRect.top) / pageRect.height).clamp(
          0.0,
          1.0,
        ),
      );
      if (normalized.width <= 0.001 || normalized.height <= 0.001) {
        continue;
      }
      previews.add(PageViewportPreview(page: index + 1, rects: [normalized]));
    }
    return previews;
  }

  bool _viewportPreviewsEqual(
    List<PageViewportPreview> first,
    List<PageViewportPreview> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    const tolerance = 0.0025;
    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];
      if (a.page != b.page || a.rects.length != b.rects.length) {
        return false;
      }
      for (var j = 0; j < a.rects.length; j++) {
        final ar = a.rects[j];
        final br = b.rects[j];
        if ((ar.left - br.left).abs() > tolerance ||
            (ar.top - br.top).abs() > tolerance ||
            (ar.right - br.right).abs() > tolerance ||
            (ar.bottom - br.bottom).abs() > tolerance) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _persistCurrentReaderPosition() async {
    final source = _source;
    if (source == null || !_viewerController.isReady) {
      return;
    }
    final page = _viewerController.pageNumber ?? _currentPage;
    final position = _captureReaderPosition(page);
    if (mounted) {
      setState(() {
        _currentPage = page;
        _jumpPageController.text = '$page';
        _applyLocalReadPosition(page, position);
      });
    }
    await (await _repo()).updateReadPosition(
      source,
      page: page,
      pageCount: _document?.pages.length,
      position: position,
    );
  }

  void _applyLocalReadPosition(int page, ReaderPosition position) {
    _recent = _recent
        .map(
          (item) => item.path == _source?.path
              ? item
                    .copyWith(page: page, openedAt: DateTime.now())
                    .copyWith(position: position)
              : item,
        )
        .toList();
    _sessionTabs = _sessionTabs
        .map(
          (item) => item.source.id == _source?.id
              ? item.copyWith(page: page, position: position)
              : item,
        )
        .toList();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _runSearch(String query) {
    final textSearcher = _textSearcher;
    final trimmed = query.trim();
    if (textSearcher == null) {
      _searchResultsActive = false;
      return;
    }
    if (trimmed.isEmpty) {
      textSearcher.resetTextSearch();
      _searchResultsActive = false;
      return;
    }
    _searchResultsActive = true;
    textSearcher.startTextSearch(trimmed, caseInsensitive: true);
    if (trimmed.isNotEmpty) {
      _showSearchPanel();
    }
    _fitWidthNextFrame();
  }

  Future<void> _goToSearchMatchIndex(int index) async {
    final textSearcher = _textSearcher;
    if (textSearcher == null) {
      return;
    }
    final resolved = await textSearcher.goToMatchOfIndex(index);
    if (resolved < 0) {
      return;
    }
    await _alignSearchMatchInViewport(resolved);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _goToNextSearchMatch() async {
    final textSearcher = _textSearcher;
    if (textSearcher == null || textSearcher.matches.isEmpty) {
      return;
    }
    var resolved = await textSearcher.goToNextMatch();
    if (resolved < 0) {
      resolved = await textSearcher.goToMatchOfIndex(0);
    }
    if (resolved < 0) {
      return;
    }
    await _alignSearchMatchInViewport(resolved);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _goToPreviousSearchMatch() async {
    final textSearcher = _textSearcher;
    if (textSearcher == null || textSearcher.matches.isEmpty) {
      return;
    }
    var resolved = await textSearcher.goToPrevMatch();
    if (resolved < 0) {
      resolved = await textSearcher.goToMatchOfIndex(
        textSearcher.matches.length - 1,
      );
    }
    if (resolved < 0) {
      return;
    }
    await _alignSearchMatchInViewport(resolved);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _alignSearchMatchInViewport(int index) async {
    final textSearcher = _textSearcher;
    if (textSearcher == null ||
        !_viewerController.isReady ||
        index < 0 ||
        index >= textSearcher.matches.length) {
      return;
    }

    final match = textSearcher.matches[index];
    final matchRect = _viewerController.calcRectForRectInsidePage(
      pageNumber: match.pageNumber,
      rect: match.bounds,
    );
    final zoom = _viewerController.currentZoom;
    if (zoom <= 0) {
      return;
    }

    const topInsetPx = 72.0;
    const bottomInsetPx = 40.0;
    const horizontalInsetPx = 36.0;
    final visible = _viewerController.visibleRect;
    final viewSize = _viewerController.viewSize;
    final viewWidth = viewSize.width / zoom;
    final viewHeight = viewSize.height / zoom;
    final topInset = topInsetPx / zoom;
    final bottomInset = bottomInsetPx / zoom;
    final horizontalInset = horizontalInsetPx / zoom;

    var targetLeft = visible.left;
    final horizontalSafeLeft = visible.left + horizontalInset;
    final horizontalSafeRight = visible.left + viewWidth - horizontalInset;
    if (matchRect.left < horizontalSafeLeft ||
        matchRect.right > horizontalSafeRight) {
      targetLeft = matchRect.center.dx - viewWidth / 2;
      if (matchRect.width + horizontalInset * 2 > viewWidth) {
        targetLeft = matchRect.left - horizontalInset;
      }
    }

    var targetTop = matchRect.top - topInset;
    final visibleBottom = targetTop + viewHeight - bottomInset;
    if (matchRect.bottom > visibleBottom) {
      targetTop = matchRect.bottom - viewHeight + bottomInset;
    }

    await _viewerController.goToPosition(
      documentOffset: Offset(
        math.max(0.0, targetLeft),
        math.max(0.0, targetTop),
      ),
      zoom: zoom,
      duration: const Duration(milliseconds: 140),
    );
  }

  bool _isCompactLayout() {
    return MediaQuery.sizeOf(context).width <
        ReaderToolbarMetrics.collapseToolbarExtrasBelow;
  }

  void _showSearchPanel() {
    final compact = _isCompactLayout();
    setState(() {
      _panelMode = PanelMode.search;
      _compactPanelOpen = compact;
      if (!compact) {
        _panelCollapsed = false;
      }
    });
  }

  void _selectPanel(PanelMode mode, {required bool compact}) {
    final wasSearch = _panelMode == PanelMode.search;
    var shouldFitWidth = wasSearch || mode == PanelMode.search || !compact;
    setState(() {
      if (compact && _panelMode == mode && _compactPanelOpen) {
        _compactPanelOpen = false;
        shouldFitWidth = mode == PanelMode.search;
        return;
      }
      if (!compact) {
        if (_panelMode == mode) {
          _panelCollapsed = !_panelCollapsed;
        } else {
          _panelMode = mode;
          _panelCollapsed = false;
        }
        _compactPanelOpen = false;
        return;
      }
      _panelMode = mode;
      _compactPanelOpen = compact;
    });
    if (shouldFitWidth) {
      _fitWidthNextFrame();
    }
  }

  void _collapsePanel() {
    if (_panelCollapsed) {
      return;
    }
    setState(() => _panelCollapsed = true);
    _fitWidthNextFrame();
  }

  void _setThumbnailColumns(bool twoColumn) {
    if (_twoColumnThumbnails == twoColumn) {
      return;
    }
    setState(() {
      _twoColumnThumbnails = twoColumn;
      _settings = _settings.copyWith(thumbnailTwoColumn: twoColumn);
    });
    unawaited(_saveSettings());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewerController.isReady) {
        _fitWidth();
      }
    });
  }

  void _setThumbnailAnchorPage(int page) {
    final normalized = math.max(1, page);
    if (_thumbnailAnchorPage == normalized) {
      return;
    }
    setState(() {
      _thumbnailAnchorPage = normalized;
      _settings = _settings.copyWith(thumbnailAnchorPage: normalized);
    });
    unawaited(_saveSettings());
  }

  void _setNightMode(bool value) {
    setState(() => _nightMode = value);
    unawaited(_syncTitleBarTheme());
  }

  void _setShortcutBinding(
    ReaderShortcutAction action,
    ReaderShortcutBinding binding,
  ) {
    final shortcuts = Map<ReaderShortcutAction, ReaderShortcutBinding>.of(
      _settings.shortcutBindings,
    );
    shortcuts[action] = binding;
    setState(() => _settings = _settings.copyWith(shortcutBindings: shortcuts));
    unawaited(_saveSettings());
  }

  bool _handleWindowShortcutKeyEvent(KeyEvent event) {
    if (!mounted ||
        !_pointerInsideWindow ||
        _globalShortcutsSuspended ||
        !_isReaderRouteCurrent()) {
      return false;
    }
    if (event is! KeyDownEvent) {
      return false;
    }
    if (_highlightColorMenuOpen) {
      return false;
    }
    if (_openTabsMenuOpen && event.logicalKey == LogicalKeyboardKey.escape) {
      _closeTabsMenu();
      return true;
    }
    final recentFileIndex = _recentFileShortcutIndex(event);
    if (recentFileIndex != null) {
      _openRecentFileFromMenu(recentFileIndex);
      return true;
    }
    if (_handleLibraryRecentKeyEvent(event)) {
      return true;
    }
    final action = _actionForKeyEvent(event);
    if (action == null) {
      return false;
    }
    if (_isEditableFocusActive() &&
        action != ReaderShortcutAction.clearSearch) {
      return false;
    }
    _handleShortcut(action);
    return true;
  }

  int? _recentFileShortcutIndex(KeyEvent event) {
    if (!_openTabsMenuOpen) {
      return null;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return null;
    }
    final keyId = event.logicalKey.keyId;
    if (keyId >= LogicalKeyboardKey.digit1.keyId &&
        keyId <= LogicalKeyboardKey.digit9.keyId) {
      return keyId - LogicalKeyboardKey.digit1.keyId;
    }
    return null;
  }

  bool _handleLibraryRecentKeyEvent(KeyEvent event) {
    if (!_isLibraryPanelVisible() ||
        _recent.isEmpty ||
        _isEditableFocusActive()) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _selectedRecentIndex = _clampedRecentIndex(
          _selectedRecentIndex - 1,
          _recent,
        );
      });
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _selectedRecentIndex = _clampedRecentIndex(
          _selectedRecentIndex + 1,
          _recent,
        );
      });
      return true;
    }
    if (key == LogicalKeyboardKey.enter) {
      final index = _clampedRecentIndex(_selectedRecentIndex, _recent);
      unawaited(_openRecent(_recent[index]));
      return true;
    }
    return false;
  }

  bool _isLibraryPanelVisible() {
    if (_panelMode != PanelMode.library) {
      return false;
    }
    return _isCompactLayout() ? _compactPanelOpen : !_panelCollapsed;
  }

  ReaderShortcutAction? _actionForKeyEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    for (final entry in _settings.shortcutBindings.entries) {
      final binding = entry.value;
      if (binding.logicalKey == event.logicalKey &&
          binding.control == keyboard.isControlPressed &&
          binding.shift == keyboard.isShiftPressed &&
          binding.alt == keyboard.isAltPressed &&
          binding.meta == keyboard.isMetaPressed) {
        return entry.key;
      }
    }
    return null;
  }

  bool _isReaderRouteCurrent() {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  bool _isEditableFocusActive() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool get _usesCustomWindowChrome => _windowChrome.isSupported;

  void _queueWindowTransition(WindowTransitionKind kind) {
    final now = DateTime.now();
    final previous = _lastWindowTransitionAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 90) &&
        _windowTransitionKind == kind) {
      return;
    }
    _lastWindowTransitionAt = now;
    _windowTransitionKind = kind;
    _windowTransitionTrigger++;
  }

  void _startWindowTransition(WindowTransitionKind kind) {
    if (!_usesCustomWindowChrome || !mounted) {
      return;
    }
    setState(() => _queueWindowTransition(kind));
  }

  Future<void> _refreshSystemResolution() async {
    if (!mounted) {
      return;
    }
    final fallback = _fallbackSystemResolution();
    var resolution = fallback;
    if (_usesCustomWindowChrome) {
      try {
        final dpi = await _windowChrome.getWindowDpi();
        if (dpi != null && dpi > 0) {
          resolution = dpi;
        }
      } catch (_) {
        resolution = fallback;
      }
    }
    resolution = ReaderSettings.normalizedSystemResolution(resolution);
    if (!mounted || _systemResolution == resolution) {
      return;
    }

    final previousResolution = _systemResolution;
    final previousRenderResolution = previousResolution == null
        ? null
        : _settings.effectiveResolutionForSystemResolution(previousResolution);
    final nextRenderResolution = _settings
        .effectiveResolutionForSystemResolution(resolution);
    setState(() {
      if (_viewerController.isReady &&
          _settings.resolutionMode == ResolutionMode.systemSetting &&
          previousRenderResolution != null &&
          previousRenderResolution != nextRenderResolution) {
        _pendingOpenPosition = _captureReaderPosition(
          _viewerController.pageNumber ?? _currentPage,
        );
      }
      _systemResolution = resolution;
    });
  }

  Future<void> _invokeWindowChrome(String method) async {
    if (!_usesCustomWindowChrome) {
      return;
    }
    try {
      await _windowChrome.invoke(method);
    } catch (_) {
      // Older runners keep the native window controls.
    }
  }

  void _startWindowDrag() {
    if (!_usesCustomWindowChrome) {
      return;
    }
    unawaited(_startWindowDragAsync());
  }

  Future<void> _startWindowDragAsync() async {
    await _invokeWindowChrome('startWindowDrag');
    await _refreshWindowMaximized();
  }

  void _startWindowResize(WindowResizeEdge edge) {
    if (!_usesCustomWindowChrome || _windowMaximized) {
      return;
    }
    unawaited(_startWindowResizeAsync(edge));
  }

  Future<void> _startWindowResizeAsync(WindowResizeEdge edge) async {
    try {
      await _windowChrome.startWindowResize(edge);
      await _refreshWindowMaximized();
      await _saveCurrentWindowSize();
    } catch (_) {
      // Older runners keep their existing resize behavior.
    }
  }

  void _minimizeWindow() {
    unawaited(_minimizeWindowAsync());
  }

  Future<void> _minimizeWindowAsync() async {
    _startWindowTransition(WindowTransitionKind.minimize);
    await Future<void>.delayed(WindowTransitionFrame.minimizeLeadDuration);
    await _invokeWindowChrome('minimizeWindow');
  }

  void _toggleMaximizeWindow() {
    if (!_usesCustomWindowChrome) {
      return;
    }
    _startWindowTransition(WindowTransitionKind.resize);
    unawaited(_toggleMaximizeWindowAsync());
  }

  Future<void> _toggleMaximizeWindowAsync() async {
    try {
      final maximized = await _windowChrome.toggleMaximizeWindow();
      if (mounted && maximized != null) {
        setState(() => _windowMaximized = maximized);
        if (!maximized) {
          _scheduleSaveCurrentWindowSize();
        }
      }
    } catch (_) {
      // Older runners keep the native window controls.
    }
  }

  Future<void> _refreshWindowMaximized() async {
    if (!_usesCustomWindowChrome) {
      return;
    }
    try {
      final maximized = await _windowChrome.isWindowMaximized();
      if (mounted && maximized != null) {
        setState(() => _windowMaximized = maximized);
      }
    } catch (_) {
      // Older runners keep the native window controls.
    }
  }

  Future<void> _syncMinimumWindowSize() async {
    if (!_usesCustomWindowChrome) {
      return;
    }
    try {
      await _windowChrome.setMinimumWindowSize(
        width: ReaderToolbarMetrics.minimumWindowWidth,
        height: ReaderToolbarMetrics.minimumWindowHeight,
      );
    } catch (_) {
      // Older runners keep their existing minimum window size.
    }
  }

  void _closeWindow() {
    unawaited(_closeWindowAsync());
  }

  Future<void> _closeWindowAsync() async {
    await _saveCurrentWindowSize();
    await _invokeWindowChrome('closeWindow');
  }

  void _scheduleSaveCurrentWindowSize() {
    if (!_usesCustomWindowChrome || !_settings.rememberWindowSize) {
      return;
    }
    _windowSizeSaveTimer?.cancel();
    _windowSizeSaveTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        unawaited(_saveCurrentWindowSize());
      }
    });
  }

  Future<void> _restoreRememberedWindowSize(ReaderSettings settings) async {
    if (!_usesCustomWindowChrome || !settings.rememberWindowSize) {
      return;
    }
    final width = settings.rememberedWindowWidth;
    final height = settings.rememberedWindowHeight;
    if (width == null || height == null) {
      return;
    }
    try {
      await _windowChrome.setWindowSize(width: width, height: height);
      await _refreshWindowMaximized();
    } catch (_) {
      // Older runners keep the startup window size.
    }
  }

  Future<({int width, int height})?> _readCurrentWindowSize() async {
    if (!_usesCustomWindowChrome) {
      return null;
    }
    return _windowChrome.getWindowSize();
  }

  Future<void> _saveCurrentWindowSize() async {
    if (!_usesCustomWindowChrome || !_settings.rememberWindowSize) {
      return;
    }
    if (_windowMaximized) {
      return;
    }
    try {
      final size = await _readCurrentWindowSize();
      if (size == null || !mounted) {
        return;
      }
      final next = _settings.copyWith(
        rememberedWindowWidth: size.width,
        rememberedWindowHeight: size.height,
      );
      if (next.rememberedWindowWidth == _settings.rememberedWindowWidth &&
          next.rememberedWindowHeight == _settings.rememberedWindowHeight) {
        return;
      }
      setState(() => _settings = next);
      await _saveSettings();
    } catch (_) {
      // Older runners do not expose persisted window dimensions.
    }
  }

  Future<void> _syncTitleBarTheme() async {
    if (!_usesCustomWindowChrome) {
      return;
    }
    if (_syncedTitleBarNightMode == _nightMode) {
      return;
    }
    _syncedTitleBarNightMode = _nightMode;
    try {
      await _windowChrome.setTitleBarTheme(dark: _nightMode);
    } catch (_) {
      // Non-Windows builds and older runners simply keep the system title bar.
    }
  }

  Future<void> _showSettings() async {
    await _refreshSystemResolution();
    if (!mounted) {
      return;
    }
    _globalShortcutsSuspended = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return SettingsDialog(
            settings: _settings,
            nightMode: _nightMode,
            systemResolution: _currentSystemResolution(),
            onSettingsChanged: (settings) {
              final previous = _settings;
              final previousRenderResolution = _effectiveRenderResolutionFor(
                previous,
              );
              final nextRenderResolution = _effectiveRenderResolutionFor(
                settings,
              );
              setState(() {
                if (_viewerController.isReady &&
                    previousRenderResolution != nextRenderResolution) {
                  _pendingOpenPosition = _captureReaderPosition(
                    _viewerController.pageNumber ?? _currentPage,
                  );
                }
                _settings = settings;
              });
              if (settings.rememberWindowSize) {
                _scheduleSaveCurrentWindowSize();
              }
              unawaited(_saveSettings());
            },
            onNightModeChanged: _setNightMode,
            onShortcutChanged: _setShortcutBinding,
            onClearSoftwareCache: _clearSoftwareCache,
            onClearAllFileData: _clearAllFileData,
            onClearSelectedFileData: _clearSelectedFileData,
            onLoadFileData: _loadFileData,
          );
        },
      );
    } finally {
      _globalShortcutsSuspended = false;
    }
  }

  Future<void> _clearSoftwareCache() async {
    await widget.settingsStore.clear();
    await (await _repo()).clearRecent();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = const ReaderSettings();
      _twoColumnThumbnails = _settings.thumbnailTwoColumn;
      _thumbnailAnchorPage = _settings.thumbnailAnchorPage;
      _recent = const [];
      _selectedRecentIndex = 0;
      _loadingLibrary = false;
    });
    _showMessage('已清除软件缓存，不会删除本地 PDF 文件。');
  }

  Future<List<FileDataSummary>> _loadFileData() async {
    return (await _repo()).listFileData();
  }

  Future<void> _clearAllFileData() async {
    await (await _repo()).clearFileData();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = const [];
      _highlights = const [];
      _recent = [
        for (final item in _recent)
          item.copyWith(page: 1, fileHash: null, position: null),
      ];
      _selectedRecentIndex = _clampedRecentIndex(_selectedRecentIndex, _recent);
    });
    _showMessage('已清除全部 PDF 文件数据。');
  }

  Future<void> _clearSelectedFileData(Set<String> hashes) async {
    if (hashes.isEmpty) {
      return;
    }
    await (await _repo()).deleteFileDataByHashes(hashes);
    if (!mounted) {
      return;
    }
    final currentHash = _source?.hash;
    setState(() {
      _recent = [
        for (final item in _recent)
          hashes.contains(item.fileHash)
              ? item.copyWith(page: 1, fileHash: null, position: null)
              : item,
      ];
      _selectedRecentIndex = _clampedRecentIndex(_selectedRecentIndex, _recent);
      if (currentHash != null && hashes.contains(currentHash)) {
        _notes = const [];
        _highlights = const [];
      }
    });
    _showMessage('已清除选中文件数据。');
  }

  Future<void> _deleteRecent(RecentDocument item) async {
    await (await _repo()).deleteRecent(item.path);
    if (!mounted) {
      return;
    }
    setState(() {
      _recent = _recent.where((recent) => recent.path != item.path).toList();
      _selectedRecentIndex = _clampedRecentIndex(_selectedRecentIndex, _recent);
      _sessionTabs = _sessionTabs
          .where((tab) => tab.source.path != item.path)
          .toList();
    });
    _showMessage('已从最近文件移除。');
  }

  Future<void> _clearRecent() async {
    await (await _repo()).clearRecent();
    if (!mounted) {
      return;
    }
    setState(() {
      _recent = const [];
      _selectedRecentIndex = 0;
      _sessionTabs = const [];
    });
    _showMessage('已清空最近文件。');
  }

  Future<void> _showPdfContextMenu(PdfSource source, Offset position) async {
    final action = await showThemedContextMenu<Pdf2zhAction>(
      context: context,
      position: position,
      minWidth: 128,
      items: [
        for (final action in Pdf2zhAction.values)
          themedContextMenuItem(value: action, label: action.label),
      ],
    );
    if (action == null) {
      return;
    }
    unawaited(_runPdf2zhAction(source, action));
  }

  Future<void> _runPdf2zhAction(PdfSource source, Pdf2zhAction action) async {
    if (action == Pdf2zhAction.checkService) {
      final running = await _pdf2zhService.isRunning(
        _settings.pdf2zhServiceUrl,
      );
      if (!mounted) {
        return;
      }
      _showMessage(running ? 'pdf2zh 本地服务正在运行。' : '未检测到 pdf2zh 本地服务。');
      return;
    }
    if (source.path == null || source.path!.isEmpty) {
      _showMessage('pdf2zh 需要本地 PDF 文件路径。');
      return;
    }
    if (mounted) {
      setState(() => _status = '正在提交 pdf2zh 任务...');
    }
    try {
      final saved = await _pdf2zhService.run(
        source: source,
        settings: _settings,
        action: action,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        saved.isEmpty ? 'pdf2zh 已完成请求。' : 'pdf2zh 已导出 ${saved.length} 个文件。',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _status = _document == null ? null : '${_document!.pages.length} 页';
        });
      }
    }
  }

  void _translateSelectionText(String text) {
    final trimmed = SelectionTranslationService.normalizeSelectionText(text);
    if (trimmed.isEmpty) {
      _showMessage('没有可翻译的选中文本。');
      return;
    }
    setState(() {
      _translationSourceText = trimmed;
      _translationResult = null;
      _panelMode = PanelMode.translate;
      _compactPanelOpen =
          MediaQuery.sizeOf(context).width <
          ReaderToolbarMetrics.collapseToolbarExtrasBelow;
      _panelCollapsed = false;
    });
    unawaited(_runSelectionTranslation(trimmed));
  }

  Future<void> _runSelectionTranslation(String text) async {
    final result = await _selectionTranslationService.translate(
      text: text,
      settings: _settings,
    );
    if (!mounted || _translationSourceText != text) {
      return;
    }
    final summary = result.summary.trim().isEmpty ? '未返回翻译结果。' : result.summary;
    setState(() => _translationResult = result);
    final autoPlayAudio = _autoPlayPronunciation(result.audio);
    if (autoPlayAudio != null) {
      unawaited(_selectionAudioPlayer.play(UrlSource(autoPlayAudio.url)));
    }
    if (_settings.selectionTranslatePopup) {
      final compact = summary.length > 180
          ? '${summary.substring(0, 180)}...'
          : summary;
      _showMessage(compact);
    }
  }

  PronunciationAudio? _autoPlayPronunciation(List<PronunciationAudio> audio) {
    final accent = switch (_settings.selectionAutoPlayPronunciation) {
      PronunciationAutoPlay.us => PronunciationAccent.us,
      PronunciationAutoPlay.uk => PronunciationAccent.uk,
      PronunciationAutoPlay.off => null,
    };
    if (accent == null) {
      return null;
    }
    for (final item in audio) {
      if (item.accent == accent) {
        return item;
      }
    }
    return null;
  }

  void _goToPage(int page) {
    final pageCount = _document?.pages.length ?? 0;
    if (pageCount == 0) {
      return;
    }
    final next = page.clamp(1, pageCount);
    _viewerController.goToPage(pageNumber: next);
  }

  void _selectNote(PageNote note) {
    final compact =
        MediaQuery.sizeOf(context).width <
        ReaderToolbarMetrics.collapseToolbarExtrasBelow;
    setState(() {
      _selectedNoteId = note.id;
      _panelMode = PanelMode.notes;
      _panelCollapsed = false;
      if (compact) {
        _compactPanelOpen = true;
      }
    });
    _goToNote(note);
  }

  void _clearSelectedNote() {
    if (_selectedNoteId == null) {
      return;
    }
    setState(() => _selectedNoteId = null);
  }

  void _goToAdjacentNote(int direction) {
    if (_notes.isEmpty) {
      return;
    }
    final sorted = List<PageNote>.of(_notes)..sort(PageNote.compareByPosition);
    final currentIndex = sorted.indexWhere(
      (note) => note.id == _selectedNoteId,
    );
    final baseIndex = currentIndex < 0
        ? (direction > 0 ? -1 : 0)
        : currentIndex;
    final nextIndex = (baseIndex + direction) % sorted.length;
    _selectNote(sorted[nextIndex < 0 ? sorted.length - 1 : nextIndex]);
  }

  Future<void> _updateNoteTextInline(PageNote note, String text) async {
    final nextText = text.trim();
    final now = DateTime.now();
    setState(() {
      _selectedNoteId = note.id;
      _notes = [
        for (final item in _notes)
          if (item.id == note.id)
            item.copyWith(text: nextText, updatedAt: now)
          else
            item,
      ]..sort(PageNote.compareByPosition);
    });
    await _saveNotes();
  }

  void _goToNote(PageNote note) {
    final document = _document;
    if (!_viewerController.isReady ||
        document == null ||
        note.page < 1 ||
        note.page > document.pages.length ||
        note.page > _viewerController.layout.pageLayouts.length) {
      _goToPage(note.page);
      return;
    }

    final documentRect = _noteDocumentRect(note);
    if (documentRect != null) {
      _alignDocumentRectInViewport(documentRect);
      return;
    }

    final page = document.pages[note.page - 1];
    final pageRect = _viewerController.layout.pageLayouts[note.page - 1];
    final localPoint = _noteLocalPoint(note, page);
    if (localPoint == null) {
      _goToPage(note.page);
      return;
    }

    final documentPoint = Offset(
      pageRect.left + localPoint.dx / page.width * pageRect.width,
      pageRect.top + localPoint.dy / page.height * pageRect.height,
    );
    final zoom = _viewerController.currentZoom;
    final viewportWidth = _viewerController.viewSize.width / zoom;
    final viewportHeight = _viewerController.viewSize.height / zoom;
    final documentSize = _viewerController.documentSize;
    final target = Offset(
      (documentPoint.dx - viewportWidth * 0.28).clamp(
        0.0,
        math.max(0.0, documentSize.width - viewportWidth),
      ),
      (documentPoint.dy - viewportHeight * 0.30).clamp(
        0.0,
        math.max(0.0, documentSize.height - viewportHeight),
      ),
    );
    unawaited(
      _viewerController.goToPosition(
        documentOffset: target,
        zoom: zoom,
        duration: const Duration(milliseconds: 160),
      ),
    );
  }

  void _alignDocumentRectInViewport(Rect documentRect) {
    final zoom = _viewerController.currentZoom;
    if (zoom <= 0) {
      return;
    }

    const topInsetPx = 72.0;
    const bottomInsetPx = 40.0;
    const horizontalInsetPx = 36.0;
    final visible = _viewerController.visibleRect;
    final viewSize = _viewerController.viewSize;
    final viewWidth = viewSize.width / zoom;
    final viewHeight = viewSize.height / zoom;
    final topInset = topInsetPx / zoom;
    final bottomInset = bottomInsetPx / zoom;
    final horizontalInset = horizontalInsetPx / zoom;
    final documentSize = _viewerController.documentSize;

    var targetLeft = visible.left;
    final safeLeft = visible.left + horizontalInset;
    final safeRight = visible.left + viewWidth - horizontalInset;
    if (documentRect.left < safeLeft || documentRect.right > safeRight) {
      targetLeft = documentRect.center.dx - viewWidth / 2;
      if (documentRect.width + horizontalInset * 2 > viewWidth) {
        targetLeft = documentRect.left - horizontalInset;
      }
    }

    var targetTop = documentRect.top - topInset;
    if (documentRect.height + topInset + bottomInset > viewHeight) {
      targetTop = documentRect.top - topInset;
    }

    final maxLeft = math.max(0.0, documentSize.width - viewWidth);
    final maxTop = math.max(0.0, documentSize.height - viewHeight);
    unawaited(
      _viewerController.goToPosition(
        documentOffset: Offset(
          targetLeft.clamp(0.0, maxLeft).toDouble(),
          targetTop.clamp(0.0, maxTop).toDouble(),
        ),
        zoom: zoom,
        duration: const Duration(milliseconds: 160),
      ),
    );
  }

  Rect? _noteDocumentRect(PageNote note) {
    final document = _document;
    if (!_viewerController.isReady ||
        document == null ||
        note.page < 1 ||
        note.page > document.pages.length ||
        note.page > _viewerController.layout.pageLayouts.length) {
      return null;
    }

    final page = document.pages[note.page - 1];
    final pageRect = _viewerController.layout.pageLayouts[note.page - 1];
    final highlightId = note.highlightId;
    if (highlightId != null) {
      for (final highlight in _highlights) {
        if (highlight.id == highlightId) {
          return _highlightDocumentRect(highlight, page, pageRect);
        }
      }
    }

    final localPoint = _noteLocalPoint(note, page);
    if (localPoint == null) {
      return null;
    }
    final scale = pageRect.width / page.width;
    final size = scale * 28.0;
    final pagePoint = Offset(
      localPoint.dx / page.width * pageRect.width,
      localPoint.dy / page.height * pageRect.height,
    );
    final left = (pagePoint.dx - size * 0.78).clamp(
      0.0,
      math.max(0.0, pageRect.width - size),
    );
    final top = (pagePoint.dy - size * 0.78).clamp(
      0.0,
      math.max(0.0, pageRect.height - size),
    );
    return Rect.fromLTWH(
      pageRect.left + left.toDouble() - 3,
      pageRect.top + top.toDouble() - 3,
      size + 6,
      size + 6,
    );
  }

  Rect? _highlightDocumentRect(
    TextHighlight highlight,
    PdfPage page,
    Rect pageRect,
  ) {
    Rect? union;
    for (final rect in highlight.rects) {
      final local = rect.toPdfRect().toRect(
        page: page,
        scaledPageSize: pageRect.size,
      );
      if (local.width <= 0.2 || local.height <= 0.2) {
        continue;
      }
      final band = Rect.fromLTRB(
        local.left - 0.8,
        local.top + local.height * 0.06,
        local.right + 0.8,
        local.bottom - local.height * 0.02,
      ).translate(pageRect.left, pageRect.top);
      union = union == null ? band : union.expandToInclude(band);
    }
    return union?.inflate(3);
  }

  Offset? _noteLocalPoint(PageNote note, PdfPage page) {
    final highlightId = note.highlightId;
    if (highlightId != null) {
      for (final highlight in _highlights) {
        if (highlight.id == highlightId) {
          return _firstHighlightPoint(highlight);
        }
      }
    }
    final x = note.x;
    final y = note.y;
    if (x == null || y == null) {
      return null;
    }
    return Offset(
      x.clamp(0.0, page.width).toDouble(),
      y.clamp(0.0, page.height).toDouble(),
    );
  }

  void _jumpFromField() {
    final page = int.tryParse(_jumpPageController.text);
    if (page != null) {
      _goToPage(page);
    } else {
      _jumpPageController.text = '$_currentPage';
    }
  }

  void _zoomIn() {
    _viewerController.zoomUp();
  }

  void _zoomOut() {
    _viewerController.zoomDown();
  }

  void _fitWidth({double? anchorTop}) {
    final pageNumber = _viewerController.pageNumber ?? _currentPage;
    if (!_viewerController.isReady ||
        pageNumber < 1 ||
        pageNumber > _viewerController.layout.pageLayouts.length) {
      return;
    }
    final pageRect = _viewerController.layout.pageLayouts[pageNumber - 1];
    final visibleTop = anchorTop ?? _viewerController.visibleRect.top;
    final zoom = (_viewerController.viewSize.width / pageRect.width)
        .clamp(_viewerController.minScale, _viewerController.maxScale)
        .toDouble();
    final centerY = visibleTop + _viewerController.viewSize.height / (2 * zoom);
    _viewerController.goTo(
      _viewerController.calcMatrixFor(
        Offset(pageRect.center.dx, centerY),
        zoom: zoom,
      ),
    );
  }

  void _fitWidthNextFrame() {
    final anchorTop = _viewerController.isReady
        ? _viewerController.visibleRect.top
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewerController.isReady) {
        _fitWidth(anchorTop: anchorTop);
      }
    });
  }

  void _fitPage() {
    final pageNumber = _viewerController.pageNumber ?? _currentPage;
    _viewerController.goTo(
      _viewerController.calcMatrixForFit(pageNumber: pageNumber),
    );
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入 PDF 密码'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('打开'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _addNote() async {
    if (_source == null) {
      _showMessage('请先打开一个 PDF。');
      return;
    }
    if (_noteEditorOpening) {
      return;
    }
    _noteEditorOpening = true;
    final point = _defaultNotePositionForPage(_currentPage);
    final now = DateTime.now();
    final draft = PageNote(
      id: now.microsecondsSinceEpoch.toString(),
      page: _currentPage,
      text: '',
      x: point?.dx,
      y: point?.dy,
      colorValue: _highlightColor.toARGB32(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      final result = await _editNoteTextDialog(draft);
      if (result == null || result.action == _NoteEditorAction.delete) {
        return;
      }
      final note = draft.copyWith(
        text: result.text.trim(),
        updatedAt: DateTime.now(),
      );
      setState(() {
        if (_notes.any((item) => item.id == note.id)) {
          return;
        }
        _notes = [note, ..._notes]..sort(PageNote.compareByPosition);
      });
      await _saveNotes();
    } finally {
      _noteEditorOpening = false;
    }
  }

  Offset? _defaultNotePositionForPage(int pageNumber) {
    final document = _document;
    if (!_viewerController.isReady ||
        document == null ||
        pageNumber < 1 ||
        pageNumber > document.pages.length ||
        pageNumber > _viewerController.layout.pageLayouts.length) {
      return null;
    }
    final page = document.pages[pageNumber - 1];
    final pageRect = _viewerController.layout.pageLayouts[pageNumber - 1];
    final visible = _viewerController.visibleRect;
    final x =
        ((math.max(visible.left, pageRect.left) - pageRect.left) /
                    pageRect.width *
                    page.width +
                28)
            .clamp(0.0, page.width);
    final y =
        ((math.max(visible.top, pageRect.top) - pageRect.top) /
                    pageRect.height *
                    page.height +
                28)
            .clamp(0.0, page.height);
    return Offset(x.toDouble(), y.toDouble());
  }

  Future<_NoteEditorResult?> _editNoteTextDialog(
    PageNote note, {
    Offset? anchor,
    String? title,
    String? hintText,
  }) {
    final controller = TextEditingController(text: note.text);

    Widget buildEditor(BuildContext context) {
      return _NoteEditorCard(
        title: title ?? '编辑第 ${note.page} 页笔记',
        page: note.page,
        controller: controller,
        hintText: hintText ?? '写下评论内容',
        color: Color(note.colorValue),
        onCancel: () => Navigator.of(context).pop(),
        onClear: () => Navigator.of(
          context,
        ).pop(const _NoteEditorResult(_NoteEditorAction.clear, '')),
        onDelete: () => Navigator.of(
          context,
        ).pop(const _NoteEditorResult(_NoteEditorAction.delete, '')),
        onSave: () => Navigator.of(
          context,
        ).pop(_NoteEditorResult(_NoteEditorAction.save, controller.text)),
      );
    }

    if (anchor == null) {
      return showDialog<_NoteEditorResult>(
        context: context,
        builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: buildEditor(context),
          ),
        ),
      ).whenComplete(controller.dispose);
    }

    return showGeneralDialog<_NoteEditorResult>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (context, _, _) {
        final size = MediaQuery.sizeOf(context);
        const width = 360.0;
        const estimatedHeight = 228.0;
        final left = (anchor.dx - 42).clamp(12.0, size.width - width - 12);
        final top = (anchor.dy + 12).clamp(
          12.0,
          size.height - estimatedHeight - 12,
        );
        return Stack(
          children: [
            Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              width: width,
              child: Material(
                color: Colors.transparent,
                child: buildEditor(context),
              ),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _editNote(PageNote note, {Offset? anchor}) async {
    final result = await _editNoteTextDialog(note, anchor: anchor);
    if (result == null) {
      return;
    }
    if (result.action == _NoteEditorAction.delete) {
      await _deleteNote(note, showMessage: false);
      return;
    }
    final nextText = result.text.trim();
    final now = DateTime.now();
    setState(() {
      final exists = _notes.any((item) => item.id == note.id);
      final updated = note.copyWith(text: nextText, updatedAt: now);
      _notes = [
        for (final item in _notes)
          if (item.id == note.id) updated else item,
        if (!exists) updated,
      ]..sort(PageNote.compareByPosition);
    });
    await _saveNotes();
  }

  Future<void> _moveNote(
    PageNote note,
    Offset? pdfPosition,
    bool commit,
  ) async {
    if (pdfPosition != null) {
      final now = DateTime.now();
      setState(() {
        _notes = [
          for (final item in _notes)
            if (item.id == note.id)
              item.copyWith(
                x: pdfPosition.dx,
                y: pdfPosition.dy,
                updatedAt: now,
              )
            else
              item,
        ]..sort(PageNote.compareByPosition);
      });
    }
    if (commit) {
      await _saveNotes();
    }
  }

  Future<void> _editHighlightNote(
    TextHighlight highlight, {
    Offset? anchor,
  }) async {
    final existing = _noteForHighlight(highlight);
    if (existing != null) {
      await _editNote(existing, anchor: anchor);
      return;
    }

    final draft = _createNoteForHighlight(highlight, text: '');
    final result = await _editNoteTextDialog(
      draft,
      anchor: anchor,
      title: '第 ${highlight.page} 页高亮评论',
      hintText: '为这段高亮添加评论',
    );
    if (result == null) {
      return;
    }
    if (result.action == _NoteEditorAction.delete) {
      await _deleteNote(draft, showMessage: false);
      return;
    }
    final comment = result.text.trim();
    final note = draft.copyWith(text: comment, updatedAt: DateTime.now());
    setState(() {
      _notes = [note, ..._notes]..sort(PageNote.compareByPosition);
    });
    await _saveNotes();
  }

  PageNote? _noteForHighlight(TextHighlight highlight) {
    for (final note in _notes) {
      if (note.highlightId == highlight.id) {
        return note;
      }
    }
    return null;
  }

  PageNote _createNoteForHighlight(
    TextHighlight highlight, {
    required String text,
  }) {
    final point = _firstHighlightPoint(highlight);
    final now = DateTime.now();
    return PageNote(
      id: 'highlight:${highlight.id}',
      page: highlight.page,
      text: text,
      x: point?.dx,
      y: point?.dy,
      highlightId: highlight.id,
      colorValue: highlight.colorValue,
      createdAt: now,
      updatedAt: now,
    );
  }

  Offset? _firstHighlightPoint(TextHighlight highlight) {
    final document = _document;
    if (highlight.rects.isEmpty ||
        document == null ||
        highlight.page < 1 ||
        highlight.page > document.pages.length) {
      return null;
    }
    final page = document.pages[highlight.page - 1];
    final sorted = List<HighlightRect>.of(highlight.rects)
      ..sort((a, b) {
        final top = a.top.compareTo(b.top);
        return top == 0 ? a.left.compareTo(b.left) : top;
      });
    final first = sorted.first.toPdfRect().toRect(page: page);
    return Offset(
      first.left.clamp(0.0, page.width).toDouble(),
      first.top.clamp(0.0, page.height).toDouble(),
    );
  }

  Future<void> _addHighlightFromSelection(List<PdfPageTextRange> ranges) async {
    if (_source == null) {
      _showMessage('请先打开一个 PDF。');
      return;
    }
    final candidates = <TextHighlight>[];
    final now = DateTime.now();
    for (final range in ranges) {
      final rects = [
        for (final fragment in range.enumerateFragmentBoundingRects())
          HighlightRect.fromPdfRect(fragment.bounds),
      ];
      if (rects.isEmpty) {
        continue;
      }
      candidates.add(
        TextHighlight(
          id: '${now.microsecondsSinceEpoch}.${candidates.length}',
          page: range.pageNumber,
          text: range.text.trim(),
          rects: rects,
          createdAt: now,
          colorValue: _highlightColor.toARGB32(),
        ),
      );
    }
    if (candidates.isEmpty) {
      _showMessage('没有可高亮的文本，请重新选择。');
      return;
    }

    final previous = List<TextHighlight>.of(_highlights);
    final candidateRectsByPage = <int, List<HighlightRect>>{};
    for (final candidate in candidates) {
      candidateRectsByPage
          .putIfAbsent(candidate.page, () => <HighlightRect>[])
          .addAll(candidate.rects);
    }

    final retained = <TextHighlight>[];
    var changedExisting = false;
    for (final highlight in previous) {
      final cutters = candidateRectsByPage[highlight.page] ?? const [];
      final nextRects = [
        for (final rect in highlight.rects)
          ..._subtractHighlightRects(rect, cutters),
      ];
      changedExisting =
          changedExisting ||
          !_highlightRectListsEqual(highlight.rects, nextRects);
      if (nextRects.isNotEmpty) {
        retained.add(highlight.copyWith(rects: nextRects));
      }
    }

    final previousRectsByPage = <int, List<HighlightRect>>{};
    for (final highlight in previous) {
      previousRectsByPage
          .putIfAbsent(highlight.page, () => <HighlightRect>[])
          .addAll(highlight.rects);
    }

    final additions = <TextHighlight>[];
    for (final candidate in candidates) {
      final blockers = previousRectsByPage[candidate.page] ?? const [];
      final nextRects = [
        for (final rect in candidate.rects)
          ..._subtractHighlightRects(rect, blockers),
      ];
      if (nextRects.isNotEmpty) {
        additions.add(candidate.copyWith(rects: nextRects));
      }
    }

    if (!changedExisting && additions.isEmpty) {
      _showMessage('所选区域未产生可更新的高亮。');
      return;
    }
    final nextHighlights = [...additions, ...retained];
    final autoNotes = [
      for (final highlight in additions)
        _createNoteForHighlight(highlight, text: ''),
    ];
    var notesChanged = false;
    setState(() {
      _highlights = nextHighlights;
      final prunedNotes = _notesPrunedForHighlights(_notes, nextHighlights);
      final existingNoteIds = {for (final note in prunedNotes) note.id};
      final nextNotes = [
        for (final note in autoNotes)
          if (!existingNoteIds.contains(note.id)) note,
        ...prunedNotes,
      ]..sort(PageNote.compareByPosition);
      notesChanged = !_noteListsEqual(_notes, nextNotes);
      _notes = nextNotes;
    });
    await _saveHighlights();
    if (notesChanged) {
      await _saveNotes();
    }
    _showMessage(additions.isEmpty ? '已取消高亮' : '已更新高亮');
  }

  List<PageNote> _notesPrunedForHighlights(
    List<PageNote> notes,
    List<TextHighlight> highlights,
  ) {
    final highlightsById = {
      for (final highlight in highlights) highlight.id: highlight,
    };
    final next = [
      for (final note in notes)
        if (note.highlightId == null)
          note
        else if (highlightsById.containsKey(note.highlightId) &&
            !_isUneditedAutoHighlightNote(
              note,
              highlightsById[note.highlightId]!,
            ))
          note.copyWith(
            colorValue: highlightsById[note.highlightId]!.colorValue,
          ),
    ];
    return next..sort(PageNote.compareByPosition);
  }

  bool _isUneditedAutoHighlightNote(PageNote note, TextHighlight highlight) {
    final updatedAt = note.updatedAt ?? note.createdAt;
    return note.highlightId != null &&
        note.text.trim() == highlight.text.trim() &&
        updatedAt.isAtSameMomentAs(note.createdAt);
  }

  bool _noteListsEqual(List<PageNote> first, List<PageNote> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];
      if (a.id != b.id ||
          a.page != b.page ||
          a.text != b.text ||
          a.x != b.x ||
          a.y != b.y ||
          a.highlightId != b.highlightId ||
          a.colorValue != b.colorValue ||
          a.createdAt != b.createdAt ||
          a.updatedAt != b.updatedAt) {
        return false;
      }
    }
    return true;
  }

  List<HighlightRect> _subtractHighlightRects(
    HighlightRect source,
    List<HighlightRect> cutters,
  ) {
    var parts = <HighlightRect>[source];
    for (final cutter in cutters) {
      parts = [
        for (final part in parts) ..._subtractHighlightRect(part, cutter),
      ];
      if (parts.isEmpty) {
        break;
      }
    }
    return parts;
  }

  List<HighlightRect> _subtractHighlightRect(
    HighlightRect source,
    HighlightRect cutter,
  ) {
    if (!_rectsOverlap(source, cutter)) {
      return [source];
    }

    final left = source.left > cutter.left ? source.left : cutter.left;
    final top = source.top > cutter.top ? source.top : cutter.top;
    final right = source.right < cutter.right ? source.right : cutter.right;
    final bottom = source.bottom < cutter.bottom
        ? source.bottom
        : cutter.bottom;
    const minExtent = 0.5;
    final parts = <HighlightRect>[];

    void addPart(double l, double t, double r, double b) {
      if (r - l > minExtent && b - t > minExtent) {
        parts.add(HighlightRect(left: l, top: t, right: r, bottom: b));
      }
    }

    addPart(source.left, source.top, source.right, top);
    addPart(source.left, bottom, source.right, source.bottom);
    addPart(source.left, top, left, bottom);
    addPart(right, top, source.right, bottom);
    return parts;
  }

  bool _rectsOverlap(HighlightRect a, HighlightRect b) {
    const epsilon = 0.5;
    return a.left < b.right - epsilon &&
        a.right > b.left + epsilon &&
        a.top < b.bottom - epsilon &&
        a.bottom > b.top + epsilon;
  }

  bool _highlightRectListsEqual(
    List<HighlightRect> first,
    List<HighlightRect> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];
      if (a.left != b.left ||
          a.top != b.top ||
          a.right != b.right ||
          a.bottom != b.bottom) {
        return false;
      }
    }
    return true;
  }

  Future<void> _deleteNote(PageNote note, {bool showMessage = false}) async {
    final highlightId = note.highlightId;
    final removesHighlight =
        highlightId != null &&
        _highlights.any((highlight) => highlight.id == highlightId);
    setState(() {
      _notes = _notes.where((item) => item.id != note.id).toList();
      if (_selectedNoteId == note.id) {
        _selectedNoteId = null;
      }
      if (highlightId != null) {
        _highlights = [
          for (final highlight in _highlights)
            if (highlight.id != highlightId) highlight,
        ];
      }
    });
    await _saveNotes();
    if (removesHighlight) {
      await _saveHighlights();
    }
    if (showMessage) {
      _showMessage('已删除笔记');
    }
  }

  PageExportOptions get _quickExportOptions {
    return PageExportOptions(
      resolution: _settings.quickExportResolution,
      format: _settings.quickExportFormat,
      namePattern: _settings.quickExportNamePattern,
      folder: _settings.quickExportFolder,
    );
  }

  Future<void> _quickExportPage(int pageNumber) async {
    await _exportPageWithOptions(
      pageNumber: pageNumber,
      options: _quickExportOptions,
      quick: true,
    );
  }

  Future<void> _exportPage(int pageNumber) async {
    final options = await showDialog<PageExportOptions>(
      context: context,
      builder: (context) {
        return PageExportDialog(
          pageNumber: pageNumber,
          initialOptions: _quickExportOptions,
        );
      },
    );
    if (options == null) {
      return;
    }
    await _exportPageWithOptions(
      pageNumber: pageNumber,
      options: options,
      quick: false,
    );
  }

  Future<void> _exportPageWithOptions({
    required int pageNumber,
    required PageExportOptions options,
    required bool quick,
  }) async {
    final document = _document;
    if (document == null ||
        pageNumber < 1 ||
        pageNumber > document.pages.length) {
      _showMessage('请先打开一个可导出的 PDF 页面。');
      return;
    }

    setState(() => _status = '正在导出第 $pageNumber 页');
    try {
      final bytes = await _renderPageImageBytes(
        pageNumber: pageNumber,
        resolution: options.resolution,
        format: options.format,
      );
      final fileName = _buildExportFileName(
        pageNumber: pageNumber,
        format: options.format,
        pattern: options.namePattern,
      );

      final folder = options.folder?.trim();
      String? savedPath;
      if (folder != null && folder.isNotEmpty && supportsDirectFileSave) {
        savedPath = await saveBytesToFolder(
          bytes: bytes,
          folder: folder,
          fileName: fileName,
        );
      } else {
        savedPath = await FilePicker.saveFile(
          dialogTitle: quick ? '快速导出页面' : '导出页面',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [options.format.extension],
          bytes: bytes,
          lockParentWindow: true,
        );
      }

      if (!mounted) {
        return;
      }
      if (savedPath == null) {
        _showMessage('已取消导出。');
      } else {
        _showMessage('已导出：$savedPath');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('导出失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _status = '${_document?.pages.length ?? 0} 页');
      }
    }
  }

  Future<Uint8List> _renderPageImageBytes({
    required int pageNumber,
    required int resolution,
    required ExportImageFormat format,
  }) async {
    final document = _document;
    if (document == null) {
      throw StateError('PDF 文档尚未准备好。');
    }

    final page = await document.pages[pageNumber - 1].ensureLoaded();
    final scale = normalizeExportImageDpi(resolution) / 72.0;
    final width = math.max(1, (page.width * scale).round());
    final height = math.max(1, (page.height * scale).round());
    final rendered = await page.render(
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: 0xffffffff,
    );
    if (rendered == null) {
      throw StateError('页面渲染失败。');
    }

    try {
      final image = image_lib.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: rendered.pixels.buffer,
        bytesOffset: rendered.pixels.offsetInBytes,
        numChannels: 4,
        order: image_lib.ChannelOrder.bgra,
      );
      return encodeExportImage(
        image: image,
        format: format,
        resolution: resolution,
      );
    } finally {
      rendered.dispose();
    }
  }

  String _buildExportFileName({
    required int pageNumber,
    required ExportImageFormat format,
    required String pattern,
  }) {
    final sourceName = _source?.name.trim();
    final documentName = sourceName == null || sourceName.isEmpty
        ? 'document'
        : p.basenameWithoutExtension(sourceName);
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final page = pageNumber.toString();
    var name = (pattern.trim().isEmpty ? '{document}_P{page}' : pattern)
        .replaceAll('{document}', documentName)
        .replaceAll('{page}', page)
        .replaceAll('{page2}', pageNumber.toString().padLeft(2, '0'))
        .replaceAll('{page3}', pageNumber.toString().padLeft(3, '0'))
        .replaceAll('{date}', date);
    name = _sanitizeFileName(name);
    if (name.isEmpty) {
      name = '${_sanitizeFileName(documentName)}_P$page';
    }
    final extension = '.${format.extension}';
    return name.toLowerCase().endsWith(extension) ? name : '$name$extension';
  }

  String _sanitizeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showMessage(String text) {
    _messageTimer?.cancel();
    _messageEntry?.remove();

    final overlay = Overlay.of(context);
    final fallbackWidth = MediaQuery.sizeOf(context).width;
    var left = 0.0;
    var top = 86.0;
    var width = fallbackWidth;
    final stageContext = _stageKey.currentContext;
    final stageBox = stageContext?.findRenderObject() as RenderBox?;
    if (stageBox != null && stageBox.hasSize) {
      final origin = stageBox.localToGlobal(Offset.zero);
      left = origin.dx;
      top = origin.dy + 16;
      width = stageBox.size.width;
    }

    _messageEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          top: top,
          width: width,
          child: IgnorePointer(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_messageEntry!);
    _messageTimer = Timer(const Duration(milliseconds: 1800), () {
      _messageEntry?.remove();
      _messageEntry = null;
    });
  }

  void _handleShortcut(ReaderShortcutAction action) {
    switch (action) {
      case ReaderShortcutAction.openFile:
        unawaited(_pickPdf());
        break;
      case ReaderShortcutAction.search:
        _focusSearch();
        break;
      case ReaderShortcutAction.clearSearch:
        _handleClearSearchOrHidePanel();
        break;
      case ReaderShortcutAction.openRecentFiles:
        _openTabsMenu();
        break;
      case ReaderShortcutAction.selectHighlightColor:
        _openHighlightColorMenu();
        break;
      case ReaderShortcutAction.openLibraryPanel:
        _openShortcutPanel(PanelMode.library, selectFirstRecent: true);
        break;
      case ReaderShortcutAction.openPagesPanel:
        _openShortcutPanel(PanelMode.pages);
        break;
      case ReaderShortcutAction.toggleThumbnailLayout:
        _toggleThumbnailLayout();
        break;
      case ReaderShortcutAction.openOutlinePanel:
        _openShortcutPanel(PanelMode.outline);
        break;
      case ReaderShortcutAction.openNotesPanel:
        _openShortcutPanel(PanelMode.notes);
        break;
      case ReaderShortcutAction.openSettings:
        unawaited(_showSettings());
        break;
      case ReaderShortcutAction.addNote:
        unawaited(_addNote());
        break;
      case ReaderShortcutAction.previousPage:
        _goToPage(_currentPage - 1);
        break;
      case ReaderShortcutAction.nextPage:
        _goToPage(_currentPage + 1);
        break;
      case ReaderShortcutAction.fitWidth:
        if (_viewerController.isReady) {
          _fitWidth();
        }
        break;
      case ReaderShortcutAction.fitPage:
        if (_viewerController.isReady) {
          _fitPage();
        }
        break;
      case ReaderShortcutAction.toggleTheme:
        _setNightMode(!_nightMode);
        break;
    }
  }

  void _handleClearSearchOrHidePanel() {
    if (_panelMode == PanelMode.search && _clearSearchResults()) {
      return;
    }
    _hideActivePanel();
  }

  void _openShortcutPanel(PanelMode mode, {bool selectFirstRecent = false}) {
    final compact = _isCompactLayout();
    _searchFocusNode.unfocus();
    setState(() {
      _panelMode = mode;
      _compactPanelOpen = compact;
      if (!compact) {
        _panelCollapsed = false;
      }
      if (selectFirstRecent) {
        _selectedRecentIndex = _clampedRecentIndex(0, _recent);
      }
    });
    if (!compact || mode == PanelMode.search) {
      _fitWidthNextFrame();
    }
  }

  bool _hideActivePanel() {
    if (_isCompactLayout()) {
      if (!_compactPanelOpen) {
        return false;
      }
      setState(() => _compactPanelOpen = false);
      return true;
    }
    if (_panelCollapsed) {
      return false;
    }
    setState(() => _panelCollapsed = true);
    _fitWidthNextFrame();
    return true;
  }

  void _toggleThumbnailLayout() {
    _setThumbnailColumns(!_twoColumnThumbnails);
  }

  void _openTabsMenu() {
    setState(() {
      _openTabsMenuTrigger++;
      _openTabsMenuOpen = true;
    });
  }

  void _closeTabsMenu() {
    setState(() {
      _closeTabsMenuTrigger++;
      _openTabsMenuOpen = false;
    });
  }

  void _openRecentFileFromMenu(int index) {
    if (!_openTabsMenuOpen || index < 0 || index >= _sessionTabs.length) {
      return;
    }
    final tab = _sessionTabs[index];
    _closeTabsMenu();
    unawaited(_openSessionTab(tab));
  }

  void _openHighlightColorMenu() {
    setState(() => _highlightColorMenuTrigger++);
  }

  void _focusSearch() {
    if (_source == null) {
      _showMessage('请先打开一个 PDF。');
      return;
    }
    _showSearchPanel();
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    _fitWidthNextFrame();
  }

  bool _clearSearchResults() {
    if (!_searchResultsActive) {
      return false;
    }
    _textSearcher?.resetTextSearch();
    _searchResultsActive = false;
    return true;
  }

  Widget _buildToolbar() {
    return ReaderToolbar(
      source: _source,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      textSearcher: _textSearcher,
      viewerController: _viewerController,
      shortcutBindings: _settings.shortcutBindings,
      sessionTabs: _sessionTabs,
      currentSourceId: _source?.id,
      openTabsMenuTrigger: _openTabsMenuTrigger,
      closeTabsMenuTrigger: _closeTabsMenuTrigger,
      onOpenTabsMenuChanged: (open) => _openTabsMenuOpen = open,
      onOpen: _pickPdf,
      onOpenTab: _openSessionTab,
      onPdfContextMenu: _showPdfContextMenu,
      onSearch: _runSearch,
      onNextSearchMatch: () {
        unawaited(_goToNextSearchMatch());
      },
      onPreviousSearchMatch: () {
        unawaited(_goToPreviousSearchMatch());
      },
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      onFitWidth: _fitWidth,
      onFitPage: _fitPage,
      highlightColor: _highlightColor,
      highlightColorMenuTrigger: _highlightColorMenuTrigger,
      onHighlightColorMenuChanged: (open) => _highlightColorMenuOpen = open,
      onHighlightColorChanged: (color) {
        setState(() => _highlightColor = color);
      },
      showWindowControls: _usesCustomWindowChrome,
      windowMaximized: _windowMaximized,
      onWindowDrag: _startWindowDrag,
      onWindowMinimize: _minimizeWindow,
      onWindowMaximizeRestore: _toggleMaximizeWindow,
      onWindowClose: _closeWindow,
    );
  }

  Widget _buildReaderPanel({required bool compact, bool overlay = false}) {
    return ReaderPanel(
      mode: _panelMode,
      document: _document,
      outline: _outline,
      notes: List<PageNote>.of(_notes)..sort(PageNote.compareByPosition),
      highlights: List<TextHighlight>.of(_highlights),
      selectedNoteId: _selectedNoteId,
      viewportPreviews: _viewportPreviews,
      twoColumnThumbnails: _twoColumnThumbnails,
      thumbnailAnchorPage: _thumbnailAnchorPage,
      currentPage: _currentPage,
      pageCount: _document?.pages.length ?? 0,
      jumpController: _jumpPageController,
      recent: _recent,
      selectedRecentIndex: _selectedRecentIndex,
      loadingLibrary: _loadingLibrary,
      textSearcher: _textSearcher,
      shortcutBindings: _settings.shortcutBindings,
      onOpen: _pickPdf,
      onOpenRecent: _openRecent,
      onDeleteRecent: _deleteRecent,
      onClearRecent: _clearRecent,
      onPdfContextMenu: _showPdfContextMenu,
      onPdf2zhAction: (source, action) {
        unawaited(_runPdf2zhAction(source, action));
      },
      onGoToPage: (page) {
        _goToPage(page);
        if (overlay) {
          setState(() => _compactPanelOpen = false);
        }
      },
      onGoToNote: (note) {
        _selectNote(note);
      },
      onEditNote: (note) {
        unawaited(_editNote(note));
      },
      onUpdateNoteText: (note, text) {
        unawaited(_updateNoteTextInline(note, text));
      },
      onGoToNextNote: () => _goToAdjacentNote(1),
      onGoToPreviousNote: () => _goToAdjacentNote(-1),
      onGoToOutline: (dest) {
        _viewerController.goToDest(dest);
        if (overlay) {
          setState(() => _compactPanelOpen = false);
        }
      },
      onGoToSearchMatch: (match) {
        unawaited(_goToSearchMatchIndex(match));
        if (overlay) {
          setState(() => _compactPanelOpen = false);
        }
      },
      onDeleteNote: _deleteNote,
      onAddNote: _addNote,
      onThumbnailLayoutChanged: _setThumbnailColumns,
      onThumbnailAnchorPageChanged: _setThumbnailAnchorPage,
      onJumpSubmitted: _jumpFromField,
      onPreviousPage: () => _goToPage(_currentPage - 1),
      onNextPage: () => _goToPage(_currentPage + 1),
      onQuickExportPage: _quickExportPage,
      onExportPage: _exportPage,
      translationSourceText: _translationSourceText,
      translationResult: _translationResult,
      onCollapse: compact
          ? () => setState(() => _compactPanelOpen = false)
          : _collapsePanel,
    );
  }

  Widget _buildReaderStack({
    required bool compact,
    required int systemResolution,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: ReaderStage(
            key: _stageKey,
            source: _source,
            status: _status,
            nightMode: _nightMode,
            settings: _settings,
            systemResolution: systemResolution,
            controller: _viewerController,
            textSearcher: _textSearcher,
            notes: _notes,
            highlights: _highlights,
            selectedNoteId: _selectedNoteId,
            onOpen: _pickPdf,
            onAddHighlight: _addHighlightFromSelection,
            onEditNote: _editNote,
            onSelectNote: _selectNote,
            onClearNoteSelection: _clearSelectedNote,
            onMoveNote: _moveNote,
            onEditHighlightNote: (highlight, anchor) =>
                _editHighlightNote(highlight, anchor: anchor),
            onTranslateSelection: _translateSelectionText,
            onViewerReady: _onViewerReady,
            onPageChanged: _onPageChanged,
            passwordProvider: _askPassword,
          ),
        ),
        if (compact && _compactPanelOpen)
          Positioned.fill(
            child: Row(
              children: [
                Material(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  color: AppColors.panel,
                  child: _buildReaderPanel(compact: true, overlay: true),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _compactPanelOpen = false),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setTheme(nightMode: _nightMode, accentChoice: _settings.accent);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth <
            ReaderToolbarMetrics.collapseToolbarExtrasBelow;
        final systemResolution = _currentSystemResolution();
        final baseTheme = Theme.of(context);
        final themed = baseTheme.copyWith(
          scaffoldBackgroundColor: AppColors.canvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accent,
            brightness: _nightMode ? Brightness.dark : Brightness.light,
            surface: AppColors.surface,
          ),
          textTheme: baseTheme.textTheme.apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          ),
          iconTheme: IconThemeData(color: AppColors.ink),
          textSelectionTheme: TextSelectionThemeData(
            selectionColor: AppColors.selection,
            cursorColor: AppColors.accent,
            selectionHandleColor: AppColors.accent,
          ),
          tooltipTheme: TooltipThemeData(
            waitDuration: const Duration(milliseconds: 450),
            showDuration: const Duration(milliseconds: 2600),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        );
        return Theme(
          data: themed,
          child: MouseRegion(
            onEnter: (_) => _pointerInsideWindow = true,
            onHover: (_) => _pointerInsideWindow = true,
            onExit: (_) => _pointerInsideWindow = false,
            child: Focus(
              autofocus: true,
              child: WindowResizeFrame(
                enabled: _usesCustomWindowChrome && !_windowMaximized,
                onResizeStart: _startWindowResize,
                child: WindowTransitionFrame(
                  trigger: _windowTransitionTrigger,
                  kind: _windowTransitionKind,
                  child: Scaffold(
                    backgroundColor: AppColors.canvas,
                    body: SafeArea(
                      child: Column(
                        children: [
                          _buildToolbar(),
                          Expanded(
                            child: Row(
                              children: [
                                ReaderRail(
                                  selected: _panelMode,
                                  onSelected: (mode) =>
                                      _selectPanel(mode, compact: compact),
                                  shortcutBindings: _settings.shortcutBindings,
                                  hasDocument: _source != null,
                                  nightMode: _nightMode,
                                  onNightModeChanged: _setNightMode,
                                  onSettings: _showSettings,
                                ),
                                if (!compact && !_panelCollapsed)
                                  _buildReaderPanel(compact: false),
                                Expanded(
                                  child: _buildReaderStack(
                                    compact: compact,
                                    systemResolution: systemResolution,
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
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _NoteEditorAction { save, clear, delete }

class _NoteEditorResult {
  const _NoteEditorResult(this.action, this.text);

  final _NoteEditorAction action;
  final String text;
}

class _NoteEditorCard extends StatelessWidget {
  const _NoteEditorCard({
    required this.title,
    required this.page,
    required this.controller,
    required this.hintText,
    required this.color,
    required this.onCancel,
    required this.onClear,
    required this.onDelete,
    required this.onSave,
  });

  final String title;
  final int page;
  final TextEditingController controller;
  final String hintText;
  final Color color;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  Color get _solidColor => color.withValues(alpha: 1);

  void _insertNewline() {
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, '\n'),
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
              child: Row(
                children: [
                  _MiniNoteGlyph(color: _solidColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '页 $page',
                    style: TextStyle(
                      color: AppColors.subtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: onCancel,
                    visualDensity: VisualDensity.compact,
                    iconSize: 17,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.enter): _SaveNoteIntent(),
                  SingleActivator(LogicalKeyboardKey.enter, control: true):
                      _InsertNoteNewlineIntent(),
                  SingleActivator(LogicalKeyboardKey.enter, shift: true):
                      _InsertNoteNewlineIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _SaveNoteIntent: CallbackAction<_SaveNoteIntent>(
                      onInvoke: (_) {
                        onSave();
                        return null;
                      },
                    ),
                    _InsertNoteNewlineIntent:
                        CallbackAction<_InsertNoteNewlineIntent>(
                          onInvoke: (_) {
                            _insertNewline();
                            return null;
                          },
                        ),
                  },
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(color: AppColors.ink, height: 1.35),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: AppColors.subtle,
                        height: 1.35,
                      ),
                      filled: true,
                      fillColor: AppColors.canvas,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.accentLine),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(9),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(
                  children: [
                    TextButton(onPressed: onClear, child: const Text('清空')),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('删除'),
                    ),
                    const Spacer(),
                    FilledButton(onPressed: onSave, child: const Text('保存')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniNoteGlyph extends StatelessWidget {
  const _MiniNoteGlyph({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MiniNoteGlyphPainter(color),
    );
  }
}

class _MiniNoteGlyphPainter extends CustomPainter {
  const _MiniNoteGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = AppColors.noteGlyphStroke.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.07);
    final fill = Paint()
      ..color = color.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;
    final fold = Paint()
      ..color = Color.lerp(
        color,
        AppColors.noteFoldSurface,
        0.56,
      )!.withValues(alpha: 1)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.12, h * 0.08)
      ..lineTo(w * 0.86, h * 0.08)
      ..lineTo(w * 0.86, h * 0.9)
      ..lineTo(w * 0.34, h * 0.9)
      ..lineTo(w * 0.12, h * 0.66)
      ..close();
    final foldPath = Path()
      ..moveTo(w * 0.12, h * 0.66)
      ..lineTo(w * 0.34, h * 0.66)
      ..lineTo(w * 0.34, h * 0.9)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(foldPath, fold);
    canvas.drawPath(path, border);
    canvas.drawLine(
      Offset(w * 0.12, h * 0.66),
      Offset(w * 0.34, h * 0.66),
      border,
    );
    canvas.drawLine(
      Offset(w * 0.34, h * 0.66),
      Offset(w * 0.34, h * 0.9),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniNoteGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SaveNoteIntent extends Intent {
  const _SaveNoteIntent();
}

class _InsertNoteNewlineIntent extends Intent {
  const _InsertNoteNewlineIntent();
}
