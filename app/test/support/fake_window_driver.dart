import 'dart:async';
import 'dart:ui';

import 'package:ai_pet_assistant/platform/window/window_driver.dart';
import 'package:ai_pet_assistant/platform/window/window_geometry.dart';

/// 假窗口：位置记在内存里，拖动就是把矩形挪到指定位置，代替系统拖拽。
///
/// 窗口层与 app 层的测试共用它，省得每处再写一遍平台通道的替身。
class FakeWindowDriver implements WindowDriver {
  FakeWindowDriver({required this.area});

  final ScreenWorkArea area;
  final StreamController<void> _dragEnded = StreamController<void>.broadcast();
  Rect rect = Rect.zero;
  int prepared = 0;
  int drags = 0;
  final List<Rect> placed = [];

  /// 最近一次置顶开关的值。主界面档要能关掉，别的档要开着。
  bool? alwaysOnTop;

  @override
  Stream<void> get dragEnded => _dragEnded.stream;

  @override
  Future<void> prepare() async {
    prepared++;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async => alwaysOnTop = value;

  @override
  Future<ScreenWorkArea> workArea() async => area;

  @override
  Future<Rect> bounds() async => rect;

  @override
  Future<void> placeAt(Rect bounds) async {
    rect = bounds;
    placed.add(bounds);
  }

  @override
  Future<void> startDrag() async {
    drags++;
  }

  /// 模拟手把窗口拖到某处：左上角落到 [topLeft]，尺寸不变。
  void dragTo(Offset topLeft) {
    rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, rect.width, rect.height);
  }

  /// 模拟系统拖动停下：窗口停住之后由驱动通知外面一声。
  void dropDrag() => _dragEnded.add(null);
}
