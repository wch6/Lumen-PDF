import 'package:flutter/material.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

class ReaderRail extends StatelessWidget {
  const ReaderRail({
    required this.selected,
    required this.onSelected,
    required this.hasDocument,
    required this.onSettings,
    super.key,
  });

  final PanelMode selected;
  final ValueChanged<PanelMode> onSelected;
  final bool hasDocument;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      color: AppColors.rail,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Tooltip(
            message: '资料库',
            child: IconButton(
              onPressed: () => onSelected(PanelMode.library),
              style: IconButton.styleFrom(
                backgroundColor: selected == PanelMode.library
                    ? AppColors.accent
                    : AppColors.accentSoft,
                foregroundColor: selected == PanelMode.library
                    ? AppColors.surface
                    : AppColors.accent,
                minimumSize: const Size(42, 42),
                fixedSize: const Size(42, 42),
                maximumSize: const Size(42, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.picture_as_pdf_rounded, size: 23),
            ),
          ),
          const SizedBox(height: 14),
          RailButton(
            tooltip: '页面缩略图',
            icon: Icons.view_module_outlined,
            selected: selected == PanelMode.pages,
            enabled: hasDocument,
            onTap: () => onSelected(PanelMode.pages),
          ),
          RailButton(
            tooltip: '目录书签',
            icon: Icons.bookmark_border_rounded,
            selected: selected == PanelMode.outline,
            enabled: hasDocument,
            onTap: () => onSelected(PanelMode.outline),
          ),
          RailButton(
            tooltip: '搜索',
            icon: Icons.search_rounded,
            selected: selected == PanelMode.search,
            enabled: hasDocument,
            onTap: () => onSelected(PanelMode.search),
          ),
          RailButton(
            tooltip: '页面笔记',
            icon: Icons.sticky_note_2_outlined,
            selected: selected == PanelMode.notes,
            enabled: hasDocument,
            onTap: () => onSelected(PanelMode.notes),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              iconSize: 22,
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.accent,
                minimumSize: const Size(40, 40),
                fixedSize: const Size(40, 40),
                maximumSize: const Size(40, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.settings_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class RailButton extends StatelessWidget {
  const RailButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: enabled ? onTap : null,
          iconSize: 21,
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            fixedSize: const Size(40, 40),
            maximumSize: const Size(40, 40),
            backgroundColor: selected
                ? AppColors.accentSoft
                : Colors.transparent,
            foregroundColor: selected ? AppColors.accent : AppColors.muted,
            disabledForegroundColor: AppColors.muted.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}
