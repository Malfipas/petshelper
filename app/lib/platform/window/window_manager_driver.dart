import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'window_driver.dart';
import 'window_geometry.dart';

/// 真窗口：走 window_manager 与 screen_retriever。
///
/// 透明底与初始位置还要在起窗时用 `WindowOptions` 交代一次，两处配合才不出现
/// 白底方框；那部分在入口的起窗流程里，这里只负责窗口就位之后的样式与摆位。
class WindowManagerDriver with WindowListener implements WindowDriver {
  WindowManagerDriver();

  /// 拖动停下多久算松手。系统拖动时窗口一路在动，停下来那一刻没有事件可听。
  static const Duration settleDelay = Duration(milliseconds: 180);

  final StreamController<void> _dragEnded = StreamController<void>.broadcast();
  Timer? _settle;
  bool _watching = false;

  @override
  Stream<void> get dragEnded => _dragEnded.stream;

  @override
  Future<void> prepare() async {
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(const Color(0x00000000));
  }

  @override
  Future<void> setAlwaysOnTop(bool value) => windowManager.setAlwaysOnTop(value);

  /// 主屏可见区。系统给的是扣掉任务栏之后的那块，拿来当纵向余量才不会被任务栏压住。
  @override
  Future<ScreenWorkArea> workArea() async {
    final display = await screenRetriever.getPrimaryDisplay();
    return ScreenWorkArea.fromOrigin(
      display.visiblePosition ?? Offset.zero,
      display.visibleSize ?? display.size,
    );
  }

  @override
  Future<Rect> bounds() => windowManager.getBounds();

  @override
  Future<void> placeAt(Rect bounds) => windowManager.setBounds(bounds);

  @override
  Future<void> startDrag() async {
    if (!_watching) {
      windowManager.addListener(this);
      _watching = true;
    }
    await windowManager.startDragging();
  }

  /// 窗口动一下就重置计时器，停下来才算这次拖动结束。
  ///
  /// 自己摆位时也会触发这里，但那时 `PetWindow` 并不在拖动中，收到事件也不会做什么。
  @override
  void onWindowMoved() {
    _settle?.cancel();
    _settle = Timer(settleDelay, () {
      if (!_dragEnded.isClosed) _dragEnded.add(null);
    });
  }
}
