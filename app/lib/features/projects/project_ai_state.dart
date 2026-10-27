import '../../domain/model/ai_attachment.dart';
import '../../domain/model/planned_step.dart';

/// 拆解卡片走到哪一步。
enum AiPlanPhase {
  /// 还没发过请求。
  idle,

  /// 请求在路上，按钮换成「正在拆…」。
  thinking,

  /// 拿到结果，等使用者点「应用到项目」。
  ready,

  /// 这次没成，卡片里显示一句原因。
  failed,
}

/// 项目详情页「AI 帮助」那一块的所有状态。
///
/// 单独拎一个不可变对象，是因为这些字段只在这一块里用，塞进 `ProjectListState`
/// 会让那个已经很长的构造函数再长一截。
class AiHelp {
  const AiHelp({
    this.open = false,
    this.goal = '',
    this.phase = AiPlanPhase.idle,
    this.reply = '',
    this.steps = const <PlannedStep>[],
    this.error = '',
    this.applied = false,
    this.attachments = const <AiAttachment>[],
    this.hint = '',
  });

  /// 整块是否展开。收起不动内容，再展开还能接着改。
  final bool open;

  /// 目标输入框里的草稿。
  final String goal;

  final AiPlanPhase phase;

  /// 模型给的那一句话。
  final String reply;

  /// 拆出来的步骤，等确认后落库。
  final List<PlannedStep> steps;

  /// 失败原因，只在 [phase] 为 failed 时有意义。
  final String error;

  /// 这一份结果是否已经写进项目；写完按钮换成「已应用」，防止点两次写出两份。
  final bool applied;

  /// 这一轮一起送进去的图片与文件。
  final List<AiAttachment> attachments;

  /// 灰色的一行提示：挑文件被跳过时说明原因，不当作失败。
  final String hint;

  /// 拆完了、还没落库，这时才给「应用到项目」。
  bool get canApply => phase == AiPlanPhase.ready && steps.isNotEmpty && !applied;

  /// 正在等结果时不允许再发一次。
  bool get busy => phase == AiPlanPhase.thinking;

  /// 还能再带几个附件。
  int get remainingSlots => AiAttachment.maxCount - attachments.length;

  /// 一句话与附件都没有就没什么可发的。
  bool get canAsk => !busy && (goal.trim().isNotEmpty || attachments.isNotEmpty);

  AiHelp copyWith({
    bool? open,
    String? goal,
    AiPlanPhase? phase,
    String? reply,
    List<PlannedStep>? steps,
    String? error,
    bool? applied,
    List<AiAttachment>? attachments,
    String? hint,
  }) => AiHelp(
    open: open ?? this.open,
    goal: goal ?? this.goal,
    phase: phase ?? this.phase,
    reply: reply ?? this.reply,
    steps: steps ?? this.steps,
    error: error ?? this.error,
    applied: applied ?? this.applied,
    attachments: attachments ?? this.attachments,
    hint: hint ?? this.hint,
  );
}
