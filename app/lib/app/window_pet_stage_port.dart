import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../features/pet/pet_frame.dart';
import '../features/pet/pet_stage_port.dart';
import '../platform/window/pet_layout.dart';
import '../platform/window/pet_window.dart';

/// 把窗口层算出来的布局翻成界面用的相对坐标。
///
/// 窗口层只认屏幕绝对坐标，界面只认窗口内坐标；两家的话在这一处翻译。
PetFrame petFrameOf(PetLayout layout) => PetFrame(
  size: layout.window.size,
  pet: layout.petInWindow,
  panel: layout.panelInWindow,
  main: layout.mainInWindow,
  deadlineBubble: layout.deadlineBubbleInWindow,
  reportBubble: layout.reportBubbleInWindow,
);

/// 真窗口版的常驻端口。
///
/// 界面说「换哪一档、要不要给气泡让位」，这里翻成窗口动作；
/// 界面因此完全不用认识 `window_manager`。
class WindowPetStagePort implements PetStagePort {
  WindowPetStagePort(this._window);

  final PetWindow _window;

  @override
  ValueListenable<bool> get dragging => _window.dragging;

  @override
  Future<void> showCollapsed() => _window.setStage(PetStage.collapsed);

  @override
  Future<void> showPanel() => _window.setStage(PetStage.panel);

  @override
  Future<void> showMain() => _window.setStage(PetStage.main);

  @override
  Future<void> showBubbles({required double? deadlineHeight, required double? reportHeight}) =>
      _window.setBubbles(deadlineHeight: deadlineHeight, reportHeight: reportHeight);

  @override
  Future<void> beginDrag() => _window.beginDrag();

  @override
  Future<void> dragBy(Offset delta) => _window.dragPetBy(delta);

  @override
  Future<void> endDrag() => _window.endDrag();
}
