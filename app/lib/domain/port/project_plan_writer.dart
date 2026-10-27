import '../model/planned_step.dart';

/// 把拆解结果写进项目。
///
/// 单独开一个窄接口而不塞进 `ProjectGateway`：拆解是唯一一处要同时写步骤与
/// 事项的地方，别的用例不该顺手拿到这个口子。
abstract interface class ProjectPlanWriter {
  /// 空流程整段替换，已有内容追加在末尾。返回写进去的步骤数。
  Future<int> applyPlan({
    required String projectId,
    required List<PlannedStep> steps,
    required int nowMs,
  });
}
