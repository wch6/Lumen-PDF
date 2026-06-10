import 'package:flutter/material.dart';

import '../models/reader_models.dart';
import '../theme/app_colors.dart';

class PdfFirstPagePreview extends StatelessWidget {
  const PdfFirstPagePreview({
    required this.preview,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.padding = 4,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    super.key,
  });

  final PdfFirstPagePreviewData? preview;
  final double width;
  final double height;
  final double borderRadius;
  final double padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = this.iconColor ?? AppColors.accent;
    final preview = this.preview;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.toolbarItem,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: preview == null
          ? _PdfPreviewPlaceholder(iconColor: iconColor)
          : Padding(
              padding: EdgeInsets.all(padding),
              child: Image.memory(
                preview.pngBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
    );
  }
}

class _PdfPreviewPlaceholder extends StatelessWidget {
  const _PdfPreviewPlaceholder({required this.iconColor});

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.picture_as_pdf_outlined, color: iconColor, size: 28),
    );
  }
}
