import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

const double kPageSeparatorExtent = 1;

PdfPageLayout continuousPageLayout(
  List<PdfPage> pages,
  PdfViewerParams params,
) {
  final width = pages.fold(0.0, (value, page) => math.max(value, page.width));
  final pageLayouts = <Rect>[];
  var y = 0.0;

  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    pageLayouts.add(
      Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height),
    );
    y += page.height;
    if (index < pages.length - 1) {
      y += kPageSeparatorExtent;
    }
  }

  return PdfPageLayout(pageLayouts: pageLayouts, documentSize: Size(width, y));
}

class VelocityScrollInteractionDelegateProvider
    extends PdfViewerScrollInteractionDelegateProvider {
  const VelocityScrollInteractionDelegateProvider({
    this.panFriction = 15,
    this.zoomFriction = 14,
    this.velocityScale = 900,
    this.maxVelocityMultiplier = 3.4,
  });

  final double panFriction;
  final double zoomFriction;
  final double velocityScale;
  final double maxVelocityMultiplier;

  @override
  PdfViewerScrollInteractionDelegate create() {
    return _VelocityScrollInteractionDelegate(
      panFriction: panFriction,
      zoomFriction: zoomFriction,
      velocityScale: velocityScale,
      maxVelocityMultiplier: maxVelocityMultiplier,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VelocityScrollInteractionDelegateProvider &&
        other.panFriction == panFriction &&
        other.zoomFriction == zoomFriction &&
        other.velocityScale == velocityScale &&
        other.maxVelocityMultiplier == maxVelocityMultiplier;
  }

  @override
  int get hashCode {
    return Object.hash(
      panFriction,
      zoomFriction,
      velocityScale,
      maxVelocityMultiplier,
    );
  }
}

class _VelocityScrollInteractionDelegate
    implements PdfViewerScrollInteractionDelegate {
  _VelocityScrollInteractionDelegate({
    required this.panFriction,
    required this.zoomFriction,
    required this.velocityScale,
    required this.maxVelocityMultiplier,
  });

  final double panFriction;
  final double zoomFriction;
  final double velocityScale;
  final double maxVelocityMultiplier;

  PdfViewerController? _controller;
  TickerProvider? _vsync;
  Ticker? _panTicker;
  Ticker? _zoomTicker;
  Offset? _panTarget;
  Offset? _lastFocalPoint;
  double? _zoomTarget;
  DateTime? _lastWheelTime;
  Duration? _lastPanFrameTime;
  Duration? _lastZoomFrameTime;

  @override
  void init(PdfViewerController controller, TickerProvider vsync) {
    _controller = controller;
    _vsync = vsync;
  }

  @override
  void dispose() {
    stop();
    _controller = null;
    _vsync = null;
  }

  @override
  void stop() {
    _panTicker?.dispose();
    _panTicker = null;
    _panTarget = null;
    _lastPanFrameTime = null;

    _zoomTicker?.dispose();
    _zoomTicker = null;
    _zoomTarget = null;
    _lastZoomFrameTime = null;
  }

  @override
  void pan(Offset delta, PdfViewerLayoutMetrics layoutMetrics) {
    final controller = _controller;
    final vsync = _vsync;
    if (controller == null || !controller.isReady || vsync == null) {
      return;
    }

    _zoomTicker?.dispose();
    _zoomTicker = null;
    _zoomTarget = null;

    if (delta.dx.abs() > delta.dy.abs()) {
      _panTicker?.dispose();
      _panTicker = null;
      _panTarget = null;
      _lastPanFrameTime = null;
      final next = controller.value.clone()
        ..translateByDouble(delta.dx, delta.dy, 0, 1);
      controller.value = controller.makeMatrixInSafeRange(
        next,
        forceClamp: true,
      );
      return;
    }

    final now = DateTime.now();
    final elapsed = _lastWheelTime == null
        ? const Duration(milliseconds: 80)
        : now.difference(_lastWheelTime!);
    _lastWheelTime = now;

    if (_panTarget == null || elapsed > const Duration(milliseconds: 180)) {
      final translation = controller.value.getTranslation();
      _panTarget = Offset(translation.x, translation.y);
    }

    final dt = math.max(elapsed.inMicroseconds / 1000000, 1 / 240);
    final velocity = delta.distance / dt;
    final velocityLift = (velocity / velocityScale).clamp(
      0.0,
      maxVelocityMultiplier - 1,
    );
    final acceleratedDelta = delta * (1 + velocityLift);
    _panTarget = _panTarget! + acceleratedDelta;

    if (_panTicker == null) {
      _lastPanFrameTime = null;
      _panTicker = vsync.createTicker(_onPanTick)..start();
    }
  }

  void _onPanTick(Duration elapsed) {
    final controller = _controller;
    if (controller == null || _panTarget == null) {
      _panTicker?.dispose();
      _panTicker = null;
      return;
    }

    final dt = _lastPanFrameTime == null
        ? 1 / 60
        : (elapsed - _lastPanFrameTime!).inMicroseconds / 1000000;
    _lastPanFrameTime = elapsed;

    final translation = controller.value.getTranslation();
    final current = Offset(translation.x, translation.y);
    final diff = _panTarget! - current;

    if (diff.distance < 0.5) {
      _applyTranslation(_panTarget!);
      _panTicker?.dispose();
      _panTicker = null;
      _panTarget = null;
      return;
    }

    final alpha = 1 - math.exp(-panFriction * dt);
    _applyTranslation(current + diff * alpha);
  }

  void _applyTranslation(Offset translation) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final next = controller.value.clone()
      ..setTranslation(vec.Vector3(translation.dx, translation.dy, 0));
    controller.value = controller.makeMatrixInSafeRange(next, forceClamp: true);

    final actual = controller.value.getTranslation();
    if (_panTarget != null) {
      if ((actual.x - translation.dx).abs() > 1) {
        _panTarget = Offset(actual.x, _panTarget!.dy);
      }
      if ((actual.y - translation.dy).abs() > 1) {
        _panTarget = Offset(_panTarget!.dx, actual.y);
      }
    }
  }

  @override
  void zoom(
    double scale,
    Offset focalPoint,
    PdfViewerLayoutMetrics layoutMetrics,
  ) {
    final controller = _controller;
    final vsync = _vsync;
    if (controller == null || !controller.isReady || vsync == null) {
      return;
    }

    _panTicker?.dispose();
    _panTicker = null;
    _panTarget = null;

    _zoomTarget ??= controller.currentZoom;
    _zoomTarget = (_zoomTarget! * scale).clamp(
      layoutMetrics.minScale,
      layoutMetrics.maxScale,
    );
    _lastFocalPoint = focalPoint;

    if (_zoomTicker == null) {
      _lastZoomFrameTime = null;
      _zoomTicker = vsync.createTicker(_onZoomTick)..start();
    }
  }

  void _onZoomTick(Duration elapsed) {
    final controller = _controller;
    final target = _zoomTarget;
    final focalPoint = _lastFocalPoint;
    if (controller == null || target == null || focalPoint == null) {
      _zoomTicker?.dispose();
      _zoomTicker = null;
      return;
    }

    final dt = _lastZoomFrameTime == null
        ? 1 / 60
        : (elapsed - _lastZoomFrameTime!).inMicroseconds / 1000000;
    _lastZoomFrameTime = elapsed;

    final diff = target - controller.currentZoom;
    if (diff.abs() < 0.0001) {
      controller.zoomOnLocalPosition(
        localPosition: focalPoint,
        newZoom: target,
        duration: Duration.zero,
      );
      _zoomTicker?.dispose();
      _zoomTicker = null;
      _zoomTarget = null;
      return;
    }

    final alpha = 1 - math.exp(-zoomFriction * dt);
    controller.zoomOnLocalPosition(
      localPosition: focalPoint,
      newZoom: controller.currentZoom + diff * alpha,
      duration: Duration.zero,
    );
  }
}
