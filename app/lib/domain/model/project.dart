/// 项目容器。
///
/// 组织方式固定为流程顺序：步骤按 `index` 排，`currentStep` 是当前推进到第几步。
class Project {
  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.dueAt,
    this.currentStep = -1,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// 一句话说明，可为空字符串。
  final String description;

  /// 截止时间，毫秒时间戳；没有截止为 null。
  final int? dueAt;

  /// 当前步骤下标，-1 表示还没开始。
  final int currentStep;

  final int createdAt;

  bool get hasDue => dueAt != null;

  bool get started => currentStep >= 0;
}
