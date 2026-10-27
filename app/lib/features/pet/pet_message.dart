import '../../domain/model/project_digest.dart';

/// 气泡分两档：截止强提醒与开机播报。
enum PetBubbleKind { deadline, report }

/// 离截止还有多远。24 小时内与 2 小时内各提醒一次，两次内容一样、紧急度不同。
enum DeadlineStage {
  /// 还早，不提醒。
  none,

  /// 24 小时内。
  withinDay,

  /// 2 小时内。
  withinTwoHours,
}

/// 一次截止提醒：哪件事、什么时候截止、急不急。
class DeadlineHint {
  const DeadlineHint({
    required this.projectId,
    required this.name,
    required this.dueAt,
    required this.stage,
  });

  final String projectId;

  /// 「项目名 · 那件事」。
  final String name;

  final int dueAt;
  final DeadlineStage stage;

  /// 2 小时内算紧急，气泡用更重的边框。
  bool get urgent => stage == DeadlineStage.withinTwoHours;
}

/// 这一刻该不该提醒这个截止时间。
///
/// 已经过期的项目不再提醒：提醒也来不及，只会让人每天开机就被骂一次。
DeadlineStage deadlineStageOf({required int dueAt, required int now}) {
  final left = dueAt - now;
  if (left <= 0) return DeadlineStage.none;
  if (left <= const Duration(hours: 2).inMilliseconds) {
    return DeadlineStage.withinTwoHours;
  }
  if (left <= const Duration(hours: 24).inMilliseconds) {
    return DeadlineStage.withinDay;
  }
  return DeadlineStage.none;
}

/// 挑出最该提醒的一条截止：多个项目同时逼近时只留最早的那个。
///
/// 《页面操作流程》第 3 节起改成「一件一条」由 [deadlineHints] 供，这里留着给只想知道
/// 「最近的那个是哪个」的地方用。
DeadlineHint? nearestDeadline(List<ProjectDigest> digests, {required int now}) {
  final hints = deadlineHints(digests, now: now);
  return hints.isEmpty ? null : hints.first;
}

/// 所有进了提醒窗口的截止，按到期时间从近到远。
///
/// 《页面操作流程》第 3 节：「每件事一个气泡，多个事件同时逼近时，各显示一个气泡」。
/// 气泡栈最多摆三块由 [PetState.visibleBubbles] 兜着，这里不截。
List<DeadlineHint> deadlineHints(List<ProjectDigest> digests, {required int now}) {
  final hints = <DeadlineHint>[];
  for (final digest in digests) {
    final dueAt = digest.dueAt;
    if (dueAt == null) continue;
    final stage = deadlineStageOf(dueAt: dueAt, now: now);
    if (stage == DeadlineStage.none) continue;
    final name = digest.currentStepName == null
        ? digest.name
        : '${digest.name} · ${digest.currentStepName}';
    hints.add(DeadlineHint(projectId: digest.projectId, name: name, dueAt: dueAt, stage: stage));
  }
  hints.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return hints;
}

/// 截止时间的说法：「将于 2026年10月31日 截止」。
///
/// 《页面操作流程》第 3 节把这一行定成「将于*截止日期*截止」，写死日期而不是
/// 「今天/明天」：截止气泡不自动消失，飘一天之后「今天」就不成立了。
String dueLabel(int dueAt, {required int now}) {
  final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
  return '将于 ${due.year}年${due.month}月${due.day}日 截止';
}

/// 上次推进的说法：「今天」「前天」「8-12」；从没推进过返回 null。
///
/// 按日历日算，不按 24 小时——昨晚 23 点推进的，今早开机应该说「昨天」。
String? lastAdvancedLabel(int? at, {required int now}) {
  if (at == null) return null;
  final then = DateTime.fromMillisecondsSinceEpoch(at);
  final today = DateTime.fromMillisecondsSinceEpoch(now);
  final days = _dayDiff(today, then);
  if (days <= 0) return '今天';
  if (days == 1) return '昨天';
  if (days == 2) return '前天';
  if (days < 7) return '$days天前';
  return '${then.month}-${then.day}';
}

/// 播报的一行拆成两段：项目名单独一段，好在气泡里加粗。
///
/// 原型 `.brow` 是「`<b>项目名</b>` + 浅色说明」，整行一个样式就不像它了。
class ReportRow {
  const ReportRow({required this.name, required this.detail});

  final String name;

  /// 进度与上次推进：「18%，1/7，前天」。
  final String detail;

  @override
  String toString() => '$name $detail';
}

/// 播报的一行：「毕业论文 3/7 42% | 3天前」。
///
/// 《页面操作流程》第 2 节给的行序是「项目名 | 项目进度（已完成数/总数、百分比）
/// | 上次推进时间」，分隔用竖线。没拆步骤的项目写「还没拆步骤」，没推进过的省掉
/// 时间那一节——报一个 0% 不如直接说没开始。
ReportRow reportRow(ProjectDigest digest, {required int now}) {
  final progress = digest.totalSteps == 0
      ? '还没拆步骤'
      : '${digest.doneSteps}/${digest.totalSteps} ${digest.percent}%';
  final when = lastAdvancedLabel(digest.lastAdvancedAt, now: now);
  return ReportRow(name: digest.name, detail: when == null ? progress : '$progress | $when');
}

/// 一整行的说法，给不拆样式的地方用。
String reportLine(ProjectDigest digest, {required int now}) {
  final row = reportRow(digest, now: now);
  return '${row.name} ${row.detail}';
}

/// 两个时刻之间差几个日历日，忽略时分秒。
int _dayDiff(DateTime later, DateTime earlier) {
  final a = DateTime(later.year, later.month, later.day);
  final b = DateTime(earlier.year, earlier.month, earlier.day);
  return a.difference(b).inDays;
}


