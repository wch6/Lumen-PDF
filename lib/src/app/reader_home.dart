import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reader_models.dart';
import '../services/file_saver.dart';
import '../services/reader_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/page_export_dialog.dart';
import '../widgets/reader_panels.dart';
import '../widgets/reader_rail.dart';
import '../widgets/reader_stage.dart';
import '../widgets/reader_toolbar.dart';
import '../widgets/settings_dialog.dart';

class ReaderHome extends StatefulWidget {
  const ReaderHome({this.repositoryFuture, super.key});

  final Future<ReaderRepository>? repositoryFuture;

  @override
  State<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends State<ReaderHome> {
  final _prefs = SharedPreferencesAsync();
  final _viewerController = PdfViewerController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _jumpPageController = TextEditingController(text: '1');
  final _stageKey = GlobalKey();
  late final Future<ReaderRepository> _repositoryFuture;
  static const _windowChromeChannel = MethodChannel('pdf_reader/window_chrome');

  PdfTextSearcher? _textSearcher;
  ReaderRepository? _repository;
  OverlayEntry? _messageEntry;
  Timer? _messageTimer;
  bool? _syncedTitleBarNightMode;

  PdfSource? _source;
  PdfDocument? _document;
  List<PdfOutlineNode> _outline = const [];
  List<PageNote> _notes = const [];
  List<TextHighlight> _highlights = const [];
  final List<List<TextHighlight>> _highlightUndoStack = [];
  final List<List<TextHighlight>> _highlightRedoStack = [];
  List<RecentDocument> _recent = const [];
  List<SessionDocumentTab> _sessionTabs = const [];

  PanelMode _panelMode = PanelMode.library;
  ReaderSettings _settings = const ReaderSettings();
  Color _highlightColor = AppColors.highlightPalette.first;
  int _currentPage = 1;
  bool _loadingLibrary = true;
  bool _nightMode = false;
  bool _windowMaximized = false;
  bool _compactPanelOpen = false;
  bool _panelCollapsed = false;
  bool _twoColumnThumbnails = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _repositoryFuture = widget.repositoryFuture ?? ReaderRepository.open();
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcutKey);
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
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcutKey);
    _messageTimer?.cancel();
    _messageEntry?.remove();
    _disposeTextSearcher();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _jumpPageController.dispose();
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
    final raw = await _prefs.getString(StorageKeys.settings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = ReaderSettings.tryDecode(raw));
  }

  Future<void> _saveSettings() async {
    await _prefs.setString(
      StorageKeys.settings,
      jsonEncode(_settings.toJson()),
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
      _loadingLibrary = false;
    });
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

  Future<void> _openRecent(RecentDocument recent) async {
    await _openSource(
      PdfSource(name: recent.name, path: recent.path, size: recent.size),
      initialPage: recent.page,
    );
  }

  Future<void> _openSessionTab(SessionDocumentTab tab) async {
    await _openSource(tab.source, initialPage: tab.page);
  }

  Future<void> _openSource(PdfSource source, {int initialPage = 1}) async {
    setState(() => _status = '正在读取 PDF 指纹...');
    late final OpenedPdfState opened;
    try {
      opened = await (await _repo()).openSource(
        source,
        initialPage: initialPage,
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
    setState(() {
      _source = resolved;
      _document = null;
      _outline = const [];
      _notes = opened.notes;
      _highlights = opened.highlights;
      _highlightUndoStack.clear();
      _highlightRedoStack.clear();
      _currentPage = initialPage;
      _jumpPageController.text = '$initialPage';
      _status = null;
      _panelMode = PanelMode.pages;
      _compactPanelOpen = false;
      _panelCollapsed = false;
      _recent = opened.recent;
      _sessionTabs = [
        SessionDocumentTab(
          source: resolved,
          page: initialPage,
          openedAt: DateTime.now(),
        ),
        ..._sessionTabs.where((item) => item.source.id != resolved.id),
      ].take(10).toList();
    });

    _searchController.clear();
    _disposeTextSearcher();
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
          ),
        ),
      );
    }
    unawaited(_loadOutline(document));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
    setState(() {
      _currentPage = pageNumber;
      _jumpPageController.text = '$pageNumber';
      _recent = _recent
          .map(
            (item) => item.path == _source?.path
                ? item.copyWith(page: pageNumber, openedAt: DateTime.now())
                : item,
          )
          .toList();
      _sessionTabs = _sessionTabs
          .map(
            (item) => item.source.id == _source?.id
                ? item.copyWith(page: pageNumber)
                : item,
          )
          .toList();
    });
    if (source != null) {
      unawaited(
        _repo().then(
          (repo) => repo.updateReadPosition(
            source,
            page: pageNumber,
            pageCount: _document?.pages.length,
          ),
        ),
      );
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _runSearch(String query) {
    final textSearcher = _textSearcher;
    final trimmed = query.trim();
    if (textSearcher == null || trimmed.isEmpty) {
      return;
    }
    textSearcher.startTextSearch(trimmed, caseInsensitive: true);
    if (trimmed.isNotEmpty) {
      setState(() {
        _panelMode = PanelMode.search;
        _compactPanelOpen = true;
      });
    }
    _fitWidthNextFrame();
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
    setState(() => _twoColumnThumbnails = twoColumn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewerController.isReady) {
        _fitWidth();
      }
    });
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

  bool get _usesCustomWindowChrome =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _invokeWindowChrome(String method) async {
    if (!_usesCustomWindowChrome) {
      return;
    }
    try {
      await _windowChromeChannel.invokeMethod<void>(method);
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

  void _startWindowResize(_WindowResizeEdge edge) {
    if (!_usesCustomWindowChrome || _windowMaximized) {
      return;
    }
    unawaited(_startWindowResizeAsync(edge));
  }

  Future<void> _startWindowResizeAsync(_WindowResizeEdge edge) async {
    try {
      await _windowChromeChannel.invokeMethod<void>('startWindowResize', {
        'edge': edge.name,
      });
      await _refreshWindowMaximized();
    } catch (_) {
      // Older runners keep their existing resize behavior.
    }
  }

  void _minimizeWindow() {
    unawaited(_invokeWindowChrome('minimizeWindow'));
  }

  void _toggleMaximizeWindow() {
    if (!_usesCustomWindowChrome) {
      return;
    }
    unawaited(_toggleMaximizeWindowAsync());
  }

  Future<void> _toggleMaximizeWindowAsync() async {
    try {
      final maximized = await _windowChromeChannel.invokeMethod<bool>(
        'toggleMaximizeWindow',
      );
      if (mounted && maximized != null) {
        setState(() => _windowMaximized = maximized);
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
      final maximized = await _windowChromeChannel.invokeMethod<bool>(
        'isWindowMaximized',
      );
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
      await _windowChromeChannel.invokeMethod<void>('setMinimumWindowSize', {
        'width': ReaderToolbarMetrics.minimumWindowWidth,
        'height': ReaderToolbarMetrics.minimumWindowHeight,
      });
    } catch (_) {
      // Older runners keep their existing minimum window size.
    }
  }

  void _closeWindow() {
    unawaited(_invokeWindowChrome('closeWindow'));
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
      await _windowChromeChannel.invokeMethod<void>('setTitleBarTheme', {
        'dark': _nightMode,
      });
    } catch (_) {
      // Non-Windows builds and older runners simply keep the system title bar.
    }
  }

  Future<void> _showSettings() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return SettingsDialog(
          settings: _settings,
          nightMode: _nightMode,
          onSettingsChanged: (settings) {
            final previous = _settings;
            setState(() => _settings = settings);
            if (_viewerController.isReady &&
                previous.resolutionMode != settings.resolutionMode) {
              _viewerController.invalidate();
            }
            unawaited(_saveSettings());
          },
          onNightModeChanged: _setNightMode,
          onShortcutChanged: _setShortcutBinding,
          onClearCache: _clearSoftwareCache,
        );
      },
    );
  }

  Future<void> _clearSoftwareCache() async {
    await _prefs.clear();
    await (await _repo()).clearUserData();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = const ReaderSettings();
      _recent = const [];
      _notes = const [];
      _highlights = const [];
      _highlightUndoStack.clear();
      _highlightRedoStack.clear();
      _loadingLibrary = false;
    });
    _showMessage('已清除软件缓存，不会删除本地 PDF 文件。');
  }

  void _goToPage(int page) {
    final pageCount = _document?.pages.length ?? 0;
    if (pageCount == 0) {
      return;
    }
    final next = page.clamp(1, pageCount);
    _viewerController.goToPage(pageNumber: next);
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

  void _fitWidth() {
    final pageNumber = _viewerController.pageNumber ?? _currentPage;
    _viewerController.goTo(
      _viewerController.calcMatrixFitWidthForPage(pageNumber: pageNumber),
    );
  }

  void _fitWidthNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewerController.isReady) {
        _fitWidth();
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
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('第 $_currentPage 页笔记'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: '写下这一页的重点、批注或待办'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);

    final noteText = text?.trim();
    if (noteText == null || noteText.isEmpty) {
      return;
    }
    setState(() {
      _notes = [
        PageNote(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          page: _currentPage,
          text: noteText,
          createdAt: DateTime.now(),
        ),
        ..._notes,
      ];
      _panelMode = PanelMode.notes;
    });
    await _saveNotes();
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
    _pushHighlightUndoSnapshot();
    setState(() {
      _highlights = [...additions, ...retained];
    });
    await _saveHighlights();
    _showMessage(additions.isEmpty ? '已取消高亮' : '已更新高亮');
  }

  void _pushHighlightUndoSnapshot() {
    _highlightUndoStack.add(List<TextHighlight>.of(_highlights));
    if (_highlightUndoStack.length > 60) {
      _highlightUndoStack.removeAt(0);
    }
    _highlightRedoStack.clear();
  }

  Future<void> _undoHighlight() async {
    if (_highlightUndoStack.isEmpty) {
      return;
    }
    _highlightRedoStack.add(List<TextHighlight>.of(_highlights));
    final previous = _highlightUndoStack.removeLast();
    setState(() => _highlights = previous);
    await _saveHighlights();
  }

  Future<void> _redoHighlight() async {
    if (_highlightRedoStack.isEmpty) {
      return;
    }
    _highlightUndoStack.add(List<TextHighlight>.of(_highlights));
    final next = _highlightRedoStack.removeLast();
    setState(() => _highlights = next);
    await _saveHighlights();
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

  Future<void> _deleteNote(PageNote note) async {
    setState(
      () => _notes = _notes.where((item) => item.id != note.id).toList(),
    );
    await _saveNotes();
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
    final scale = resolution.clamp(72, 600) / 72.0;
    final width = math.max(1, (page.width * scale).round());
    final height = math.max(1, (page.height * scale).round());
    final rendered = await page.render(
      width: width,
      height: height,
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
      return switch (format) {
        ExportImageFormat.png => image_lib.encodePng(image),
        ExportImageFormat.jpg => image_lib.encodeJpg(image, quality: 95),
      };
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

  Map<ShortcutActivator, Intent> _shortcutActivators() {
    return {
      for (final entry in _settings.shortcutBindings.entries)
        SingleActivator(
          entry.value.logicalKey,
          control: entry.value.control,
          shift: entry.value.shift,
          alt: entry.value.alt,
          meta: entry.value.meta,
        ): _ReaderShortcutIntent(
          entry.key,
        ),
    };
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
        _clearSearchAndReturnToPages();
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
      case ReaderShortcutAction.zoomIn:
        if (_viewerController.isReady) {
          _zoomIn();
        }
        break;
      case ReaderShortcutAction.zoomOut:
        if (_viewerController.isReady) {
          _zoomOut();
        }
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
      case ReaderShortcutAction.undoHighlight:
        unawaited(_undoHighlight());
        break;
      case ReaderShortcutAction.redoHighlight:
        unawaited(_redoHighlight());
        break;
    }
  }

  bool _handleGlobalShortcutKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    final action = _shortcutActionForEvent(event);
    if (action == null) {
      return false;
    }
    _handleShortcut(action);
    return true;
  }

  ReaderShortcutAction? _shortcutActionForEvent(KeyEvent event) {
    for (final entry in _settings.shortcutBindings.entries) {
      if (_matchesShortcut(event, entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  bool _matchesShortcut(KeyEvent event, ReaderShortcutBinding binding) {
    final keyboard = HardwareKeyboard.instance;
    return event.logicalKey == binding.logicalKey &&
        keyboard.isControlPressed == binding.control &&
        keyboard.isShiftPressed == binding.shift &&
        keyboard.isAltPressed == binding.alt &&
        keyboard.isMetaPressed == binding.meta;
  }

  void _focusSearch() {
    if (_source == null) {
      _showMessage('请先打开一个 PDF。');
      return;
    }
    setState(() {
      _panelMode = PanelMode.search;
      _compactPanelOpen = true;
    });
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    _fitWidthNextFrame();
  }

  void _clearSearchAndReturnToPages() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _textSearcher?.resetTextSearch();
    final compact = MediaQuery.sizeOf(context).width < 1040;
    setState(() {
      _panelMode = PanelMode.pages;
      _compactPanelOpen = compact;
    });
    _fitWidthNextFrame();
  }

  Widget _buildToolbar() {
    return ReaderToolbar(
      source: _source,
      currentPage: _currentPage,
      pageCount: _document?.pages.length ?? 0,
      jumpController: _jumpPageController,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      nightMode: _nightMode,
      textSearcher: _textSearcher,
      viewerController: _viewerController,
      sessionTabs: _sessionTabs,
      currentSourceId: _source?.id,
      onOpen: _pickPdf,
      onOpenTab: _openSessionTab,
      onSearch: _runSearch,
      onJumpSubmitted: _jumpFromField,
      onPreviousPage: () => _goToPage(_currentPage - 1),
      onNextPage: () => _goToPage(_currentPage + 1),
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      onFitWidth: _fitWidth,
      onFitPage: _fitPage,
      highlightColor: _highlightColor,
      onHighlightColorChanged: (color) {
        setState(() => _highlightColor = color);
      },
      onAddNote: _addNote,
      onNightModeChanged: _setNightMode,
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
      notes: _notes,
      twoColumnThumbnails: _twoColumnThumbnails,
      recent: _recent,
      loadingLibrary: _loadingLibrary,
      textSearcher: _textSearcher,
      onOpen: _pickPdf,
      onOpenRecent: _openRecent,
      onGoToPage: (page) {
        _goToPage(page);
        if (overlay) {
          setState(() => _compactPanelOpen = false);
        }
      },
      onGoToOutline: (dest) {
        _viewerController.goToDest(dest);
        if (overlay) {
          setState(() => _compactPanelOpen = false);
        }
      },
      onGoToSearchMatch: (match) {
        _textSearcher?.goToMatchOfIndex(match);
        if (overlay) {
          setState(() => _compactPanelOpen = false);
        }
      },
      onDeleteNote: _deleteNote,
      onAddNote: _addNote,
      onThumbnailLayoutChanged: _setThumbnailColumns,
      onQuickExportPage: _quickExportPage,
      onExportPage: _exportPage,
      onCollapse: compact
          ? () => setState(() => _compactPanelOpen = false)
          : _collapsePanel,
    );
  }

  Widget _buildReaderStack({required bool compact}) {
    return Stack(
      children: [
        Positioned.fill(
          child: ReaderStage(
            key: _stageKey,
            source: _source,
            status: _status,
            nightMode: _nightMode,
            settings: _settings,
            controller: _viewerController,
            textSearcher: _textSearcher,
            notes: _notes,
            highlights: _highlights,
            onOpen: _pickPdf,
            onAddHighlight: _addHighlightFromSelection,
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
        final compact = constraints.maxWidth < 1040;
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
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: TextStyle(color: AppColors.surface, fontSize: 12),
          ),
        );
        return Theme(
          data: themed,
          child: Shortcuts(
            shortcuts: _shortcutActivators(),
            child: Actions(
              actions: <Type, Action<Intent>>{
                _ReaderShortcutIntent: CallbackAction<_ReaderShortcutIntent>(
                  onInvoke: (intent) {
                    _handleShortcut(intent.action);
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: _WindowResizeFrame(
                  enabled: _usesCustomWindowChrome && !_windowMaximized,
                  onResizeStart: _startWindowResize,
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
                                  hasDocument: _source != null,
                                  onSettings: _showSettings,
                                ),
                                if (!compact && !_panelCollapsed)
                                  _buildReaderPanel(compact: false),
                                Expanded(
                                  child: _buildReaderStack(compact: compact),
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

enum _WindowResizeEdge {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _WindowResizeFrame extends StatelessWidget {
  const _WindowResizeFrame({
    required this.enabled,
    required this.onResizeStart,
    required this.child,
  });

  static const double _edgeSize = 6;
  static const double _cornerSize = 18;

  final bool enabled;
  final ValueChanged<_WindowResizeEdge> onResizeStart;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled
                    ? AppColors.line.withValues(alpha: 0.9)
                    : Colors.transparent,
              ),
            ),
            child: child,
          ),
        ),
        if (enabled) ..._resizeHandles(),
      ],
    );
  }

  List<Widget> _resizeHandles() {
    return [
      _ResizeHandle(
        edge: _WindowResizeEdge.top,
        cursor: SystemMouseCursors.resizeUpDown,
        onResizeStart: onResizeStart,
        left: _cornerSize,
        right: _cornerSize,
        top: 0,
        height: _edgeSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.bottom,
        cursor: SystemMouseCursors.resizeUpDown,
        onResizeStart: onResizeStart,
        left: _cornerSize,
        right: _cornerSize,
        bottom: 0,
        height: _edgeSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.left,
        cursor: SystemMouseCursors.resizeLeftRight,
        onResizeStart: onResizeStart,
        left: 0,
        top: _cornerSize,
        bottom: _cornerSize,
        width: _edgeSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.right,
        cursor: SystemMouseCursors.resizeLeftRight,
        onResizeStart: onResizeStart,
        right: 0,
        top: _cornerSize,
        bottom: _cornerSize,
        width: _edgeSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.topLeft,
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        onResizeStart: onResizeStart,
        left: 0,
        top: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.topRight,
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        onResizeStart: onResizeStart,
        right: 0,
        top: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.bottomLeft,
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        onResizeStart: onResizeStart,
        left: 0,
        bottom: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
      _ResizeHandle(
        edge: _WindowResizeEdge.bottomRight,
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        onResizeStart: onResizeStart,
        right: 0,
        bottom: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
    ];
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.edge,
    required this.cursor,
    required this.onResizeStart,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
  });

  final _WindowResizeEdge edge;
  final MouseCursor cursor;
  final ValueChanged<_WindowResizeEdge> onResizeStart;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onResizeStart(edge),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ReaderShortcutIntent extends Intent {
  const _ReaderShortcutIntent(this.action);

  final ReaderShortcutAction action;
}
