import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../window/window_resize_edge.dart';

class WindowResizeFrame extends StatelessWidget {
  const WindowResizeFrame({
    required this.enabled,
    required this.onResizeStart,
    required this.child,
    super.key,
  });

  static const double _edgeSize = 6;
  static const double _cornerSize = 18;

  final bool enabled;
  final ValueChanged<WindowResizeEdge> onResizeStart;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled
                    ? AppColors.line.withValues(alpha: 0.9)
                    : Colors.transparent,
              ),
            ),
            child: child,
          ),
        ),
        if (enabled) ..._resizeHandles(),
      ],
    );
  }

  List<Widget> _resizeHandles() {
    return [
      _ResizeHandle(
        edge: WindowResizeEdge.top,
        cursor: SystemMouseCursors.resizeUpDown,
        onResizeStart: onResizeStart,
        left: _cornerSize,
        right: _cornerSize,
        top: 0,
        height: _edgeSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.bottom,
        cursor: SystemMouseCursors.resizeUpDown,
        onResizeStart: onResizeStart,
        left: _cornerSize,
        right: _cornerSize,
        bottom: 0,
        height: _edgeSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.left,
        cursor: SystemMouseCursors.resizeLeftRight,
        onResizeStart: onResizeStart,
        left: 0,
        top: _cornerSize,
        bottom: _cornerSize,
        width: _edgeSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.right,
        cursor: SystemMouseCursors.resizeLeftRight,
        onResizeStart: onResizeStart,
        right: 0,
        top: _cornerSize,
        bottom: _cornerSize,
        width: _edgeSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.topLeft,
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        onResizeStart: onResizeStart,
        left: 0,
        top: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.topRight,
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        onResizeStart: onResizeStart,
        right: 0,
        top: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.bottomLeft,
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        onResizeStart: onResizeStart,
        left: 0,
        bottom: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
      _ResizeHandle(
        edge: WindowResizeEdge.bottomRight,
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        onResizeStart: onResizeStart,
        right: 0,
        bottom: 0,
        width: _cornerSize,
        height: _cornerSize,
      ),
    ];
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.edge,
    required this.cursor,
    required this.onResizeStart,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
  });

  final WindowResizeEdge edge;
  final MouseCursor cursor;
  final ValueChanged<WindowResizeEdge> onResizeStart;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onResizeStart(edge),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
