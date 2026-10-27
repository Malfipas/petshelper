import '../model/ai_attachment.dart';
import '../model/project_plan.dart';

/// 把一句目标拆成步骤与每步要做的事。
///
/// 端口只管「给我一个能落库的拆解结果」，不管背后是哪家模型、怎么发请求。
/// 无 key、超时、模型答了非 JSON 都要能表达出来，界面上才分得清是去设置
/// 页还是重试。
abstract interface class ProjectPlanner {
  /// `projectName` 只用来让模型贴合语境，允许为空。
  ///
  /// [attachments] 是可以一起送进去的图片与文件：只有一句话说不清的时候，
  /// 让人把参考资料拖进来。带附件时 [goal] 允许为空。
  Future<PlanOutcome> plan({
    required String projectName,
    required String goal,
    List<AiAttachment> attachments = const <AiAttachment>[],
  });
}

/// 拆解的结果。
sealed class PlanOutcome {
  const PlanOutcome();
}

/// 拿到可用的拆解。
class PlanReady extends PlanOutcome {
  const PlanReady(this.plan);

  final ProjectPlan plan;
}

/// 还没配 key，界面要引导去设置页。
class PlanNotConfigured extends PlanOutcome {
  const PlanNotConfigured();
}

/// 配了 key 但这次没成，`reason` 是给使用者看的一句话。
class PlanFailed extends PlanOutcome {
  const PlanFailed(this.reason);

  final String reason;
}
