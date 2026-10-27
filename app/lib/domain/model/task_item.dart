/// 事项的归属：独立事项，或项目里的待办。
enum TaskScope {
  solo,
  project;

  static TaskScope fromDb(String value) =>
      TaskScope.values.firstWhere((scope) => scope.name == value, orElse: () => TaskScope.solo);
}

/// 事项是怎么来的：自己建的、从独立事项移进来的、AI 拆出来的。
enum TaskSource {
  created,
  moved,
  decomposed;

  static TaskSource fromDb(String value) => TaskSource.values.firstWhere(
    (source) => source.name == value,
    orElse: () => TaskSource.created,
  );
}

/// 一件事。独立事项与项目待办是同一张表、同一个实体，只差归属。
///
/// 卡片、计时、随手记三者对两者完全一致，所以不做成两个类型。
class TaskItem {
  const TaskItem({
    required this.id,
    required this.scope,
    this.projectId,
    this.stepId,
    required this.name,
    this.description = '',
    this.spentSec = 0,
    this.done = false,
    this.doneAt,
    this.source = TaskSource.created,
    this.createdAt = 0,
    this.orderIndex = 0,
  });

  final String id;
  final TaskScope scope;

  /// 属于哪个项目，独立事项为 null。
  final String? projectId;

  /// 挂在项目的哪一步，移入项目时可能还没选步骤。
  final String? stepId;

  final String name;
  final String description;

  /// 累计投入秒数。停止计时时把这一段的秒数加进来。
  final int spentSec;

  final bool done;

  /// 完成时间，毫秒时间戳；没完成为 null。
  final int? doneAt;

  final TaskSource source;
  final int createdAt;

  /// 同一步骤内的先后，值小的在前。
  final int orderIndex;

  bool get isSolo => scope == TaskScope.solo;

  bool get hasStep => stepId != null;

  Duration get spent => Duration(seconds: spentSec);
}
