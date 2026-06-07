import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Future<T?> showThemedContextMenu<T>({
  required BuildContext context,
  required Offset position,
  required List<PopupMenuEntry<T>> items,
  double minWidth = 132,
  double maxWidth = 210,
}) {
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 10,
    shadowColor: Colors.black.withValues(alpha: 0.18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.line),
    ),
    menuPadding: const EdgeInsets.symmetric(vertical: 4),
    items: items,
  );
}

PopupMenuItem<T> themedContextMenuItem<T>({
  required T value,
  required String label,
  bool danger = false,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: 38,
    padding: EdgeInsets.zero,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: danger ? AppColors.danger : AppColors.ink,
            fontSize: 14,
            fontWeight: danger ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

PopupMenuDivider themedContextMenuDivider<T>() {
  return PopupMenuDivider(height: 5, color: AppColors.line);
}
