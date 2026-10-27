/// 一步的状态。老数据里出现不认识的值时按 [pending] 处理。
enum StepState {
  pending,
  current,
  done;

  static StepState fromDb(String value) =>
      StepState.values.firstWhere((state) => state.name == value, orElse: () => StepState.pending);
}

/// 流程里的一步。
///
/// 删掉一步时，挂在它下面的待办转为未分配（`stepId` 置空），事项本身不删。
class Step {
  const Step({
    required this.id,
    required this.projectId,
    required this.index,
    required this.name,
    this.state = StepState.pending,
  });

  final String id;
  final String projectId;

  /// 在流程里的顺序，从 0 起。
  final int index;

  final String name;
  final StepState state;

  bool get isCurrent => state == StepState.current;
}
