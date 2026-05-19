import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

enum _SettingsSection { general, shortcuts }

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    required this.settings,
    required this.nightMode,
    required this.onSettingsChanged,
    required this.onNightModeChanged,
    required this.onShortcutChanged,
    required this.onClearCache,
    super.key,
  });

  final ReaderSettings settings;
  final bool nightMode;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final ValueChanged<bool> onNightModeChanged;
  final void Function(
    ReaderShortcutAction action,
    ReaderShortcutBinding binding,
  )
  onShortcutChanged;
  final Future<void> Function() onClearCache;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late ReaderSettings _settings = widget.settings;
  late bool _nightMode = widget.nightMode;
  _SettingsSection _section = _SettingsSection.general;

  void _emitSettings(ReaderSettings settings) {
    setState(() => _settings = settings);
    widget.onSettingsChanged(settings);
  }

  void _selectAccent(ReaderAccent accent) {
    _emitSettings(_settings.copyWith(accent: accent));
  }

  void _selectDefaultPageLayout(DefaultPageLayout layout) {
    _emitSettings(_settings.copyWith(defaultPageLayout: layout));
  }

  void _setAlwaysOpenWithDefaultLayout(bool value) {
    _emitSettings(_settings.copyWith(alwaysOpenWithDefaultLayout: value));
  }

  void _setResolutionMode(ResolutionMode mode) {
    _emitSettings(_settings.copyWith(resolutionMode: mode));
  }

  void _setScrollSensitivity(double value) {
    _emitSettings(_settings.copyWith(scrollSensitivity: value));
  }

  void _setQuickExportResolution(int resolution) {
    _emitSettings(_settings.copyWith(quickExportResolution: resolution));
  }

  void _setQuickExportFormat(ExportImageFormat format) {
    _emitSettings(_settings.copyWith(quickExportFormat: format));
  }

  void _setQuickExportNamePattern(String pattern) {
    final value = pattern.trim().isEmpty ? '{document}_P{page}' : pattern;
    _emitSettings(_settings.copyWith(quickExportNamePattern: value));
  }

  void _setQuickExportFolder(String? folder) {
    _emitSettings(_settings.copyWith(quickExportFolder: folder));
  }

  Future<void> _chooseQuickExportFolder() async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: '选择快速导出文件夹',
      initialDirectory: _settings.quickExportFolder,
      lockParentWindow: true,
    );
    if (folder != null) {
      _setQuickExportFolder(folder);
    }
  }

  void _setNightMode(bool value) {
    setState(() => _nightMode = value);
    widget.onNightModeChanged(value);
  }

  void _setShortcut(
    ReaderShortcutAction action,
    ReaderShortcutBinding binding,
  ) {
    final shortcuts = Map<ReaderShortcutAction, ReaderShortcutBinding>.of(
      _settings.shortcutBindings,
    );
    shortcuts[action] = binding;
    setState(() => _settings = _settings.copyWith(shortcutBindings: shortcuts));
    widget.onShortcutChanged(action, binding);
  }

  void _resetShortcut(ReaderShortcutAction action) {
    final binding = kDefaultShortcutBindings[action];
    if (binding != null) {
      _setShortcut(action, binding);
    }
  }

  Future<void> _captureShortcut(ReaderShortcutAction action) async {
    final binding = await showDialog<ReaderShortcutBinding>(
      context: context,
      builder: (context) => _ShortcutCaptureDialog(action: action),
    );
    if (binding != null) {
      _setShortcut(action, binding);
    }
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('清除软件缓存', style: TextStyle(color: AppColors.ink)),
          content: Text(
            '将清除本软件保存的设置、最近文件记录、便签和高亮缓存。不删除本地 PDF 文件。',
            style: TextStyle(color: AppColors.subtle, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.surface,
              ),
              child: const Text('确认清除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await widget.onClearCache();
    if (mounted) {
      setState(() => _settings = const ReaderSettings());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 620),
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 22),
                  Text(
                    '设置',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AppColors.ink),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.line),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 228,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                      children: [
                        _SettingsNavItem(
                          icon: Icons.tune_rounded,
                          label: '一般',
                          selected: _section == _SettingsSection.general,
                          onTap: () => setState(
                            () => _section = _SettingsSection.general,
                          ),
                        ),
                        _SettingsNavItem(
                          icon: Icons.keyboard_rounded,
                          label: '快捷键',
                          selected: _section == _SettingsSection.shortcuts,
                          onTap: () => setState(
                            () => _section = _SettingsSection.shortcuts,
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: AppColors.line),
                  Expanded(
                    child: switch (_section) {
                      _SettingsSection.general => _buildGeneralSettings(),
                      _SettingsSection.shortcuts => _ShortcutSettingsView(
                        settings: _settings,
                        onCapture: _captureShortcut,
                        onReset: _resetShortcut,
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 28),
      children: [
        _SectionTitle('外观'),
        const SizedBox(height: 18),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            _AccentCard(
              accent: ReaderAccent.rose,
              selected: _settings.accent == ReaderAccent.rose,
              onTap: () => _selectAccent(ReaderAccent.rose),
            ),
            _AccentCard(
              accent: ReaderAccent.purple,
              selected: _settings.accent == ReaderAccent.purple,
              onTap: () => _selectAccent(ReaderAccent.purple),
            ),
            _AccentCard(
              accent: ReaderAccent.green,
              selected: _settings.accent == ReaderAccent.green,
              onTap: () => _selectAccent(ReaderAccent.green),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 24),
        _SectionTitle('阅读'),
        const SizedBox(height: 14),
        _SettingsDropdownTile(
          title: '默认页面布局',
          subtitle: '新打开文档时优先采用的阅读比例。',
          value: _settings.defaultPageLayout,
          onChanged: _selectDefaultPageLayout,
        ),
        const SizedBox(height: 10),
        _SettingsCheckboxTile(
          title: '始终以该比例打开文档',
          subtitle: '关闭后，文档会沿用关闭前的缩放状态或默认状态打开。',
          value: _settings.alwaysOpenWithDefaultLayout,
          onChanged: _setAlwaysOpenWithDefaultLayout,
        ),
        const SizedBox(height: 10),
        _SettingsSwitchTile(
          title: '柔和夜读',
          subtitle: '界面切换为深色，PDF 页面保持原始显示。',
          value: _nightMode,
          onChanged: _setNightMode,
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 24),
        _SectionTitle('分辨率'),
        const SizedBox(height: 14),
        _ResolutionTile(settings: _settings, onModeChanged: _setResolutionMode),
        const SizedBox(height: 24),
        Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 24),
        _SectionTitle('滚动'),
        const SizedBox(height: 14),
        _SettingsSliderTile(
          title: '速度滚轮灵敏度',
          subtitle: '灵敏度越高，快速滚动时跨过的页面越多。缩略图侧栏固定使用高速滚动。',
          value: _settings.scrollSensitivity,
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: _setScrollSensitivity,
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 24),
        _SectionTitle('页面导出'),
        const SizedBox(height: 14),
        _ExportDefaultsTile(
          settings: _settings,
          onResolutionChanged: _setQuickExportResolution,
          onFormatChanged: _setQuickExportFormat,
          onNamePatternChanged: _setQuickExportNamePattern,
          onChooseFolder: _chooseQuickExportFolder,
          onClearFolder: () => _setQuickExportFolder(null),
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 24),
        _SectionTitle('维护'),
        const SizedBox(height: 14),
        _DangerActionTile(
          title: '清除软件缓存',
          subtitle: '清除设置、最近文件记录、便签和高亮缓存，不删除本地 PDF 文件。',
          buttonLabel: '清除',
          onPressed: _confirmClearCache,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.ink),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutSettingsView extends StatelessWidget {
  const _ShortcutSettingsView({
    required this.settings,
    required this.onCapture,
    required this.onReset,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderShortcutAction> onCapture;
  final ValueChanged<ReaderShortcutAction> onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 28),
      children: [
        const _SectionTitle('快捷键'),
        const SizedBox(height: 8),
        Text(
          '点击“录入”后按下新的组合键。建议保留 Ctrl+F 搜索、Esc 清除搜索、Ctrl+O 打开文件、Ctrl+Shift+N 新建便签。',
          style: TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 18),
        for (final action in ReaderShortcutAction.values) ...[
          _ShortcutTile(
            action: action,
            binding:
                settings.shortcutBindings[action] ??
                kDefaultShortcutBindings[action]!,
            onCapture: () => onCapture(action),
            onReset: () => onReset(action),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.action,
    required this.binding,
    required this.onCapture,
    required this.onReset,
  });

  final ReaderShortcutAction action;
  final ReaderShortcutBinding binding;
  final VoidCallback onCapture;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action.label,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 116),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              binding.label,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onCapture, child: const Text('录入')),
          TextButton(onPressed: onReset, child: const Text('默认')),
        ],
      ),
    );
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.action});

  final ReaderShortcutAction action;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  final _focusNode = FocusNode();
  ReaderShortcutBinding? _binding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('设置快捷键', style: TextStyle(color: AppColors.ink)),
      content: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          final next = ReaderShortcutBinding.fromKeyEvent(event);
          if (next != null) {
            setState(() => _binding = next);
          }
        },
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.toolbarItem,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.action.label,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _binding?.label ?? '按下新的快捷键',
                style: TextStyle(
                  color: _binding == null ? AppColors.subtle : AppColors.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _binding == null
              ? null
              : () => Navigator.of(context).pop(_binding),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.surface,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _AccentCard extends StatelessWidget {
  const _AccentCard({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final ReaderAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatches = switch (accent) {
      ReaderAccent.rose => const [Color(0xFFE94C5F), Color(0xFFFFE8EC)],
      ReaderAccent.purple => const [Color(0xFF7367F0), Color(0xFFEDEBFF)],
      ReaderAccent.green => const [Color(0xFF31B37A), Color(0xFFE3F7EE)],
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 176,
        height: 162,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.toolbarItem,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: swatches.last,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      decoration: BoxDecoration(
                        color: swatches.first,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(height: 8, color: swatches.first),
                            const SizedBox(height: 10),
                            Container(
                              height: 8,
                              color: swatches.first.withValues(alpha: 0.58),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 8,
                              color: swatches.first.withValues(alpha: 0.28),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              accent.label,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionTile extends StatelessWidget {
  const _ResolutionTile({required this.settings, required this.onModeChanged});

  final ReaderSettings settings;
  final ValueChanged<ResolutionMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RadioGroup<ResolutionMode>(
        groupValue: settings.resolutionMode,
        onChanged: (value) {
          if (value != null) {
            onModeChanged(value);
          }
        },
        child: Column(
          children: [
            _ResolutionOption(
              mode: ResolutionMode.defaultSetting,
              valueText: '${ReaderSettings.defaultResolution}',
              onModeChanged: onModeChanged,
            ),
            const SizedBox(height: 6),
            _ResolutionOption(
              mode: ResolutionMode.systemSetting,
              valueText:
                  '${ReaderSettings.systemResolutionFor(MediaQuery.devicePixelRatioOf(context))}',
              onModeChanged: onModeChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionOption extends StatelessWidget {
  const _ResolutionOption({
    required this.mode,
    required this.valueText,
    required this.onModeChanged,
  });

  final ResolutionMode mode;
  final String valueText;
  final ValueChanged<ResolutionMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Radio<ResolutionMode>(value: mode, activeColor: AppColors.accent),
            Expanded(
              child: Text(
                '${mode.label}：',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '像素/英寸',
              style: TextStyle(color: AppColors.subtle, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSliderTile extends StatelessWidget {
  const _SettingsSliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SettingsText(title: title, subtitle: subtitle),
          ),
          SizedBox(
            width: 260,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: value.round().toString(),
                    activeColor: AppColors.accent,
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    value.round().toString(),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
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

class _ExportDefaultsTile extends StatelessWidget {
  const _ExportDefaultsTile({
    required this.settings,
    required this.onResolutionChanged,
    required this.onFormatChanged,
    required this.onNamePatternChanged,
    required this.onChooseFolder,
    required this.onClearFolder,
  });

  final ReaderSettings settings;
  final ValueChanged<int> onResolutionChanged;
  final ValueChanged<ExportImageFormat> onFormatChanged;
  final ValueChanged<String> onNamePatternChanged;
  final VoidCallback onChooseFolder;
  final VoidCallback onClearFolder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsText(
            title: '快速导出默认值',
            subtitle: '用于缩略图菜单中的快速导出，普通导出会默认继承这些值。',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 128,
                child: _NumberField(
                  key: ValueKey('export-${settings.quickExportResolution}'),
                  value: settings.quickExportResolution,
                  min: 72,
                  max: 600,
                  onChanged: onResolutionChanged,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '像素/英寸',
                style: TextStyle(color: AppColors.subtle, fontSize: 13),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 116,
                child: DropdownButtonFormField<ExportImageFormat>(
                  initialValue: settings.quickExportFormat,
                  items: [
                    for (final item in ExportImageFormat.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onFormatChanged(value);
                    }
                  },
                  decoration: _fieldDecoration(),
                  dropdownColor: AppColors.surface,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('pattern-${settings.quickExportNamePattern}'),
            initialValue: settings.quickExportNamePattern,
            onChanged: onNamePatternChanged,
            style: TextStyle(color: AppColors.ink, fontSize: 13),
            decoration: _fieldDecoration(
              hintText: '{document}_P{page}',
              labelText: '命名格式',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  settings.quickExportFolder ?? '未设置导出文件夹',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.subtle, fontSize: 12),
                ),
              ),
              TextButton(onPressed: onChooseFolder, child: const Text('选择文件夹')),
              if (settings.quickExportFolder != null)
                TextButton(onPressed: onClearFolder, child: const Text('清除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) {
          onChanged(parsed.clamp(min, max));
        }
      },
      style: TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: _fieldDecoration(),
    );
  }
}

InputDecoration _fieldDecoration({String? hintText, String? labelText}) {
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    filled: true,
    fillColor: AppColors.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.line),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
    ),
  );
}

class _SettingsDropdownTile extends StatelessWidget {
  const _SettingsDropdownTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final DefaultPageLayout value;
  final ValueChanged<DefaultPageLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SettingsText(title: title, subtitle: subtitle),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<DefaultPageLayout>(
              initialValue: value,
              items: [
                for (final item in DefaultPageLayout.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
              dropdownColor: AppColors.surface,
              iconEnabledColor: AppColors.ink,
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              decoration: _fieldDecoration(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCheckboxTile extends StatelessWidget {
  const _SettingsCheckboxTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.toolbarItem,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
              activeColor: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SettingsText(title: title, subtitle: subtitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SettingsText(title: title, subtitle: subtitle),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _DangerActionTile extends StatelessWidget {
  const _DangerActionTile({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SettingsText(title: title, subtitle: subtitle),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accentLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _SettingsText extends StatelessWidget {
  const _SettingsText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}
