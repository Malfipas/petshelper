import 'planned_step.dart';

/// 一次拆解的成品：一句回话，加一串步骤。
///
/// 与 PRD 第 6 页的 `reply` + `steps` 结构一一对应，界面照着它渲染，
/// 「应用到项目」照着它落库。
class ProjectPlan {
  const ProjectPlan({required this.reply, required this.steps});

  /// 模型给的一句话，直接显示在拆解卡片上方。
  final String reply;

  /// 拆出来的步骤，顺序即执行顺序。
  final List<PlannedStep> steps;

  bool get isEmpty => steps.isEmpty;
}
