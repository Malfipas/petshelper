import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一档的布局，全部是窗口内的相对坐标。
///
/// 由入口把窗口层算出来的绝对矩形减掉窗口原点后塞进来。这样常驻态页面只管
/// 「东西摆在窗口里的哪一块」，不用知道屏幕多大、窗口贴哪边。
class PetFrame {
  const PetFrame({
    required this.size,
    required this.pet,
    this.panel,
    this.main,
    this.deadlineBubble,
    this.reportBubble,
  });

  /// 窗口尺寸。页面按它铺满，内容的位置由下面几个矩形决定。
  final Size size;

  final Rect pet;
  final Rect? panel;
  final Rect? main;
  final Rect? deadlineBubble;
  final Rect? reportBubble;

  /// 还没接上真窗口时的占位：一个正方形宠物框。widget 测试直接用它。
  static const PetFrame fallback = PetFrame(
    size: Size(240, 240),
    pet: Rect.fromLTWH(0, 0, 240, 240),
  );
}

/// 当前这一档的布局。窗口换档或气泡增减后，入口把新布局写进来。
class PetFrameNotifier extends Notifier<PetFrame> {
  @override
  PetFrame build() => PetFrame.fallback;

  void apply(PetFrame frame) => state = frame;
}

final petFrameProvider = NotifierProvider<PetFrameNotifier, PetFrame>(PetFrameNotifier.new);
