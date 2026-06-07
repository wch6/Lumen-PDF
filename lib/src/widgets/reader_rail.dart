import 'package:flutter/material.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';
import 'shortcut_tooltip.dart';

class ReaderRail extends StatelessWidget {
  const ReaderRail({
    required this.selected,
    required this.onSelected,
    required this.shortcutBindings,
    required this.hasDocument,
    required this.nightMode,
    required this.onNightModeChanged,
    required this.onSettings,
    super.key,
  });

  final PanelMode selected;
  final ValueChanged<PanelMode> onSelected;
  final Map<ReaderShortcutAction, ReaderShortcutBinding> shortcutBindings;
  final bool hasDocument;
  final bool nightMode;
  final ValueChanged<bool> onNightModeChanged;
  final VoidCallback onSettings;

  ReaderShortcutBinding? _shortcut(ReaderShortcutAction action) {
    return shortcutBindings[action] ?? kDefaultShortcutBindings[action];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      color: AppColors.rail,
      child: Column(
        children: [
          const SizedBox(height: 10),
          ShortcutTooltip(
            label: '资料库',
            shortcut: _shortcut(ReaderShortcutAction.openLibraryPanel),
            placement: ShortcutTooltipPlacement.right,
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
            shortcut: _shortcut(ReaderShortcutAction.openPagesPanel),
            onTap: () => onSelected(PanelMode.pages),
          ),
          RailButton(
            tooltip: '目录书签',
            icon: Icons.bookmark_border_rounded,
            selected: selected == PanelMode.outline,
            enabled: hasDocument,
            shortcut: _shortcut(ReaderShortcutAction.openOutlinePanel),
            onTap: () => onSelected(PanelMode.outline),
          ),
          RailButton(
            tooltip: '页面笔记',
            icon: Icons.sticky_note_2_outlined,
            selected: selected == PanelMode.notes,
            enabled: hasDocument,
            shortcut: _shortcut(ReaderShortcutAction.openNotesPanel),
            onTap: () => onSelected(PanelMode.notes),
          ),
          RailButton(
            tooltip: '搜索',
            icon: Icons.search_rounded,
            selected: selected == PanelMode.search,
            enabled: hasDocument,
            onTap: () => onSelected(PanelMode.search),
          ),
          RailButton(
            tooltip: '划词翻译',
            icon: Icons.translate_rounded,
            selected: selected == PanelMode.translate,
            enabled: hasDocument,
            onTap: () => onSelected(PanelMode.translate),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NightModeRailToggle(
              nightMode: nightMode,
              shortcut: _shortcut(ReaderShortcutAction.toggleTheme),
              onChanged: onNightModeChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ShortcutTooltip(
              label: '设置',
              shortcut: _shortcut(ReaderShortcutAction.openSettings),
              placement: ShortcutTooltipPlacement.right,
              child: IconButton(
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
          ),
        ],
      ),
    );
  }
}

class NightModeRailToggle extends StatelessWidget {
  const NightModeRailToggle({
    required this.nightMode,
    required this.shortcut,
    required this.onChanged,
    super.key,
  });

  final bool nightMode;
  final ReaderShortcutBinding? shortcut;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ShortcutTooltip(
      label: '切换模式',
      shortcut: shortcut,
      placement: ShortcutTooltipPlacement.right,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!nightMode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 38,
          height: 78,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentLine),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        size: 17,
                        color: nightMode
                            ? AppColors.accent.withValues(alpha: 0.38)
                            : AppColors.accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.nightlight_round,
                        size: 17,
                        color: nightMode
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: nightMode
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.line.withValues(alpha: 0.75),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    nightMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    this.shortcut,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final ReaderShortcutBinding? shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ShortcutTooltip(
        label: tooltip,
        shortcut: shortcut,
        placement: ShortcutTooltipPlacement.right,
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
