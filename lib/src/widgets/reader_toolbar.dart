import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

class ReaderToolbarMetrics {
  const ReaderToolbarMetrics._();

  static const double hideFileNameBelow = 1120;
  static const int minimumWindowWidth = 900;
  static const int minimumWindowHeight = 640;
}

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    required this.source,
    required this.currentPage,
    required this.pageCount,
    required this.jumpController,
    required this.searchController,
    required this.searchFocusNode,
    required this.nightMode,
    required this.textSearcher,
    required this.viewerController,
    required this.sessionTabs,
    required this.currentSourceId,
    required this.onOpen,
    required this.onOpenTab,
    required this.onSearch,
    required this.onJumpSubmitted,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onFitPage,
    required this.highlightColor,
    required this.onHighlightColorChanged,
    required this.onAddNote,
    required this.onNightModeChanged,
    required this.showWindowControls,
    required this.windowMaximized,
    required this.onWindowDrag,
    required this.onWindowMinimize,
    required this.onWindowMaximizeRestore,
    required this.onWindowClose,
    super.key,
  });

  final PdfSource? source;
  final int currentPage;
  final int pageCount;
  final TextEditingController jumpController;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool nightMode;
  final PdfTextSearcher? textSearcher;
  final PdfViewerController viewerController;
  final List<SessionDocumentTab> sessionTabs;
  final String? currentSourceId;
  final VoidCallback onOpen;
  final ValueChanged<SessionDocumentTab> onOpenTab;
  final ValueChanged<String> onSearch;
  final VoidCallback onJumpSubmitted;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final Color highlightColor;
  final ValueChanged<Color> onHighlightColorChanged;
  final VoidCallback onAddNote;
  final ValueChanged<bool> onNightModeChanged;
  final bool showWindowControls;
  final bool windowMaximized;
  final VoidCallback onWindowDrag;
  final VoidCallback onWindowMinimize;
  final VoidCallback onWindowMaximizeRestore;
  final VoidCallback onWindowClose;

  @override
  Widget build(BuildContext context) {
    final hasDocument = source != null && pageCount > 0;

    Widget openButton() {
      return Tooltip(
        message: '打开 PDF',
        child: IconButton.filledTonal(
          onPressed: onOpen,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accentSoft,
            foregroundColor: AppColors.accent,
            minimumSize: const Size(38, 38),
            fixedSize: const Size(38, 38),
            maximumSize: const Size(38, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(Icons.folder_open_rounded),
        ),
      );
    }

    Widget controls({required bool dense}) {
      final gap = dense ? 4.0 : 6.0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SearchBox(
            dense: dense,
            enabled: hasDocument,
            controller: searchController,
            focusNode: searchFocusNode,
            textSearcher: textSearcher,
            onSubmitted: onSearch,
          ),
          SizedBox(width: gap),
          PageStepper(
            dense: dense,
            controller: jumpController,
            currentPage: currentPage,
            pageCount: pageCount,
            onSubmitted: onJumpSubmitted,
            onPrevious: onPreviousPage,
            onNext: onNextPage,
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
          ),
          SizedBox(width: gap),
          HighlightColorButton(
            selectedColor: highlightColor,
            onSelected: onHighlightColorChanged,
          ),
          SizedBox(width: gap),
          ToolbarSquareButton(
            tooltip: '新建便签',
            icon: Icons.add_comment_outlined,
            onPressed: hasDocument ? onAddNote : null,
          ),
          SizedBox(width: gap),
          Tooltip(
            message: nightMode ? '切换到日间模式' : '切换到夜间模式',
            child: Switch(
              value: nightMode,
              onChanged: onNightModeChanged,
              activeThumbColor: AppColors.accent,
              inactiveThumbColor: AppColors.subtle,
            ),
          ),
        ],
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
          final compact = constraints.maxWidth < 940;
          final showFileName =
              constraints.maxWidth >= ReaderToolbarMetrics.hideFileNameBelow;
          final dense = !showFileName;
          final gap = dense ? 4.0 : 8.0;

          return SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      dense || compact ? 8 : 12,
                      7,
                      showWindowControls ? gap : (dense || compact ? 8 : 12),
                      7,
                    ),
                    child: Row(
                      children: [
                        openButton(),
                        SizedBox(width: gap),
                        if (showFileName) ...[
                          CurrentFileNamePill(
                            source: source,
                            width: compact ? 156 : 220,
                          ),
                          SizedBox(width: gap),
                        ],
                        OpenTabsButton(
                          tabs: sessionTabs,
                          currentSourceId: currentSourceId,
                          onSelected: onOpenTab,
                        ),
                        SizedBox(
                          width: gap,
                          child: showWindowControls
                              ? WindowDragRegion(
                                  onDrag: onWindowDrag,
                                  onDoubleTap: onWindowMaximizeRestore,
                                )
                              : null,
                        ),
                        if (compact) ...[
                          Expanded(
                            child: WindowDragRegion(
                              onDrag: onWindowDrag,
                              onDoubleTap: onWindowMaximizeRestore,
                            ),
                          ),
                          controls(dense: dense),
                        ] else ...[
                          Expanded(
                            child: WindowDragRegion(
                              onDrag: onWindowDrag,
                              onDoubleTap: onWindowMaximizeRestore,
                            ),
                          ),
                          controls(dense: dense),
                        ],
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
    super.key,
  });

  final PdfSource? source;
  final double width;

  @override
  Widget build(BuildContext context) {
    final name = source?.name ?? '未打开 PDF';
    final path = source?.path ?? name;
    final active = source != null;
    return Tooltip(
      message: path,
      child: Container(
        width: width,
        height: 38,
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
    );
  }
}

class OpenTabsButton extends StatefulWidget {
  const OpenTabsButton({
    required this.tabs,
    required this.currentSourceId,
    required this.onSelected,
    super.key,
  });

  final List<SessionDocumentTab> tabs;
  final String? currentSourceId;
  final ValueChanged<SessionDocumentTab> onSelected;

  @override
  State<OpenTabsButton> createState() => _OpenTabsButtonState();
}

class _OpenTabsButtonState extends State<OpenTabsButton> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final menuWidth = math.min(
      420.0,
      math.max(284.0, MediaQuery.sizeOf(context).width * 0.38),
    );
    return MenuAnchor(
      controller: _menuController,
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
            maxHeight: 420,
          ),
          child: _OpenTabsMenu(
            tabs: widget.tabs,
            currentSourceId: widget.currentSourceId,
            onSelected: (tab) {
              widget.onSelected(tab);
              _menuController.close();
            },
          ),
        ),
      ],
      builder: (context, controller, _) {
        return Tooltip(
          message: '切换本次打开的文件',
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
              minimumSize: const Size(38, 38),
              fixedSize: const Size(38, 38),
              maximumSize: const Size(38, 38),
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
    required this.currentSourceId,
    required this.onSelected,
  });

  final List<SessionDocumentTab> tabs;
  final String? currentSourceId;
  final ValueChanged<SessionDocumentTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final tooltipMaxWidth = MediaQuery.sizeOf(context).width * 0.5;
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
              '打开的标签页',
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
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 12,
                    color: AppColors.line.withValues(alpha: 0.65),
                  ),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    return Tooltip(
                      message: tab.tooltipPath,
                      constraints: BoxConstraints(maxWidth: tooltipMaxWidth),
                      child: _OpenTabTile(
                        tab: tab,
                        selected: tab.source.id == currentSourceId,
                        onTap: () => onSelected(tab),
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
    required this.selected,
    required this.onTap,
  });

  final SessionDocumentTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.toolbarItem,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 24,
                color: selected ? AppColors.accent : AppColors.subtle,
              ),
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

