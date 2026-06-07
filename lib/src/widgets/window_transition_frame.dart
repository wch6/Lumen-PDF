import 'dart:math' as math;

import 'package:flutter/material.dart';

enum WindowTransitionKind { resize, minimize }

class WindowTransitionFrame extends StatefulWidget {
  const WindowTransitionFrame({
    required this.trigger,
    required this.kind,
    required this.child,
    super.key,
  });

  static const minimizeLeadDuration = Duration(milliseconds: 85);

  final int trigger;
  final WindowTransitionKind kind;
  final Widget child;

  @override
  State<WindowTransitionFrame> createState() => _WindowTransitionFrameState();
}

class _WindowTransitionFrameState extends State<WindowTransitionFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..value = 1;
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant WindowTransitionFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final progress = _curve.value;
        final settle = 1 - progress;
        final minimizePulse = math.sin(progress * math.pi);
        final scale = switch (widget.kind) {
          WindowTransitionKind.resize => 1 - settle * 0.008,
          WindowTransitionKind.minimize => 1 - minimizePulse * 0.025,
        };
        final opacity = switch (widget.kind) {
          WindowTransitionKind.resize => 1 - settle * 0.035,
          WindowTransitionKind.minimize => 1 - minimizePulse * 0.12,
        };
        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            filterQuality: FilterQuality.low,
            child: child,
          ),
        );
      },
    );
  }
}
