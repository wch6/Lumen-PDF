import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

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
    required this.twoColumnThumbnails,
    required this.recent,
    required this.loadingLibrary,
    required this.textSearcher,
    required this.onOpen,
    required this.onOpenRecent,
    required this.onGoToPage,
    required this.onGoToOutline,
    required this.onGoToSearchMatch,
    required this.onDeleteNote,
    required this.onAddNote,
    required this.onThumbnailLayoutChanged,
    required this.onQuickExportPage,
    required this.onExportPage,
    this.onCollapse,
    super.key,
  });

  final PanelMode mode;
  final PdfDocument? document;
  final List<PdfOutlineNode> outline;
  final List<PageNote> notes;
  final bool twoColumnThumbnails;
  final List<RecentDocument> recent;
  final bool loadingLibrary;
  final PdfTextSearcher? textSearcher;
  final VoidCallback onOpen;
  final ValueChanged<RecentDocument> onOpenRecent;
  final ValueChanged<int> onGoToPage;
  final ValueChanged<PdfDest> onGoToOutline;
  final ValueChanged<int> onGoToSearchMatch;
  final ValueChanged<PageNote> onDeleteNote;
  final VoidCallback onAddNote;
  final ValueChanged<bool> onThumbnailLayoutChanged;
  final ValueChanged<int> onQuickExportPage;
  final ValueChanged<int> onExportPage;
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
            loading: loadingLibrary,
            onOpen: onOpen,
            onOpenRecent: onOpenRecent,
            onCollapse: onCollapse,
          ),
          PanelMode.pages => PagesPanel(
            document: document,
            twoColumn: twoColumnThumbnails,
            onLayoutChanged: onThumbnailLayoutChanged,
            onGoToPage: onGoToPage,
            onQuickExportPage: onQuickExportPage,
            onExportPage: onExportPage,
            onCollapse: onCollapse,
          ),
          PanelMode.outline => OutlinePanel(
            outline: outline,
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
            onGoToPage: onGoToPage,
            onDeleteNote: onDeleteNote,
            onAddNote: onAddNote,
            onCollapse: onCollapse,
          ),
        },
      ),
    );
  }
}

class LibraryPanel extends StatelessWidget {
  const LibraryPanel({
    required this.recent,
    required this.loading,
    required this.onOpen,
    required this.onOpenRecent,
    this.onCollapse,
    super.key,
  });

  final List<RecentDocument> recent;
  final bool loading;
  final VoidCallback onOpen;
  final ValueChanged<RecentDocument> onOpenRecent;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      key: const ValueKey('library'),
      title: '资料库',
      subtitle: '本机 PDF、最近阅读和工作入口',
      onCollapse: onCollapse,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        children: [
          Tooltip(
            message: '打开 PDF 文件',
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: Icon(Icons.folder_open_rounded),
              label: const Text('打开 PDF'),
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
          const PanelSectionTitle('最近文件'),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty)
            const EmptyPanelMessage(
              icon: Icons.history_rounded,
              title: '还没有最近文件',
              body: '打开 PDF 后，这里会保留阅读进度。',
            )
          else
            ...recent.map(
              (item) => RecentTile(item: item, onTap: () => onOpenRecent(item)),
            ),
        ],
      ),
    );
  }
}

class PagesPanel extends StatefulWidget {
  const PagesPanel({
    required this.document,
    required this.twoColumn,
    required this.onLayoutChanged,
    required this.onGoToPage,
    required this.onQuickExportPage,
    required this.onExportPage,
    this.onCollapse,
    super.key,
  });

  final PdfDocument? document;
  final bool twoColumn;
  final ValueChanged<bool> onLayoutChanged;
  final ValueChanged<int> onGoToPage;
  final ValueChanged<int> onQuickExportPage;
  final ValueChanged<int> onExportPage;
  final VoidCallback? onCollapse;

  @override
  State<PagesPanel> createState() => _PagesPanelState();
}

class _PagesPanelState extends State<PagesPanel> {
  final _thumbnailScrollController = ScrollController();

