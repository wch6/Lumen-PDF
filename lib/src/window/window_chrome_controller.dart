import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_resize_edge.dart';

typedef WindowChromeMethodHandler = Future<dynamic> Function(MethodCall call);

class WindowChromeController {
  const WindowChromeController({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pdf_reader/window_chrome');

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void setMethodCallHandler(WindowChromeMethodHandler? handler) {
    _channel.setMethodCallHandler(handler);
  }

  Future<void> invoke(String method) async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeMethod<void>(method);
  }

  Future<int?> getWindowDpi() {
    return _guard(() => _channel.invokeMethod<int>('getWindowDpi'));
  }

  Future<bool?> isWindowMaximized() {
    return _guard(() => _channel.invokeMethod<bool>('isWindowMaximized'));
  }

  Future<bool?> toggleMaximizeWindow() {
    return _guard(() => _channel.invokeMethod<bool>('toggleMaximizeWindow'));
  }

  Future<void> minimizeWindow() {
    return invoke('minimizeWindow');
  }

  Future<void> closeWindow() {
    return invoke('closeWindow');
  }

  Future<void> startWindowDrag() {
    return invoke('startWindowDrag');
  }

  Future<void> startWindowResize(WindowResizeEdge edge) async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('startWindowResize', {'edge': edge.name});
  }

  Future<void> setMinimumWindowSize({required int width, required int height}) {
    return _invokeWithMap('setMinimumWindowSize', {
      'width': width,
      'height': height,
    });
  }

  Future<void> setWindowSize({required int width, required int height}) {
    return _invokeWithMap('setWindowSize', {'width': width, 'height': height});
  }

  Future<void> setTitleBarTheme({required bool dark}) {
    return _invokeWithMap('setTitleBarTheme', {'dark': dark});
  }

  Future<({int width, int height})?> getWindowSize() async {
    if (!isSupported) {
      return null;
    }
    final size = await _guard(
      () => _channel.invokeMapMethod<String, Object?>('getWindowSize'),
    );
    final width = (size?['width'] as num?)?.round();
    final height = (size?['height'] as num?)?.round();
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }

  Future<void> _invokeWithMap(String method, Map<String, Object?> arguments) {
    if (!isSupported) {
      return Future<void>.value();
    }
    return _channel.invokeMethod<void>(method, arguments);
  }

  Future<T?> _guard<T>(Future<T?> Function() action) async {
    if (!isSupported) {
      return null;
    }
    try {
      return await action();
    } catch (_) {
      // Keep older runners usable when they do not expose a newer window API.
      return null;
    }
  }
}
