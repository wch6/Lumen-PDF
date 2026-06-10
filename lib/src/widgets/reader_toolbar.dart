import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfrx/pdfrx.dart';

import '../assets/reader_icon_assets.dart';
import '../models/reader_models.dart';
import '../theme/app_colors.dart';
import 'pdf_first_page_preview.dart';
import 'shortcut_tooltip.dart';

class ReaderToolbarMetrics {
  const ReaderToolbarMetrics._();

  static const double controlHeight = 38;
  static const double highlightSearchGap = 24;
  static const int collapseToolbarExtrasBelow = 968;
  static const int minimumWindowWidth = 720;
  static const int minimumWindowHeight = 640;
}

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    required this.source,
    required this.searchController,
    required this.searchFocusNode,
    required this.textSearcher,
    required this.viewerController,
    required this.shortcutBindings,
    required this.sessionTabs,
    required this.firstPagePreviews,
    required this.currentSourceId,
    required this.selectedTabIndex,
    required this.openTabsMenuTrigger,
    required this.closeTabsMenuTrigger,
    required this.onOpenTabsMenuChanged,
    required this.onOpen,
    required this.onOpenTab,
    required this.onPdfContextMenu,
    required this.onSearch,
    required this.onNextSearchMatch,
    required this.onPreviousSearchMatch,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onFitPage,
    required this.highlightColor,
    required this.highlightColorMenuTrigger,
    required this.onHighlightColorMenuChanged,
    required this.onHighlightColorChanged,
    required this.showWindowControls,
    required this.windowMaximized,
    required this.onWindowDrag,
    required this.onWindowMinimize,
    required this.onWindowMaximizeRestore,
    required this.onWindowClose,
    super.key,
  });

  final PdfSource? source;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final PdfTextSearcher? textSearcher;
  final PdfViewerController viewerController;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;
  final List<SessionDocumentTab> sessionTabs;
  final Map<String, PdfFirstPagePreviewData> firstPagePreviews;
  final String? currentSourceId;
  final int? selectedTabIndex;
  final int openTabsMenuTrigger;
  final int closeTabsMenuTrigger;
  final ValueChanged<bool> onOpenTabsMenuChanged;
  final VoidCallback onOpen;
  final ValueChanged<SessionDocumentTab> onOpenTab;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;
  final ValueChanged<String> onSearch;
  final VoidCallback onNextSearchMatch;
  final VoidCallback onPreviousSearchMatch;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final Color highlightColor;
  final int highlightColorMenuTrigger;
  final ValueChanged<bool> onHighlightColorMenuChanged;
  final ValueChanged<Color> onHighlightColorChanged;
  final bool showWindowControls;
  final bool windowMaximized;
  final VoidCallback onWindowDrag;
  final VoidCallback onWindowMinimize;
  final VoidCallback onWindowMaximizeRestore;
  final VoidCallback onWindowClose;

  ReaderShortcutBinding? _shortcut(ReaderShortcutAction action) {
    return shortcutBindings[action] ?? kDefaultShortcutBindings[action];
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = source != null;

    Widget openButton() {
      return ShortcutTooltip(
        label: '打开 PDF',
        shortcut: _shortcut(ReaderShortcutAction.openFile),
        child: IconButton.filledTonal(
          onPressed: onOpen,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accentSoft,
            foregroundColor: AppColors.accent,
            minimumSize: const Size(
              ReaderToolbarMetrics.controlHeight,
              ReaderToolbarMetrics.controlHeight,
            ),
            fixedSize: const Size(
              ReaderToolbarMetrics.controlHeight,
              ReaderToolbarMetrics.controlHeight,
            ),
            maximumSize: const Size(
              ReaderToolbarMetrics.controlHeight,
              ReaderToolbarMetrics.controlHeight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(Icons.folder_open_rounded),
        ),
      );
    }

    Widget windowControls() {
      if (!showWindowControls) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WindowChromeButton(
            tooltip: '最小化',
            icon: Icons.remove_rounded,
            onPressed: onWindowMinimize,
          ),
          WindowChromeButton(
            tooltip: windowMaximized ? '还原窗口' : '最大化',
            icon: windowMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onPressed: onWindowMaximizeRestore,
          ),
          WindowChromeButton(
            tooltip: '关闭',
            icon: Icons.close_rounded,
            onPressed: onWindowClose,
            closeButton: true,
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showFileName =
              constraints.maxWidth >=
              ReaderToolbarMetrics.collapseToolbarExtrasBelow;
          final dense = !showFileName;
          final gap = dense ? 4.0 : 8.0;

          return SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      7,
                      7,
                      showWindowControls ? gap : (dense ? 8 : 12),
                      7,
                    ),
                    child: Row(
                      children: [
                        openButton(),
                        SizedBox(width: gap),
                        if (showFileName) ...[
                          CurrentFileNamePill(
                            source: source,
                            width: 220,
                            onPdfContextMenu: onPdfContextMenu,
                          ),
                          SizedBox(width: gap),
                        ],
                        OpenTabsButton(
                          tabs: sessionTabs,
                          firstPagePreviews: firstPagePreviews,
                          currentSourceId: currentSourceId,
                          selectedIndex: selectedTabIndex,
                          openMenuTrigger: openTabsMenuTrigger,
                          closeMenuTrigger: closeTabsMenuTrigger,
                          shortcut: _shortcut(
                            ReaderShortcutAction.openRecentFiles,
                          ),
                          onOpenChanged: onOpenTabsMenuChanged,
                          onSelected: onOpenTab,
                          onPdfContextMenu: onPdfContextMenu,
                        ),
                        SizedBox(width: gap),
                        ZoomControls(
                          dense: dense,
                          enabled: hasDocument,
                          viewerController: viewerController,
                          onZoomIn: onZoomIn,
                          onZoomOut: onZoomOut,
                          onFitWidth: onFitWidth,
                          onFitPage: onFitPage,
                          fitWidthShortcut: _shortcut(
                            ReaderShortcutAction.fitWidth,
                          ),
                          fitPageShortcut: _shortcut(
                            ReaderShortcutAction.fitPage,
                          ),
                        ),
                        SizedBox(width: gap),
                        HighlightColorButton(
                          selectedColor: highlightColor,
                          openMenuTrigger: highlightColorMenuTrigger,
                          shortcut: _shortcut(
                            ReaderShortcutAction.selectHighlightColor,
                          ),
                          onOpenChanged: onHighlightColorMenuChanged,
                          onSelected: onHighlightColorChanged,
                        ),
                        Expanded(
                          child: WindowDragRegion(
                            onDrag: onWindowDrag,
                            onDoubleTap: onWindowMaximizeRestore,
                          ),
                        ),
                        SizedBox(
                          width: ReaderToolbarMetrics.highlightSearchGap,
                          child: showWindowControls
                              ? WindowDragRegion(
                                  onDrag: onWindowDrag,
                                  onDoubleTap: onWindowMaximizeRestore,
                                )
                              : null,
                        ),
                        SearchBox(
                          dense: dense,
                          enabled: hasDocument,
                          controller: searchController,
                          focusNode: searchFocusNode,
                          textSearcher: textSearcher,
                          onSubmitted: onSearch,
                          onNextMatch: onNextSearchMatch,
                          onPreviousMatch: onPreviousSearchMatch,
                        ),
                      ],
                    ),
                  ),
                ),
                if (showWindowControls) windowControls(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CurrentFileNamePill extends StatelessWidget {
  const CurrentFileNamePill({
    required this.source,
    required this.width,
    required this.onPdfContextMenu,
    super.key,
  });

  final PdfSource? source;
  final double width;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;

  @override
  Widget build(BuildContext context) {
    final name = source?.name ?? '未打开 PDF';
    final path = source?.path ?? name;
    final active = source != null;
    return Tooltip(
      message: path,
      child: GestureDetector(
        onSecondaryTapDown: active
            ? (details) => onPdfContextMenu(source!, details.globalPosition)
            : null,
        child: Container(
          width: width,
          height: ReaderToolbarMetrics.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: active ? AppColors.accentSoft : AppColors.toolbarItem,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.accent : AppColors.subtle,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class OpenTabsButton extends StatefulWidget {
  const OpenTabsButton({
    required this.tabs,
    required this.firstPagePreviews,
    required this.currentSourceId,
    required this.selectedIndex,
    required this.openMenuTrigger,
    required this.closeMenuTrigger,
    required this.shortcut,
    required this.onOpenChanged,
    required this.onSelected,
    required this.onPdfContextMenu,
    super.key,
  });

  final List<SessionDocumentTab> tabs;
  final Map<String, PdfFirstPagePreviewData> firstPagePreviews;
  final String? currentSourceId;
  final int? selectedIndex;
  final int openMenuTrigger;
  final int closeMenuTrigger;
  final ReaderShortcutBinding? shortcut;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<SessionDocumentTab> onSelected;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;

  @override
  State<OpenTabsButton> createState() => _OpenTabsButtonState();
}

class _OpenTabsButtonState extends State<OpenTabsButton> {
  final _menuController = MenuController();

  @override
  void didUpdateWidget(covariant OpenTabsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openMenuTrigger != widget.openMenuTrigger) {
      _menuController.open();
    }
    if (oldWidget.closeMenuTrigger != widget.closeMenuTrigger) {
      _menuController.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final availableMenuWidth = math.max(284.0, windowSize.width - 32);
    final desiredMenuWidth = math.min(
      560.0,
      math.max(460.0, windowSize.width * 0.5),
    );
    final menuWidth = math.min(availableMenuWidth, desiredMenuWidth);
    final menuMaxHeight = math.max(360.0, windowSize.height - 32);
    return MenuAnchor(
      controller: _menuController,
      onOpen: () => widget.onOpenChanged(true),
      onClose: () => widget.onOpenChanged(false),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        elevation: const WidgetStatePropertyAll(10),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: menuWidth,
            maxWidth: menuWidth,
            maxHeight: menuMaxHeight,
          ),
          child: _OpenTabsMenu(
            tabs: widget.tabs,
            firstPagePreviews: widget.firstPagePreviews,
            currentSourceId: widget.currentSourceId,
            selectedIndex: widget.selectedIndex,
            onSelected: (tab) {
              widget.onSelected(tab);
              _menuController.close();
            },
            onPdfContextMenu: widget.onPdfContextMenu,
          ),
        ),
      ],
      builder: (context, controller, _) {
        return ShortcutTooltip(
          label: '最近文件',
          shortcut: widget.shortcut,
          child: IconButton.filledTonal(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentSoft,
              foregroundColor: AppColors.accent,
              minimumSize: const Size(
                ReaderToolbarMetrics.controlHeight,
                ReaderToolbarMetrics.controlHeight,
              ),
              fixedSize: const Size(
                ReaderToolbarMetrics.controlHeight,
                ReaderToolbarMetrics.controlHeight,
              ),
              maximumSize: const Size(
                ReaderToolbarMetrics.controlHeight,
                ReaderToolbarMetrics.controlHeight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        );
      },
    );
  }
}

class _OpenTabsMenu extends StatelessWidget {
  const _OpenTabsMenu({
    required this.tabs,
    required this.firstPagePreviews,
    required this.currentSourceId,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPdfContextMenu,
  });

  final List<SessionDocumentTab> tabs;
  final Map<String, PdfFirstPagePreviewData> firstPagePreviews;
  final String? currentSourceId;
  final int? selectedIndex;
  final ValueChanged<SessionDocumentTab> onSelected;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final tooltipMaxWidth = windowSize.width * 0.5;
    final listMaxHeight = math.min(
      math.max(260.0, windowSize.height - 140),
      tabs.length * 80.0 + math.max(0, tabs.length - 1) * 8.0,
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近打开的文件',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (tabs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: AppColors.subtle),
                    const SizedBox(width: 12),
                    Text(
                      '本次还没有打开文件',
                      style: TextStyle(
                        color: AppColors.subtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMaxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 8,
                    color: AppColors.line.withValues(alpha: 0.65),
                  ),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    return Tooltip(
                      message: tab.tooltipPath,
                      constraints: BoxConstraints(maxWidth: tooltipMaxWidth),
                      child: _OpenTabTile(
                        tab: tab,
                        preview: firstPagePreviews[tab.source.id],
                        shortcutIndex: index + 1,
                        selected:
                            selectedIndex == index ||
                            (selectedIndex == null &&
                                tab.source.id == currentSourceId),
                        current: tab.source.id == currentSourceId,
                        onTap: () => onSelected(tab),
                        onPdfContextMenu: onPdfContextMenu,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenTabTile extends StatelessWidget {
  const _OpenTabTile({
    required this.tab,
    required this.preview,
    required this.shortcutIndex,
    required this.selected,
    required this.current,
    required this.onTap,
    required this.onPdfContextMenu,
  });

  final SessionDocumentTab tab;
  final PdfFirstPagePreviewData? preview;
  final int shortcutIndex;
  final bool selected;
  final bool current;
  final VoidCallback onTap;
  final void Function(PdfSource source, Offset position) onPdfContextMenu;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: current ? null : onTap,
      onSecondaryTapDown: (details) =>
          onPdfContextMenu(tab.source, details.globalPosition),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            PdfFirstPagePreview(
              preview: preview,
              width: 56,
              height: 68,
              borderRadius: 7,
              padding: 3,
              backgroundColor: selected
                  ? AppColors.surface
                  : AppColors.toolbarItem,
              borderColor: selected ? AppColors.accentLine : AppColors.line,
              iconColor: selected ? AppColors.accent : AppColors.subtle,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tab.source.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${tab.page} 页 | ${tab.source.prettySize}',
                    style: TextStyle(
                      color: AppColors.subtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ctrl+$shortcutIndex',
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.subtle,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, color: AppColors.accent, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class WindowDragRegion extends StatelessWidget {
  const WindowDragRegion({required this.onDrag, this.onDoubleTap, super.key});

  final VoidCallback onDrag;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => onDrag(),
      onDoubleTap: onDoubleTap,
      child: const SizedBox.expand(),
    );
  }
}

class WindowChromeButton extends StatelessWidget {
  const WindowChromeButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.closeButton = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool closeButton;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 52),
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          fixedSize: const WidgetStatePropertyAll(Size(48, 52)),
          maximumSize: const WidgetStatePropertyAll(Size(48, 52)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final hovered = states.contains(WidgetState.hovered);
            final pressed = states.contains(WidgetState.pressed);
            if (closeButton && (hovered || pressed)) {
              return const Color(0xFFE81123);
            }
            if (pressed) {
              return AppColors.ink.withValues(
                alpha: AppColors.isNightMode ? 0.16 : 0.12,
              );
            }
            if (hovered) {
              return AppColors.ink.withValues(
                alpha: AppColors.isNightMode ? 0.12 : 0.08,
              );
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (closeButton &&
                (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed))) {
              return Colors.white;
            }
            return AppColors.ink;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class HighlightColorButton extends StatefulWidget {
  const HighlightColorButton({
    required this.selectedColor,
    required this.openMenuTrigger,
    required this.shortcut,
    required this.onOpenChanged,
    required this.onSelected,
    super.key,
  });

  final Color selectedColor;
  final int openMenuTrigger;
  final ReaderShortcutBinding? shortcut;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<Color> onSelected;

  @override
  State<HighlightColorButton> createState() => _HighlightColorButtonState();
}

class _HighlightColorButtonState extends State<HighlightColorButton> {
  static const int _columns = 5;

  final _menuController = MenuController();
  final _focusNode = FocusNode();
  int _highlightedIndex = 0;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _highlightedIndex = _selectedColorIndex();
  }

  @override
  void didUpdateWidget(covariant HighlightColorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor.toARGB32() != widget.selectedColor.toARGB32() &&
        !_menuOpen) {
      _highlightedIndex = _selectedColorIndex();
    }
    if (oldWidget.openMenuTrigger != widget.openMenuTrigger) {
      _openMenu();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  int _selectedColorIndex() {
    final selected = widget.selectedColor.toARGB32();
    final index = AppColors.highlightPalette.indexWhere(
      (color) => color.toARGB32() == selected,
    );
    return index < 0 ? 0 : index;
  }

  int _clampColorIndex(int index) {
    return index.clamp(0, AppColors.highlightPalette.length - 1).toInt();
  }

  void _openMenu() {
    setState(() {
      _menuOpen = true;
      _highlightedIndex = _selectedColorIndex();
    });
    _menuController.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _closeMenu() {
    _menuController.close();
  }

  void _commitHighlightedColor() {
    final colors = AppColors.highlightPalette;
    if (_highlightedIndex < 0 || _highlightedIndex >= colors.length) {
      return;
    }
    widget.onSelected(colors[_highlightedIndex]);
    _closeMenu();
  }

  KeyEventResult _handleColorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    int? nextIndex;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      nextIndex = _clampColorIndex(_highlightedIndex + 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      nextIndex = _clampColorIndex(_highlightedIndex - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      nextIndex = _clampColorIndex(_highlightedIndex + _columns);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      nextIndex = _clampColorIndex(_highlightedIndex - _columns);
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _commitHighlightedColor();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeMenu();
      return KeyEventResult.handled;
    }

    if (nextIndex != null) {
      setState(() => _highlightedIndex = nextIndex!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      onOpen: () {
        widget.onOpenChanged(true);
        setState(() {
          _menuOpen = true;
          _highlightedIndex = _selectedColorIndex();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _focusNode.requestFocus();
          }
        });
      },
      onClose: () {
        widget.onOpenChanged(false);
        if (mounted) {
          setState(() {
            _menuOpen = false;
            _highlightedIndex = _selectedColorIndex();
          });
        }
      },
      menuChildren: [
        Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleColorKey,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: 178,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (
                    var index = 0;
                    index < AppColors.highlightPalette.length;
                    index++
                  )
                    _HighlightSwatch(
                      color: AppColors.highlightPalette[index],
                      selected: index == _highlightedIndex,
                      committed:
                          AppColors.highlightPalette[index].toARGB32() ==
                          widget.selectedColor.toARGB32(),
                      onTap: () {
                        widget.onSelected(AppColors.highlightPalette[index]);
                        _menuController.close();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        final solidColor = widget.selectedColor.withValues(alpha: 1);
        return ShortcutTooltip(
          label: '高亮颜色',
          shortcut: widget.shortcut,
          child: InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                _openMenu();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: ReaderToolbarMetrics.controlHeight,
              height: ReaderToolbarMetrics.controlHeight,
              child: Center(
                child: Container(
                  width: ReaderToolbarMetrics.controlHeight - 4,
                  height: ReaderToolbarMetrics.controlHeight - 4,
                  decoration: BoxDecoration(
                    color: solidColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent, width: 3),
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

class _HighlightSwatch extends StatelessWidget {
  const _HighlightSwatch({
    required this.color,
    required this.selected,
    required this.committed,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool committed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final solidColor = color.withValues(alpha: 1);
    return Tooltip(
      message: '高亮颜色',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : solidColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: committed
              ? Icon(Icons.check_rounded, size: 17, color: AppColors.ink)
              : null,
        ),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.dense,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.textSearcher,
    required this.onSubmitted,
    required this.onNextMatch,
    required this.onPreviousMatch,
    super.key,
  });

  final bool dense;
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final PdfTextSearcher? textSearcher;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onNextMatch;
  final VoidCallback onPreviousMatch;

  @override
  Widget build(BuildContext context) {
    bool hasActiveQuery() {
      final query = controller.text.trim();
      final pattern = textSearcher?.pattern;
      return query.isNotEmpty &&
          pattern is String &&
          pattern.toLowerCase() == query.toLowerCase();
    }

    void submitSearch() {
      final query = controller.text.trim();
      if (query.isEmpty) {
        controller.clear();
        return;
      }
      onSubmitted(query);
    }

    void submitOrNextMatch() {
      if (hasActiveQuery() && (textSearcher?.matches.isNotEmpty ?? false)) {
        onNextMatch();
        return;
      }
      submitSearch();
    }

    void submitOrPreviousMatch() {
      if (hasActiveQuery() && (textSearcher?.matches.isNotEmpty ?? false)) {
        onPreviousMatch();
        return;
      }
      submitSearch();
    }

    return SizedBox(
      width: dense ? 210 : 260,
      height: ReaderToolbarMetrics.controlHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  enabled &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  HardwareKeyboard.instance.isControlPressed) {
                submitOrPreviousMatch();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              onSubmitted: enabled
                  ? (_) {
                      if (HardwareKeyboard.instance.isControlPressed) {
                        submitOrPreviousMatch();
                        return;
                      }
                      submitOrNextMatch();
                    }
                  : null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                suffixIcon: enabled && textSearcher?.isSearching == true
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: '执行搜索',
                        onPressed: enabled ? submitSearch : null,
                        icon: Icon(Icons.arrow_forward_rounded, size: 18),
                      ),
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: ReaderToolbarMetrics.controlHeight,
                ),
                filled: true,
                fillColor: AppColors.toolbarItem,
                contentPadding: const EdgeInsets.fromLTRB(14, 0, 42, 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.line),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                if (controller.text.isNotEmpty || focusNode.hasFocus) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 14, right: 42),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.subtle,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '搜索内容',
                        style: TextStyle(color: AppColors.subtle, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PageStepper extends StatelessWidget {
  const PageStepper({
    required this.dense,
    required this.controller,
    required this.currentPage,
    required this.pageCount,
    required this.onSubmitted,
    required this.onPrevious,
    required this.onNext,
    this.narrow = false,
    this.width,
    super.key,
  });

  final bool dense;
  final TextEditingController controller;
  final int currentPage;
  final int pageCount;
  final VoidCallback onSubmitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool narrow;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final enabled = pageCount > 0;
    final buttonSize = narrow ? 30.0 : 34.0;
    final fieldWidth = narrow ? 30.0 : (dense ? 42.0 : 48.0);
    final numberGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: fieldWidth,
          child: TextField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => onSubmitted(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        Text(
          '/ ${pageCount == 0 ? '-' : pageCount}',
          style: TextStyle(
            color: AppColors.subtle,
            fontSize: narrow ? 11.5 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return Container(
      width: width,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _PageStepperArrow(
            tooltip: '上一页',
            icon: Icons.keyboard_arrow_left_rounded,
            size: buttonSize,
            onPressed: enabled && currentPage > 1 ? onPrevious : null,
          ),
          if (width == null)
            numberGroup
          else
            Expanded(child: Center(child: numberGroup)),
          _PageStepperArrow(
            tooltip: '下一页',
            icon: Icons.keyboard_arrow_right_rounded,
            size: buttonSize,
            onPressed: enabled && currentPage < pageCount ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _PageStepperArrow extends StatelessWidget {
  const _PageStepperArrow({
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 19,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.subtle.withValues(alpha: 0.38),
          minimumSize: Size(size, 34),
          fixedSize: Size(size, 34),
          maximumSize: Size(size, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    required this.dense,
    required this.enabled,
    required this.viewerController,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onFitPage,
    required this.fitWidthShortcut,
    required this.fitPageShortcut,
    super.key,
  });

  final bool dense;
  final bool enabled;
  final PdfViewerController viewerController;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final ReaderShortcutBinding? fitWidthShortcut;
  final ReaderShortcutBinding? fitPageShortcut;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        height: ReaderToolbarMetrics.controlHeight,
        decoration: BoxDecoration(
          color: AppColors.toolbarItem,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToolbarIconButton(
              tooltip: '缩小',
              icon: Icons.remove_rounded,
              onPressed: null,
            ),
            SizedBox(
              width: dense ? 46 : 52,
              child: Text(
                '--',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subtle,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            ToolbarIconButton(
              tooltip: '放大',
              icon: Icons.add_rounded,
              onPressed: null,
            ),
            ToolbarIconButton(
              tooltip: '适合宽度',
              svgAsset: ReaderIconAssets.fitWidth,
              iconSize: 25,
              shortcut: fitWidthShortcut,
              onPressed: null,
            ),
            ToolbarIconButton(
              tooltip: '适合页面',
              svgAsset: ReaderIconAssets.fitPage,
              iconSize: 25,
              shortcut: fitPageShortcut,
              onPressed: null,
            ),
          ],
        ),
      );
    }

    return Container(
      height: ReaderToolbarMetrics.controlHeight,
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: AnimatedBuilder(
        animation: viewerController,
        builder: (context, _) {
          final zoomText = '${(viewerController.currentZoom * 100).round()}%';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolbarIconButton(
                tooltip: '缩小',
                icon: Icons.remove_rounded,
                onPressed: onZoomOut,
              ),
              SizedBox(
                width: dense ? 46 : 52,
                child: Text(
                  zoomText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              ToolbarIconButton(
                tooltip: '放大',
                icon: Icons.add_rounded,
                onPressed: onZoomIn,
              ),
              ToolbarIconButton(
                tooltip: '适合宽度',
                svgAsset: ReaderIconAssets.fitWidth,
                iconSize: 25,
                shortcut: fitWidthShortcut,
                onPressed: onFitWidth,
              ),
              ToolbarIconButton(
                tooltip: '适合页面',
                svgAsset: ReaderIconAssets.fitPage,
                iconSize: 25,
                shortcut: fitPageShortcut,
                onPressed: onFitPage,
              ),
            ],
          );
        },
      ),
    );
  }
}

class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.svgAsset,
    this.iconSize = 19,
    this.shortcut,
    super.key,
  }) : assert(icon != null || svgAsset != null);

  final String tooltip;
  final IconData? icon;
  final String? svgAsset;
  final double iconSize;
  final ReaderShortcutBinding? shortcut;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = onPressed == null
        ? AppColors.subtle.withValues(alpha: 0.38)
        : AppColors.ink;
    return ShortcutTooltip(
      label: tooltip,
      shortcut: shortcut,
      child: IconButton(
        onPressed: onPressed,
        iconSize: iconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: ReaderToolbarMetrics.controlHeight,
          height: ReaderToolbarMetrics.controlHeight,
        ),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.subtle.withValues(alpha: 0.38),
          minimumSize: const Size(
            ReaderToolbarMetrics.controlHeight,
            ReaderToolbarMetrics.controlHeight,
          ),
          fixedSize: const Size(
            ReaderToolbarMetrics.controlHeight,
            ReaderToolbarMetrics.controlHeight,
          ),
          maximumSize: const Size(
            ReaderToolbarMetrics.controlHeight,
            ReaderToolbarMetrics.controlHeight,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: svgAsset == null
            ? Icon(icon)
            : ReaderSvgIcon(
                assetName: svgAsset!,
                color: foregroundColor,
                size: iconSize,
              ),
      ),
    );
  }
}

class ReaderSvgIcon extends StatelessWidget {
  const ReaderSvgIcon({
    required this.assetName,
    required this.color,
    this.size = 19,
    super.key,
  });

  final String assetName;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
