import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 界面能要求窗口做的几件事。
///
/// 桌宠的空间是窗口给的：宠物要多大一块、气泡要不要提前让出头顶、面板与主界面
/// 换档，全是窗口尺寸问题。这些能力从入口注入，features 不自己碰窗口。
abstract interface class PetStagePort {
  /// 收成只有宠物。
  Future<void> showCollapsed();

  /// 宠物 + 悬停面板。
  Future<void> showPanel();

  /// 主界面档。
  Future<void> showMain();

  /// 头顶气泡要不要占位、各占多高。
  ///
  /// 传 `null` 表示这一档不出现。原型的气泡是内容自然高度，窗口必须先知道高度
  /// 才让得开；内容没变时不必重复调。
  Future<void> showBubbles({required double? deadlineHeight, required double? reportHeight});

  /// 拖动正在进行。拖动期间不弹面板、不弹气泡。
  ValueListenable<bool> get dragging;

  /// 按住宠物起手拖动。
  ///
  /// 常驻档窗口就是宠物，交给系统整窗跟手；主界面档窗口里还装着主界面，
  /// 那一档改由窗口层自己算——宠物跟手，主界面不动。
  Future<void> beginDrag();

  /// 拖动中把宠物挪一段。只有主界面档用得着，常驻档由系统跟手。
  Future<void> dragBy(Offset delta);

  /// 松手：宠物吸回桌面右缘，纵向按比例记住。
  ///
  /// 常驻档的松手由窗口层从系统拖动反推；主界面档要界面在抬手时显式叫一声，
  /// 否则窗口会停在铺满工作区的样子。
  Future<void> endDrag();
}

/// 必须在入口注入：窗口在 `main` 里起，测试里换假实现。
final petStagePortProvider = Provider<PetStagePort>(
  (ref) => throw UnimplementedError('PetStagePort 要在入口注入'),
);