class ToolbarSquareButton extends StatelessWidget {
  const ToolbarSquareButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.toolbarItem,
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.subtle.withValues(alpha: 0.38),
          side: BorderSide(color: AppColors.line),
          minimumSize: const Size(34, 34),
          fixedSize: const Size(34, 34),
          maximumSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon),
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
    required this.onSelected,
    super.key,
  });

  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  @override
  State<HighlightColorButton> createState() => _HighlightColorButtonState();
}

class _HighlightColorButtonState extends State<HighlightColorButton> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 178,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in AppColors.highlightPalette)
                  _HighlightSwatch(
                    color: color,
                    selected:
                        color.toARGB32() == widget.selectedColor.toARGB32(),
                    onTap: () {
                      widget.onSelected(color);
                      _menuController.close();
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        return Tooltip(
          message: '选择高亮颜色',
          child: IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            iconSize: 19,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.toolbarItem,
              foregroundColor: AppColors.ink,
              side: BorderSide(color: AppColors.line),
              minimumSize: const Size(34, 34),
              fixedSize: const Size(34, 34),
              maximumSize: const Size(34, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.format_color_fill_rounded),
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 18,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.selectedColor.withValues(alpha: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
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
    required this.onTap,
  });

  final Color color;
  final bool selected;
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
          child: selected
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
    super.key,
  });

  final bool dense;
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final PdfTextSearcher? textSearcher;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dense ? 150 : 180,
      height: 34,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onSubmitted: enabled ? onSubmitted : null,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索内容',
          prefixIcon: Icon(Icons.search_rounded, size: 18),
          suffixIcon: enabled && textSearcher?.isSearching == true
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: '执行搜索',
                  onPressed: enabled
                      ? () => onSubmitted(controller.text)
                      : null,
                  icon: Icon(Icons.arrow_forward_rounded, size: 18),
                ),
          filled: true,
          fillColor: AppColors.toolbarItem,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
    super.key,
  });

  final bool dense;
  final TextEditingController controller;
  final int currentPage;
  final int pageCount;
  final VoidCallback onSubmitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final enabled = pageCount > 0;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToolbarIconButton(
            tooltip: '上一页',
            icon: Icons.keyboard_arrow_left_rounded,
            onPressed: enabled && currentPage > 1 ? onPrevious : null,
          ),
          SizedBox(
            width: dense ? 42 : 48,
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          ToolbarIconButton(
            tooltip: '下一页',
            icon: Icons.keyboard_arrow_right_rounded,
            onPressed: enabled && currentPage < pageCount ? onNext : null,
          ),
        ],
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
    super.key,
  });

  final bool dense;
  final bool enabled;
  final PdfViewerController viewerController;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        height: 34,
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
              icon: Icons.width_normal_rounded,
              onPressed: null,
            ),
            ToolbarIconButton(
              tooltip: '适合页面',
              icon: Icons.fit_screen_rounded,
              onPressed: null,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 34,
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
                icon: Icons.width_normal_rounded,
                onPressed: onFitWidth,
              ),
              ToolbarIconButton(
                tooltip: '适合页面',
                icon: Icons.fit_screen_rounded,
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
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 19,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.subtle.withValues(alpha: 0.38),
          minimumSize: const Size(34, 34),
          fixedSize: const Size(34, 34),
          maximumSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
