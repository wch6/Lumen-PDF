import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

class PageExportDialog extends StatefulWidget {
  const PageExportDialog({
    required this.pageNumber,
    required this.initialOptions,
    super.key,
  });

  final int pageNumber;
  final PageExportOptions initialOptions;

  @override
  State<PageExportDialog> createState() => _PageExportDialogState();
}

class _PageExportDialogState extends State<PageExportDialog> {
  late int _resolution = widget.initialOptions.resolution;
  late ExportImageFormat _format = widget.initialOptions.format;
  late String? _folder = widget.initialOptions.folder;
  late final TextEditingController _patternController = TextEditingController(
    text: widget.initialOptions.namePattern,
  );

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _chooseFolder() async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: '选择导出文件夹',
      initialDirectory: _folder,
      lockParentWindow: true,
    );
    if (folder != null) {
      setState(() => _folder = folder);
    }
  }

  void _submit() {
    final pattern = _patternController.text.trim().isEmpty
        ? '{document}_P{page}'
        : _patternController.text.trim();
    Navigator.of(context).pop(
      PageExportOptions(
        resolution: _resolution.clamp(72, 600),
        format: _format,
        namePattern: pattern,
        folder: _folder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '导出第 ${widget.pageNumber} 页',
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
                ],
              ),
              const SizedBox(height: 14),
              _ExportFieldGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('图片分辨率'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 132,
                          child: TextFormField(
                            initialValue: '$_resolution',
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null) {
                                _resolution = parsed.clamp(72, 600);
                              }
                            },
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _fieldDecoration(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '像素/英寸',
                          style: TextStyle(
                            color: AppColors.subtle,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 22),
                        SizedBox(
                          width: 126,
                          child: DropdownButtonFormField<ExportImageFormat>(
                            initialValue: _format,
                            items: [
                              for (final item in ExportImageFormat.values)
                                DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _format = value);
                              }
                            },
                            dropdownColor: AppColors.surface,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _fieldDecoration(labelText: '格式'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ExportFieldGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('命名格式'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _patternController,
                      style: TextStyle(color: AppColors.ink, fontSize: 13),
                      decoration: _fieldDecoration(
                        hintText: '{document}_P{page}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '可用占位符：{document}、{page}、{page2}、{page3}、{date}',
                      style: TextStyle(color: AppColors.subtle, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ExportFieldGroup(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _folder ?? '未设置导出文件夹，导出时会弹出保存窗口',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.subtle, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _chooseFolder,
                      child: const Text('选择文件夹'),
                    ),
                    if (_folder != null)
                      TextButton(
                        onPressed: () => setState(() => _folder = null),
                        child: const Text('清除'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('导出'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportFieldGroup extends StatelessWidget {
  const _ExportFieldGroup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
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
  );
}
