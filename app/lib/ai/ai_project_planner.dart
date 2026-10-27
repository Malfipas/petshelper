import '../domain/model/ai_attachment.dart';
import '../domain/port/project_planner.dart';
import 'chat_client.dart';
import 'plan_parser.dart';
import 'prompts.dart';

/// 用模型拆步骤。
///
/// 这一层只做三件事：拼话、发请求、把话解析成能落库的结果。三种不成功都翻
/// 成端口上的结果，界面据此决定是引导去设置页、还是给一个「再试一次」。
class AiProjectPlanner implements ProjectPlanner {
  const AiProjectPlanner(this._client);

  final ChatClient _client;

  @override
  Future<PlanOutcome> plan({
    required String projectName,
    required String goal,
    List<AiAttachment> attachments = const <AiAttachment>[],
  }) async {
    final trimmed = goal.trim();
    // 一句话没写、附件也没有，那是还没想好要做什么；带了附件就允许空话。
    if (trimmed.isEmpty && attachments.isEmpty) {
      return const PlanFailed('先写一句要做什么');
    }

    final outcome = await _client.complete(
      system: planSystemPrompt,
      user: planUserPrompt(projectName: projectName, goal: trimmed),
      attachments: attachments,
    );

    switch (outcome) {
      case ChatNoKey():
        return const PlanNotConfigured();
      case ChatError(:final reason):
        return PlanFailed(reason);
      case ChatReply(:final text):
        final plan = parsePlan(text);
        if (plan == null) return const PlanFailed('这次没拆成，再试一次');
        return PlanReady(plan);
    }
  }
}