  @override
  void dispose() {
    _thumbnailScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final crossAxisCount = widget.twoColumn ? 2 : 1;
    return PanelScaffold(
      key: const ValueKey('pages'),
      title: '页面',
      subtitle: doc == null ? '等待文档载入' : '${doc.pages.length} 页',
      onCollapse: widget.onCollapse,
      child: doc == null
          ? const EmptyPanelMessage(
              icon: Icons.view_module_outlined,
              title: '打开 PDF 后查看缩略图',
              body: '页面预览会随着文档载入生成。',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                  child: ThumbnailLayoutToggle(
                    twoColumn: widget.twoColumn,
                    onChanged: widget.onLayoutChanged,
                  ),
                ),
                Expanded(
                  child: GridView.builder(
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
                          onTap: () => widget.onGoToPage(page),
                          onQuickExport: () => widget.onQuickExportPage(page),
                          onExport: () => widget.onExportPage(page),
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

class ThumbnailLayoutToggle extends StatelessWidget {
  const ThumbnailLayoutToggle({
    required this.twoColumn,
    required this.onChanged,
    super.key,
  });

  final bool twoColumn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 180;
        if (compact) {
          return Row(
            children: [
              Text(
                twoColumn ? '双页' : '单页',
                style: TextStyle(
                  color: AppColors.subtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: twoColumn ? '切换为单页缩略图' : '切换为双页缩略图',
                child: Switch(
                  value: twoColumn,
                  onChanged: onChanged,
                  activeThumbColor: AppColors.accent,
                  inactiveThumbColor: AppColors.subtle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Text(
              twoColumn ? '双页缩略图' : '单页缩略图',
              style: TextStyle(
                color: AppColors.subtle,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.crop_portrait_rounded, size: 17),
                  tooltip: '单页缩略图',
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.view_module_rounded, size: 17),
                  tooltip: '双页缩略图',
                ),
              ],
              selected: {twoColumn},
              onSelectionChanged: (value) => onChanged(value.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.accentSoft;
                  }
                  return AppColors.toolbarItem;
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PageThumb extends StatelessWidget {
  const PageThumb({
    required this.document,
    required this.pageNumber,
    required this.onTap,
    required this.onQuickExport,
    required this.onExport,
    super.key,
  });

  final PdfDocument document;
  final int pageNumber;
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
                child: PdfPageView(
                  document: document,
                  pageNumber: pageNumber,
                  alignment: Alignment.center,
                  maximumDpi: 156,
                  decoration: const BoxDecoration(color: Color(0xFFFFFCF9)),
                  backgroundColor: const Color(0xFFFFFCF9),
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
                tooltip: '页面操作',
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
                    child: Text('快速导出'),
                  ),
                  PopupMenuItem(
                    value: _PageThumbAction.export,
                    child: Text('普通导出'),
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

class OutlinePanel extends StatelessWidget {
  const OutlinePanel({
    required this.outline,
    required this.onGoToDest,
    this.onCollapse,
    super.key,
  });

  final List<PdfOutlineNode> outline;
  final ValueChanged<PdfDest> onGoToDest;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      key: const ValueKey('outline'),
      title: '目录',
      subtitle: outline.isEmpty ? '未检测到文档目录' : '跳转到章节',
      onCollapse: onCollapse,
      child: outline.isEmpty
          ? const EmptyPanelMessage(
              icon: Icons.bookmark_border_rounded,
              title: '没有可用目录',
              body: '部分扫描件或导出文件不会包含 PDF 大纲。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 18),
              children: [
                for (final node in outline)
                  OutlineNodeTile(node: node, onGoToDest: onGoToDest),
              ],
            ),
    );
  }
}

class OutlineNodeTile extends StatelessWidget {
  const OutlineNodeTile({
    required this.node,
    required this.onGoToDest,
    this.depth = 0,
    super.key,
  });

  final PdfOutlineNode node;
  final ValueChanged<PdfDest> onGoToDest;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final dest = node.dest;
    return Column(
      children: [
        InkWell(
          onTap: dest == null ? null : () => onGoToDest(dest),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10 + depth * 14, 9, 8, 9),
            child: Row(
              children: [
                Icon(
                  depth == 0
                      ? Icons.menu_book_rounded
                      : Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: AppColors.subtle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final child in node.children)
          OutlineNodeTile(
            node: child,
            onGoToDest: onGoToDest,
            depth: depth + 1,
          ),
      ],
    );
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
    final total = matches.length;
    return PanelScaffold(
      key: const ValueKey('search'),
      title: '搜索结果',
      subtitle: isSearching ? '正在扫描文本层' : '$total 个匹配',
      onCollapse: onCollapse,
      child: total == 0
          ? EmptyPanelMessage(
              icon: Icons.search_rounded,
              title: isSearching ? '搜索中' : '暂无结果',
              body: isSearching ? '正在读取 PDF 文本层。' : '在顶部搜索框输入关键词。',
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
    required this.onTap,
    super.key,
  });

  final int index;
  final int pageNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '第 $pageNumber 页',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}

class NotesPanel extends StatelessWidget {
  const NotesPanel({
    required this.notes,
    required this.onGoToPage,
    required this.onDeleteNote,
    required this.onAddNote,
    this.onCollapse,
    super.key,
  });

  final List<PageNote> notes;
  final ValueChanged<int> onGoToPage;
  final ValueChanged<PageNote> onDeleteNote;
  final VoidCallback onAddNote;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      key: const ValueKey('notes'),
      title: '笔记',
      subtitle: '${notes.length} 条本地页面笔记',
      onCollapse: onCollapse,
      trailing: IconButton.filledTonal(
        tooltip: '新建笔记',
        onPressed: onAddNote,
        icon: Icon(Icons.add_comment_outlined),
      ),
      child: notes.isEmpty
          ? const EmptyPanelMessage(
              icon: Icons.sticky_note_2_outlined,
              title: '还没有笔记',
              body: '点击左侧栏的新建便签，为当前页添加本地批注。',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = notes[index];
                return NoteTile(
                  note: note,
                  onTap: () => onGoToPage(note.page),
                  onDelete: () => onDeleteNote(note),
                );
              },
            ),
    );
  }
}

class NoteTile extends StatelessWidget {
  const NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final PageNote note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.note,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE9D689)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '第 ${note.page} 页',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '删除笔记',
                  onPressed: onDelete,
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
            const SizedBox(height: 6),
            Text(
              note.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.ink, height: 1.35),
            ),
          ],
        ),
      ),
    );
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
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.subtle,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (onCollapse != null)
                IconButton(
                  tooltip: '收起侧边栏',
                  onPressed: onCollapse,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.keyboard_double_arrow_left_rounded),
                ),
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
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

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
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtle,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentTile extends StatelessWidget {
  const RecentTile({required this.item, required this.onTap, super.key});

  final RecentDocument item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
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
    );
  }
}
