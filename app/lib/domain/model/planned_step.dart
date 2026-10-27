/// AI 拆出来的一步：这一步叫什么，这一步要动手做的那件事是什么。
///
/// 只带两个字段——多给字段模型就会开始编造工期、负责人、起止日期，
/// 而这一版没有这些东西可落。
class PlannedStep {
  const PlannedStep({required this.name, required this.task});

  /// 步骤名，落到 `steps.name`。
  final String name;

  /// 这一步下要加的一条事项，落到 `task_items.name`；空串表示只出步骤不出事项。
  final String task;

  @override
  String toString() => 'PlannedStep($name / $task)';
}
