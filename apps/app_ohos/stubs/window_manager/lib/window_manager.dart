import 'dart:async';
import 'package:flutter/material.dart';

enum TitleBarStyle {
  normal,
  hidden,
}

mixin WindowListener {
  void onWindowFocus() {}
  void onWindowBlur() {}
  void onWindowMaximize() {}
  void onWindowUnmaximize() {}
  void onWindowMinimize() {}
  void onWindowRestore() {}
  void onWindowResize() {}
  void onWindowMove() {}
  void onWindowEnterFullScreen() {}
  void onWindowLeaveFullScreen() {}
  void onWindowClose() {}
  void onWindowEvent(String eventName) {}
}

class WindowManager {
  static final WindowManager _instance = WindowManager._();
  factory WindowManager() => _instance;
  WindowManager._();

  final List<WindowListener> _listeners = [];

  Future<void> ensureInitialized() async {}
  Future<void> waitUntilReadyToShow() async {}
  Future<void> setTitleBarStyle(TitleBarStyle style, {bool windowButtonVisibility = true}) async {}
  Future<void> setBackgroundColor(Color color) async {}
  Future<void> setMinimumSize(Size size) async {}
  Future<void> setSize(Size size) async {}
  Future<Size> getSize() async => Size.zero;
  Future<String> getTitle() async => '';
  Future<void> setTitle(String title) async {}
  Future<bool> isMaximized() async => false;
  Future<void> maximize() async {}
  Future<void> unmaximize() async {}
  Future<bool> isMinimized() async => false;
  Future<void> minimize() async {}
  Future<void> restore() async {}
  Future<void> close() async {}
  Future<void> hide() async {}
  Future<void> show() async {}
  Future<void> setPreventClose(bool preventClose) async {}
  Future<void> startDragging() async {}
  Future<Offset> getPosition() async => Offset.zero;
  Future<void> setPosition(Offset position) async {}
  Future<void> setFullScreen(bool isFullScreen) async {}
  Future<Rect> getBounds() async => Rect.zero;
  Future<void> setBounds(Rect rect) async {}
  Future<void> center() async {}

  void addListener(WindowListener listener) {
    _listeners.add(listener);
  }

  void removeListener(WindowListener listener) {
    _listeners.remove(listener);
  }
}

final windowManager = WindowManager();

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DragToResizeArea extends StatelessWidget {
  const DragToResizeArea({
    required this.child,
    this.enableResizeEdges,
    super.key,
  });

  final Widget child;
  final List<ResizeEdge>? enableResizeEdges;

  @override
  Widget build(BuildContext context) => child;
}

enum ResizeEdge {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}
