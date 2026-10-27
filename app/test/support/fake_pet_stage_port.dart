import 'dart:ui';

import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:flutter/foundation.dart';

/// 假窗口端口：只记「界面要过哪一档、气泡要多高、拖了多远」，不真的动窗口。
class FakePetStagePort implements PetStagePort {
  final List<String> calls = [];

  /// 最近一次要求的气泡高度，`null` 表示那一档不出现。
  ({double? deadlineHeight, double? reportHeight})? bubbles;

  final ValueNotifier<bool> _dragging = ValueNotifier<bool>(false);
  int drags = 0;

  /// 宠物拖动收尾过几次。
  int dragEnds = 0;

  /// 拖动中累计的位移，按调用顺序记；测试拿它算宠物最后停在哪。
  final List<Offset> offsets = [];

  @override
  ValueListenable<bool> get dragging => _dragging;

  void setDragging(bool value) => _dragging.value = value;

  void dispose() => _dragging.dispose();

  @override
  Future<void> showCollapsed() async => calls.add('collapsed');

  @override
  Future<void> showPanel() async => calls.add('panel');

  @override
  Future<void> showMain() async => calls.add('main');

  @override
  Future<void> showBubbles({required double? deadlineHeight, required double? reportHeight}) async {
    bubbles = (deadlineHeight: deadlineHeight, reportHeight: reportHeight);
    calls.add('bubbles:$deadlineHeight:$reportHeight');
  }

  @override
  Future<void> beginDrag() async => drags++;

  @override
  Future<void> dragBy(Offset delta) async => offsets.add(delta);

  @override
  Future<void> endDrag() async => dragEnds++;
}
