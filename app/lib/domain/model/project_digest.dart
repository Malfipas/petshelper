/// 头顶播报要的一行：项目名、走了多少步、上次推进什么时候。
///
/// 只放播报与截止提醒用得上的几个数，不搬整套步骤与进度史——
/// 一次开机要读全部项目，搬全量会让启动白等。
class ProjectDigest {
  const ProjectDigest({
    required this.projectId,
    required this.name,
    this.dueAt,
    required this.doneSteps,
    required this.totalSteps,
    this.lastAdvancedAt,
    this.currentStepName,
  });

  final String projectId;
  final String name;

  /// 截止时间，毫秒时间戳；没有截止为 null。
  final int? dueAt;

  /// 已完成的步数。
  final int doneSteps;

  /// 步骤总数。还没拆步骤的项目是 0。
  final int totalSteps;

  /// 最近一次推进的时间；从没推进过为 null。
  final int? lastAdvancedAt;

  /// 当前走在哪一步，用来凑「项目名 · 那件事」；还没走到任何一步为 null。
  final String? currentStepName;

  bool get hasDue => dueAt != null;

  /// 完成度百分比，向下取整。没有步骤的项目算 0%，不显示 NaN 或 100%。
  int get percent {
    if (totalSteps == 0) return 0;
    final value = doneSteps * 100 ~/ totalSteps;
    return value < 0 ? 0 : (value > 100 ? 100 : value);
  }
}
