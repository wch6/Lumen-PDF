import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

enum _SettingsSection {
  general,
  shortcuts,
  documentTranslation,
  selectionTranslation,
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    required this.settings,
    required this.nightMode,
    required this.systemResolution,
    required this.onSettingsChanged,
    required this.onNightModeChanged,
    required this.onShortcutChanged,
    required this.onClearSoftwareCache,
    required this.onClearAllFileData,
    required this.onClearSelectedFileData,
    required this.onLoadFileData,
    super.key,
  });

  final ReaderSettings settings;
  final bool nightMode;
  final int systemResolution;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final ValueChanged<bool> onNightModeChanged;
  final void Function(
    ReaderShortcutAction action,
    ReaderShortcutBinding binding,
  )
  onShortcutChanged;
  final Future<void> Function() onClearSoftwareCache;
  final Future<void> Function() onClearAllFileData;
  final Future<void> Function(Set<String> hashes) onClearSelectedFileData;
  final Future<List<FileDataSummary>> Function() onLoadFileData;

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

  void _setRememberWindowSize(bool value) {
    _emitSettings(_settings.copyWith(rememberWindowSize: value));
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

  void _setPdf2zhServiceUrl(String value) {
    _emitSettings(_settings.copyWith(pdf2zhServiceUrl: value.trim()));
  }

  void _setPdf2zhEngine(String value) {
    _emitSettings(_settings.copyWith(pdf2zhEngine: value));
  }

  void _setPdf2zhService(String value) {
    _emitSettings(_settings.copyWith(pdf2zhService: value.trim()));
  }

  void _setPdf2zhNextService(String value) {
    _emitSettings(_settings.copyWith(pdf2zhNextService: value.trim()));
  }

  void _setPdf2zhSourceLanguage(String value) {
    _emitSettings(_settings.copyWith(pdf2zhSourceLanguage: value.trim()));
  }

  void _setPdf2zhTargetLanguage(String value) {
    _emitSettings(_settings.copyWith(pdf2zhTargetLanguage: value.trim()));
  }

  void _setPdf2zhThreadCount(int value) {
    _emitSettings(_settings.copyWith(pdf2zhThreadCount: value));
  }

  void _setPdf2zhQps(int value) {
    _emitSettings(_settings.copyWith(pdf2zhQps: value));
  }

  void _setPdf2zhSkipLastPages(int value) {
    _emitSettings(_settings.copyWith(pdf2zhSkipLastPages: value));
  }

  void _setPdf2zhPoolSize(int value) {
    _emitSettings(_settings.copyWith(pdf2zhPoolSize: value));
  }

  void _setPdf2zhRename(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhRename: value));
  }

  void _setPdf2zhSkipSubsetFonts(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhSkipSubsetFonts: value));
  }

  void _setPdf2zhBabeldoc(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhBabeldoc: value));
  }

  void _setPdf2zhFontFamily(String value) {
    _emitSettings(_settings.copyWith(pdf2zhFontFamily: value.trim()));
  }

  void _setPdf2zhDualMode(String value) {
    _emitSettings(_settings.copyWith(pdf2zhDualMode: value));
  }

  void _setPdf2zhTransFirst(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhTransFirst: value));
  }

  void _setPdf2zhOcr(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhOcr: value));
  }

  void _setPdf2zhAutoOcr(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhAutoOcr: value));
  }

  void _setPdf2zhNoWatermark(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhNoWatermark: value));
  }

  void _setPdf2zhEnhanceCompatibility(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhEnhanceCompatibility: value));
  }

  void _setPdf2zhTranslateTableText(bool value) {
    _emitSettings(_settings.copyWith(pdf2zhTranslateTableText: value));
  }

  void _setSelectionTranslateService(String value) {
    _emitSettings(_settings.copyWith(selectionTranslateService: value));
  }

  void _setSelectionTranslateSourceLanguage(String value) {
    _emitSettings(
      _settings.copyWith(selectionTranslateSourceLanguage: value.trim()),
    );
  }

  void _setSelectionTranslateTargetLanguage(String value) {
    _emitSettings(
      _settings.copyWith(selectionTranslateTargetLanguage: value.trim()),
    );
  }

  void _setSelectionTranslatePopup(bool value) {
    _emitSettings(_settings.copyWith(selectionTranslatePopup: value));
  }

  void _setSelectionTranslateAutoDetectLanguage(bool value) {
    _emitSettings(
      _settings.copyWith(selectionTranslateAutoDetectLanguage: value),
    );
  }

  void _setSelectionTranslateSecret(String value) {
    _setSelectionTranslateSecretFor(_settings.selectionTranslateService, value);
  }

  void _setSelectionTranslateEndpoint(String value) {
    _emitSettings(_settings.copyWith(selectionTranslateEndpoint: value.trim()));
  }

  void _setSelectionTranslateSecretFor(String service, String value) {
    final next = Map<String, String>.from(_settings.selectionTranslateSecrets);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      next.remove(service);
    } else {
      next[service] = trimmed;
    }
    _emitSettings(_settings.copyWith(selectionTranslateSecrets: next));
  }

  Future<void> _openSelectionTranslateConfig() async {
    final service = _settings.selectionTranslateService;
    if (!_requiresTranslateSecret(service)) {
      return;
    }
    final secret = await showDialog<String>(
      context: context,
      builder: (context) => _SelectionApiConfigDialog(
        service: service,
        secret: _settings.selectionTranslateSecretFor(service),
      ),
    );
    if (secret != null) {
      _setSelectionTranslateSecretFor(service, secret);
    }
  }

  bool _requiresTranslateSecret(String service) {
    return const {'baidu', 'aliyun', 'tencent'}.contains(service);
  }

  String _translateServiceLabel(String service) {
    return const {
          'youdao': '有道',
          'bing': '必应',
          'cnki': 'CNKI',
          'google': 'Google',
          'haici': '海词',
          'huoshanweb': '火山网页翻译',
          'tencenttransmart': '腾讯TranSmart',
          'deeplx': 'DeepLX',
          'baidu': '百度(API)',
          'aliyun': '阿里(API)',
          'tencent': '腾讯(API)',
        }[service] ??
        service;
  }

  void _setSelectionDictionaryEnabled(bool value) {
    _emitSettings(_settings.copyWith(selectionDictionaryEnabled: value));
  }

  void _setSelectionDictionaryService(String value) {
    _emitSettings(_settings.copyWith(selectionDictionaryService: value));
  }

  void _setSelectionDictionarySecret(String value) {
    _emitSettings(_settings.copyWith(selectionDictionarySecret: value.trim()));
  }

  void _setSelectionShowPronunciation(bool value) {
    _emitSettings(_settings.copyWith(selectionShowPronunciation: value));
  }

  void _setSelectionAutoPlayPronunciation(String value) {
    final mode = PronunciationAutoPlay.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PronunciationAutoPlay.off,
    );
    _emitSettings(_settings.copyWith(selectionAutoPlayPronunciation: mode));
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

  Future<void> _confirmClearSoftwareCache() async {
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
    await widget.onClearSoftwareCache();
    if (mounted) {
      setState(() => _settings = const ReaderSettings());
    }
  }

  Future<void> _confirmClearAllFileData() async {
    final confirmed = await _confirmDanger(
      title: '清除全部文件数据',
      body: '将删除所有 PDF 的阅读记录、便签、高亮和批注。最近文件列表会保留路径，但会清空与文件哈希关联的进度数据。',
      confirmLabel: '清除全部',
    );
    if (confirmed) {
      await widget.onClearAllFileData();
    }
  }

  Future<void> _chooseFileDataToClear() async {
    final items = await widget.onLoadFileData();
    if (!mounted) {
      return;
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _FileDataSelectionDialog(items: items),
    );
    if (selected != null && selected.isNotEmpty) {
      await widget.onClearSelectedFileData(selected);
    }
  }

  Future<bool> _confirmDanger({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title, style: TextStyle(color: AppColors.ink)),
          content: Text(
            body,
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
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setTheme(nightMode: _nightMode, accentChoice: _settings.accent);
    final baseTheme = Theme.of(context);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: _nightMode ? Brightness.dark : Brightness.light,
      surface: AppColors.surface,
    );
    final settingsTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: colorScheme,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.accentSoft,
          disabledForegroundColor: AppColors.subtle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accentLine),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent;
          }
          return AppColors.accentLine;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentSoft;
          }
          return AppColors.accentSoft.withValues(alpha: 0.64);
        }),
        trackOutlineColor: WidgetStatePropertyAll(AppColors.accentLine),
      ),
    );
    return Theme(
      data: settingsTheme,
      child: Dialog(
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
                          _SettingsNavItem(
                            icon: Icons.picture_as_pdf_rounded,
                            label: '文档翻译',
                            selected:
                                _section ==
                                _SettingsSection.documentTranslation,
                            onTap: () => setState(
                              () => _section =
                                  _SettingsSection.documentTranslation,
                            ),
                          ),
                          _SettingsNavItem(
                            icon: Icons.translate_rounded,
                            label: '划词翻译',
                            selected:
                                _section ==
                                _SettingsSection.selectionTranslation,
                            onTap: () => setState(
                              () => _section =
                                  _SettingsSection.selectionTranslation,
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
                        _SettingsSection.documentTranslation =>
                          _buildDocumentTranslationSettings(),
                        _SettingsSection.selectionTranslation =>
                          _buildSelectionTranslationSettings(),
                      },
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

  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 28),
      children: [
        _SectionTitle('主题'),
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
          title: '记忆窗口大小',
          subtitle: '开启后，下次启动会恢复上次关闭前的软件窗口大小。',
          value: _settings.rememberWindowSize,
          onChanged: _setRememberWindowSize,
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
        _ResolutionTile(
          settings: _settings,
          systemResolution: widget.systemResolution,
          onModeChanged: _setResolutionMode,
        ),
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
        const _SectionTitle('维护'),
        const SizedBox(height: 14),
        _DangerActionTile(
          title: '清除软件缓存',
          subtitle: '仅清除软件设置和最近文件列表，不删除任何 PDF 文件，也不删除 PDF 对应的便签、高亮和批注。',
          buttonLabel: '清除',
          onPressed: _confirmClearSoftwareCache,
        ),
        const SizedBox(height: 12),
        _DangerActionTile(
          title: '清除全部文件数据',
          subtitle: '删除全部 PDF 的阅读记录、便签、高亮和批注；最近文件路径会保留，但不再关联旧哈希。',
          buttonLabel: '全部',
          onPressed: _confirmClearAllFileData,
        ),
        const SizedBox(height: 12),
        _DangerActionTile(
          title: '选择文件数据清除',
          subtitle: '按文件哈希单选、多选或全选，精确删除某些 PDF 的阅读记录和批注数据。',
          buttonLabel: '选择',
          onPressed: _chooseFileDataToClear,
        ),
      ],
    );
  }

  Widget _buildDocumentTranslationSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 28),
      children: [
        const _SectionTitle('文档翻译'),
        const SizedBox(height: 8),
        Text(
          '根据 Zotero pdf2zh 插件设置接入。本地服务默认地址为 http://localhost:8890；使用前会先检测服务是否正在运行。',
          style: TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 16),
        _TextSettingTile(
          title: 'pdf2zh 服务地址',
          subtitle: '终端运行 pdf2zh 后，右键菜单会向该本地服务发送 translate/crop/compare 请求。',
          value: _settings.pdf2zhServiceUrl,
          onChanged: _setPdf2zhServiceUrl,
        ),
        const SizedBox(height: 10),
        _ChoiceSettingTile(
          title: '引擎',
          subtitle: '对应 Zotero 插件中的 engine / engineSelect。',
          value: _settings.pdf2zhEngine,
          values: const ['pdf2zh_next', 'pdf2zh'],
          onChanged: _setPdf2zhEngine,
        ),
        const SizedBox(height: 10),
        _TextSettingTile(
          title: 'pdf2zh 1.x 翻译服务',
          subtitle: '默认 bing，对应插件 service。',
          value: _settings.pdf2zhService,
          onChanged: _setPdf2zhService,
        ),
        const SizedBox(height: 10),
        _TextSettingTile(
          title: 'pdf2zh 2.x 翻译服务',
          subtitle: '默认 siliconflowfree，对应插件 next_service。',
          value: _settings.pdf2zhNextService,
          onChanged: _setPdf2zhNextService,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TextSettingTile(
                title: '源语言',
                subtitle: 'sourceLang',
                value: _settings.pdf2zhSourceLanguage,
                onChanged: _setPdf2zhSourceLanguage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TextSettingTile(
                title: '目标语言',
                subtitle: 'targetLang',
                value: _settings.pdf2zhTargetLanguage,
                onChanged: _setPdf2zhTargetLanguage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberSettingTile(
                title: '线程数',
                subtitle: 'threadNum',
                value: _settings.pdf2zhThreadCount,
                min: 1,
                max: 32,
                onChanged: _setPdf2zhThreadCount,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberSettingTile(
                title: 'QPS',
                subtitle: 'qps',
                value: _settings.pdf2zhQps,
                min: 1,
                max: 120,
                onChanged: _setPdf2zhQps,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('任务与输出'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberSettingTile(
                title: '跳过末尾页数',
                subtitle: 'skipLastPages',
                value: _settings.pdf2zhSkipLastPages,
                min: 0,
                max: 99,
                onChanged: _setPdf2zhSkipLastPages,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberSettingTile(
                title: '进程池大小',
                subtitle: 'poolSize，0 表示由服务自动决定',
                value: _settings.pdf2zhPoolSize,
                min: 0,
                max: 64,
                onChanged: _setPdf2zhPoolSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SettingsSwitchTile(
                title: '自动重命名',
                subtitle: 'rename',
                value: _settings.pdf2zhRename,
                onChanged: _setPdf2zhRename,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SettingsSwitchTile(
                title: '去水印',
                subtitle: 'noWatermark',
                value: _settings.pdf2zhNoWatermark,
                onChanged: _setPdf2zhNoWatermark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('排版与兼容'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TextSettingTile(
                title: '字体族',
                subtitle: 'fontFamily，默认 auto',
                value: _settings.pdf2zhFontFamily,
                onChanged: _setPdf2zhFontFamily,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChoiceSettingTile(
                title: '双语布局',
                subtitle: 'dualMode',
                value: _settings.pdf2zhDualMode,
                values: const ['LR', 'TB'],
                onChanged: _setPdf2zhDualMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SettingsSwitchTile(
                title: '先翻译后排版',
                subtitle: 'transFirst',
                value: _settings.pdf2zhTransFirst,
                onChanged: _setPdf2zhTransFirst,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SettingsSwitchTile(
                title: '增强兼容性',
                subtitle: 'enhanceCompatibility',
                value: _settings.pdf2zhEnhanceCompatibility,
                onChanged: _setPdf2zhEnhanceCompatibility,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SettingsSwitchTile(
                title: '跳过子集字体',
                subtitle: 'skipSubsetFonts',
                value: _settings.pdf2zhSkipSubsetFonts,
                onChanged: _setPdf2zhSkipSubsetFonts,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SettingsSwitchTile(
                title: 'BabelDOC',
                subtitle: 'babeldoc',
                value: _settings.pdf2zhBabeldoc,
                onChanged: _setPdf2zhBabeldoc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('OCR 与表格'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SettingsSwitchTile(
                title: '启用 OCR',
                subtitle: 'ocr',
                value: _settings.pdf2zhOcr,
                onChanged: _setPdf2zhOcr,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SettingsSwitchTile(
                title: '自动 OCR',
                subtitle: 'autoOcr',
                value: _settings.pdf2zhAutoOcr,
                onChanged: _setPdf2zhAutoOcr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SettingsSwitchTile(
          title: '翻译表格文本',
          subtitle: 'translateTableText',
          value: _settings.pdf2zhTranslateTableText,
          onChanged: _setPdf2zhTranslateTableText,
        ),
      ],
    );
  }

  Widget _buildSelectionTranslationSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 28),
      children: [
        const _SectionTitle('\u5212\u8bcd\u7ffb\u8bd1'),
        const SizedBox(height: 8),
        Text(
          '\u53c2\u8003 Translate for Zotero \u7684\u670d\u52a1\u7ec4\u7ec7\u65b9\u5f0f\u3002\u9009\u4e2d PDF \u6587\u672c\u540e\u53ef\u7ffb\u8bd1\uff1b\u82f1\u6587\u5355\u8bcd\u548c\u77ed\u8bed\u4f1a\u540c\u65f6\u67e5\u8be2\u8bcd\u5178\u3001\u97f3\u6807\u548c\u82f1\u7f8e\u53d1\u97f3\u3002',
          style: TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 16),
        _ChoiceSettingTile(
          title: '\u7ffb\u8bd1\u670d\u52a1',
          subtitle:
              '\u7528\u4e8e\u53e5\u5b50\u548c\u6bb5\u843d\u7ffb\u8bd1\uff1b\u77ed\u8bcd\u4ecd\u4f1a\u989d\u5916\u67e5\u8be2\u4e0b\u65b9\u7684\u8bcd\u5178\u670d\u52a1\u3002',
          value: _settings.selectionTranslateService,
          values: const [
            'youdao',
            'bing',
            'cnki',
            'google',
            'haici',
            'huoshanweb',
            'tencenttransmart',
            'deeplx',
            'baidu',
            'aliyun',
            'tencent',
          ],
          labels: const {
            'youdao': '\u6709\u9053',
            'bing': '\u5fc5\u5e94',
            'cnki': 'CNKI',
            'google': 'Google',
            'haici': '\u6d77\u8bcd',
            'huoshanweb': '\u706b\u5c71\u7f51\u9875\u7ffb\u8bd1',
            'tencenttransmart': '\u817e\u8baf TranSmart',
            'deeplx': 'DeepLX',
            'baidu': '\u767e\u5ea6(API)',
            'aliyun': '\u963f\u91cc(API)',
            'tencent': '\u817e\u8baf(API)',
          },
          onChanged: _setSelectionTranslateService,
        ),
        const SizedBox(height: 10),
        _SettingsSwitchTile(
          title: '\u81ea\u52a8\u68c0\u6d4b\u6e90\u8bed\u8a00',
          subtitle:
              '\u5f00\u542f\u540e\u5ffd\u7565\u6e90\u8bed\u8a00\u8f93\u5165\uff0c\u7531\u7ffb\u8bd1\u670d\u52a1\u81ea\u52a8\u5224\u65ad\u539f\u6587\u8bed\u8a00\u3002',
          value: _settings.selectionTranslateAutoDetectLanguage,
          onChanged: _setSelectionTranslateAutoDetectLanguage,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TextSettingTile(
                title: '\u6e90\u8bed\u8a00',
                subtitle:
                    '\u4f8b\u5982 en-US\uff1b\u81ea\u52a8\u68c0\u6d4b\u5f00\u542f\u65f6\u53ef\u4fdd\u6301\u9ed8\u8ba4\u3002',
                value: _settings.selectionTranslateSourceLanguage,
                onChanged: _setSelectionTranslateSourceLanguage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TextSettingTile(
                title: '\u76ee\u6807\u8bed\u8a00',
                subtitle:
                    '\u4f8b\u5982 zh-CN\uff0c\u7528\u4e8e\u7ffb\u8bd1\u7ed3\u679c\u548c\u5251\u6865\u8bcd\u5178\u76ee\u6807\u8bed\u3002',
                value: _settings.selectionTranslateTargetLanguage,
                onChanged: _setSelectionTranslateTargetLanguage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SettingsSwitchTile(
          title: '\u542f\u7528\u5212\u8bcd\u5f39\u7a97',
          subtitle:
              '\u5173\u95ed\u540e\u4e0d\u5f39\u51fa\u6d88\u606f\u63d0\u793a\uff0c\u7ffb\u8bd1\u4e0e\u8bcd\u5178\u7ed3\u679c\u4ecd\u663e\u793a\u5728\u4fa7\u680f\u3002',
          value: _settings.selectionTranslatePopup,
          onChanged: _setSelectionTranslatePopup,
        ),
        const SizedBox(height: 10),
        _SelectionApiSecretTile(
          serviceLabel: _translateServiceLabel(
            _settings.selectionTranslateService,
          ),
          requiresSecret: _requiresTranslateSecret(
            _settings.selectionTranslateService,
          ),
          value: _settings.selectionTranslateSecretFor(
            _settings.selectionTranslateService,
          ),
          onChanged: _setSelectionTranslateSecret,
          onConfigure: _openSelectionTranslateConfig,
        ),
        const SizedBox(height: 10),
        _TextSettingTile(
          title: '\u81ea\u5b9a\u4e49\u670d\u52a1\u5730\u5740',
          subtitle:
              'DeepLX \u7b49\u517c\u5bb9\u63a5\u53e3\u5730\u5740\uff0c\u4f8b\u5982 http://127.0.0.1:1188/translate\u3002',
          value: _settings.selectionTranslateEndpoint,
          onChanged: _setSelectionTranslateEndpoint,
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 24),
        const _SectionTitle('\u5b57\u5178\u670d\u52a1'),
        const SizedBox(height: 14),
        _SettingsSwitchTile(
          title: '\u4f7f\u7528\u5b57\u5178\u670d\u52a1\u7ffb\u8bd1\u8bcd\u8bed',
          subtitle:
              '\u82f1\u6587\u5355\u8bcd\u6216\u77ed\u8bed\u4f1a\u8865\u5145\u8bcd\u5178\u91ca\u4e49\uff0c\u5e76\u53ea\u4fdd\u7559\u82f1\u5f0f\u3001\u7f8e\u5f0f\u4e24\u7c7b\u53d1\u97f3\u3002',
          value: _settings.selectionDictionaryEnabled,
          onChanged: _setSelectionDictionaryEnabled,
        ),
        const SizedBox(height: 10),
        _ChoiceSettingTile(
          title: '\u5b57\u5178\u670d\u52a1',
          subtitle:
              '\u7528\u4e8e\u5355\u8bcd\u91ca\u4e49\u3001\u97f3\u6807\u548c\u53d1\u97f3\uff1b\u4e0d\u540c\u670d\u52a1\u7684\u91ca\u4e49\u4f1a\u7edf\u4e00\u6574\u7406\u4e3a\u4fbf\u4e8e\u67e5\u9605\u7684\u683c\u5f0f\u3002',
          value: _settings.selectionDictionaryService,
          values: const [
            'haicidict',
            'youdaodict',
            'bingdict',
            'cambridgedict',
            'freedictionaryapi',
          ],
          labels: const {
            'haicidict': '\u6d77\u8bcd\u8bcd\u5178(en->zh)',
            'youdaodict': '\u6709\u9053\u8bcd\u5178(en->zh)',
            'bingdict': '\u5fc5\u5e94\u8bcd\u5178(en->zh)',
            'cambridgedict': '\u5251\u6865\u8bcd\u5178(en->other)',
            'freedictionaryapi': 'FreeDictionaryAPI(en->en)',
          },
          onChanged: _setSelectionDictionaryService,
        ),
        const SizedBox(height: 10),
        _TextSettingTile(
          title: '\u5b57\u5178\u5bc6\u94a5',
          subtitle:
              '\u5f53\u524d\u5185\u7f6e\u8bcd\u5178\u65e0\u9700\u586b\u5199\uff1b\u540e\u7eed\u63a5\u5165\u79c1\u6709\u8bcd\u5178\u670d\u52a1\u65f6\u4f7f\u7528\u3002',
          value: _settings.selectionDictionarySecret,
          onChanged: _setSelectionDictionarySecret,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SettingsSwitchTile(
                title: '\u663e\u793a\u53d1\u97f3\u6309\u94ae',
                subtitle: '',
                value: _settings.selectionShowPronunciation,
                onChanged: _setSelectionShowPronunciation,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChoiceSettingTile(
                title: '\u81ea\u52a8\u64ad\u653e\u53d1\u97f3',
                subtitle: '',
                value: _settings.selectionAutoPlayPronunciation.name,
                values: const ['us', 'off', 'uk'],
                labels: const {
                  'us': '\u7f8e\u5f0f',
                  'off': '\u5173\u95ed',
                  'uk': '\u82f1\u5f0f',
                },
                controlWidth: 132,
                onChanged: _setSelectionAutoPlayPronunciation,
              ),
            ),
          ],
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
          '点击“录入”后按下新的组合键。建议保留 Ctrl+F 搜索、Esc 清除/隐藏侧边栏、Ctrl+O 打开文件、Ctrl+Tab 最近文件、Ctrl+H 高亮颜色、Ctrl+L 资料库、Ctrl+T 缩略图、Shift+Tab 单/双页缩略图、Ctrl+B 目录、Ctrl+N 笔记、Ctrl+\' 设置、Ctrl+W 适合宽度、Ctrl+P 适合页面。',
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

class _SelectionApiConfigDialog extends StatefulWidget {
  const _SelectionApiConfigDialog({
    required this.service,
    required this.secret,
  });

  final String service;
  final String secret;

  @override
  State<_SelectionApiConfigDialog> createState() =>
      _SelectionApiConfigDialogState();
}

class _SelectionApiConfigDialogState extends State<_SelectionApiConfigDialog> {
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final parts = widget.secret.split('#');
    TextEditingController controller(String key, [String fallback = '']) {
      final index = _fieldKeys.indexOf(key);
      final value =
          index >= 0 && index < parts.length && parts[index].isNotEmpty
          ? parts[index]
          : fallback;
      return TextEditingController(text: value);
    }

    for (final entry in _fieldDefaults.entries) {
      _controllers[entry.key] = controller(entry.key, entry.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _fieldKeys {
    return switch (widget.service) {
      'baidu' => const ['appid', 'key', 'action'],
      'aliyun' => const ['accessKeyId', 'accessKeySecret', 'endpoint'],
      'tencent' => const [
        'secretId',
        'secretKey',
        'region',
        'projectId',
        'termRepoIds',
        'sentRepoIds',
      ],
      _ => const [],
    };
  }

  Map<String, String> get _fieldDefaults {
    return switch (widget.service) {
      'baidu' => const {'appid': '', 'key': '', 'action': '0'},
      'aliyun' => const {
        'accessKeyId': '',
        'accessKeySecret': '',
        'endpoint': 'https://mt.aliyuncs.com/',
      },
      'tencent' => const {
        'secretId': '',
        'secretKey': '',
        'region': 'ap-shanghai',
        'projectId': '0',
        'termRepoIds': '',
        'sentRepoIds': '',
      },
      _ => const {},
    };
  }

  String get _serviceLabel {
    return const {
          'baidu': '百度',
          'aliyun': '阿里',
          'tencent': '腾讯',
        }[widget.service] ??
        widget.service;
  }

  String _fieldLabel(String key) {
    return const {
          'appid': 'AppID',
          'key': 'Key',
          'action': 'Action',
          'accessKeyId': 'AccessKey ID',
          'accessKeySecret': 'AccessKey Secret',
          'endpoint': 'Endpoint',
          'secretId': 'SecretId',
          'secretKey': 'SecretKey',
          'region': 'Region',
          'projectId': 'ProjectId',
          'termRepoIds': '术语库 ID',
          'sentRepoIds': '句库 ID',
          'apiKey': 'API Key',
          'glossaryId': 'Glossary ID',
        }[key] ??
        key;
  }

  String _fieldHint(String key) {
    return const {
          'action': '默认 0',
          'endpoint': '默认 https://mt.aliyuncs.com/',
          'region': '默认 ap-shanghai',
          'projectId': '默认 0',
          'termRepoIds': '多个 ID 用英文逗号分隔',
          'sentRepoIds': '多个 ID 用英文逗号分隔',
          'glossaryId': '可选',
        }[key] ??
        '';
  }

  bool _obscure(String key) {
    return const {
      'key',
      'accessKeySecret',
      'secretKey',
      'apiKey',
    }.contains(key);
  }

  void _save() {
    final values = [
      for (final key in _fieldKeys) _controllers[key]?.text.trim() ?? '',
    ];
    while (values.isNotEmpty && values.last.isEmpty) {
      values.removeLast();
    }
    Navigator.of(context).pop(values.join('#'));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('$_serviceLabel 配置', style: TextStyle(color: AppColors.ink)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final key in _fieldKeys) ...[
                TextFormField(
                  controller: _controllers[key],
                  obscureText: _obscure(key),
                  style: TextStyle(color: AppColors.ink),
                  decoration: _fieldDecoration(
                    labelText: _fieldLabel(key),
                    hintText: _fieldHint(key),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('保存'),
        ),
      ],
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
  const _ResolutionTile({
    required this.settings,
    required this.systemResolution,
    required this.onModeChanged,
  });

  final ReaderSettings settings;
  final int systemResolution;
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
                  '${ReaderSettings.normalizedSystemResolution(systemResolution)}',
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
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.subtle,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionApiSecretTile extends StatelessWidget {
  const _SelectionApiSecretTile({
    required this.serviceLabel,
    required this.requiresSecret,
    required this.value,
    required this.onChanged,
    required this.onConfigure,
  });

  final String serviceLabel;
  final bool requiresSecret;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final subtitle = requiresSecret
        ? '当前为 $serviceLabel 单独保存密钥。可直接粘贴 Zotero 格式，也可点配置分项填写。'
        : '当前服务无需密钥。切换到百度、阿里、腾讯或 DeepL API 后会显示对应配置。';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsText(title: 'API 配置', subtitle: subtitle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey(
                    'translate-secret-$serviceLabel-${value.hashCode}',
                  ),
                  enabled: requiresSecret,
                  initialValue: value,
                  onChanged: onChanged,
                  style: TextStyle(color: AppColors.ink, fontSize: 13),
                  decoration: _fieldDecoration(
                    hintText: requiresSecret ? '密钥信息' : '无需密钥',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: requiresSecret ? onConfigure : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.line,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('配置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextSettingTile extends StatelessWidget {
  const _TextSettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsText(title: title, subtitle: subtitle),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('$title-$value'),
            initialValue: value,
            onChanged: onChanged,
            style: TextStyle(color: AppColors.ink, fontSize: 13),
            decoration: _fieldDecoration(),
          ),
        ],
      ),
    );
  }
}

class _ChoiceSettingTile extends StatelessWidget {
  const _ChoiceSettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labels = const {},
    this.controlWidth = 190,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final Map<String, String> labels;
  final double controlWidth;

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
            width: controlWidth,
            child: DropdownButtonFormField<String>(
              initialValue: values.contains(value) ? value : values.first,
              items: [
                for (final item in values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(labels[item] ?? item),
                  ),
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
                fontSize: 13,
              ),
              decoration: _fieldDecoration(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberSettingTile extends StatelessWidget {
  const _NumberSettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsText(title: title, subtitle: subtitle),
          const SizedBox(height: 10),
          _NumberField(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FileDataSelectionDialog extends StatefulWidget {
  const _FileDataSelectionDialog({required this.items});

  final List<FileDataSummary> items;

  @override
  State<_FileDataSelectionDialog> createState() =>
      _FileDataSelectionDialogState();
}

class _FileDataSelectionDialogState extends State<_FileDataSelectionDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.items.isNotEmpty && _selected.length == widget.items.length;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('选择文件数据', style: TextStyle(color: AppColors.ink)),
      content: SizedBox(
        width: 560,
        height: 420,
        child: widget.items.isEmpty
            ? Center(
                child: Text(
                  '暂无可清除的文件数据',
                  style: TextStyle(color: AppColors.subtle),
                ),
              )
            : Column(
                children: [
                  CheckboxListTile(
                    value: allSelected,
                    onChanged: (value) {
                      setState(() {
                        _selected.clear();
                        if (value == true) {
                          _selected.addAll(
                            widget.items.map((item) => item.hash),
                          );
                        }
                      });
                    },
                    title: Text('全选', style: TextStyle(color: AppColors.ink)),
                    activeColor: AppColors.accent,
                  ),
                  Divider(height: 1, color: AppColors.line),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final selected = _selected.contains(item.hash);
                        return CheckboxListTile(
                          value: selected,
                          activeColor: AppColors.accent,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(item.hash);
                              } else {
                                _selected.remove(item.hash);
                              }
                            });
                          },
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${item.type} · ${item.hash}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.of(_selected)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.surface,
          ),
          child: const Text('清除选中'),
        ),
      ],
    );
  }
}
