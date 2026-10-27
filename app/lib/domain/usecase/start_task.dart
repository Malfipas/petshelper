import '../model/task_item.dart';
import '../port/task_gateway.dart';

/// 开始一件事：确认它能开始，然后交给计时服务走秒。
///
/// 同一时刻只允许一条在跑——这是产品约定，不是界面约束，所以放在用例里守住。
class StartTask {
  const StartTask(this._tasks);

  final TaskGateway _tasks;

  Future<StartTaskOutcome> call({
    required String taskId,
    String? runningTaskId,
    required int nowMs,
  }) async {
    final task = await _tasks.byId(taskId);
    if (task == null) return const StartTaskNotFound();
    if (task.done) return StartTaskAlreadyDone(task);
    if (runningTaskId != null && runningTaskId != taskId) {
      return StartTaskBusy(runningTaskId: runningTaskId);
    }
    return StartTaskStarted(task: task, startedAt: nowMs);
  }
}

/// 开始的结果。[StartTaskOutcome] 是密封的，调用方必须把每种情况写全。
sealed class StartTaskOutcome {
  const StartTaskOutcome();
}

/// 已经开始走秒。
class StartTaskStarted extends StartTaskOutcome {
  const StartTaskStarted({required this.task, required this.startedAt});

  final TaskItem task;
  final int startedAt;
}

/// 另一条正在跑，先停了它。
class StartTaskBusy extends StartTaskOutcome {
  const StartTaskBusy({required this.runningTaskId});

  final String runningTaskId;
}

/// 事项已经完成，不再开始。
class StartTaskAlreadyDone extends StartTaskOutcome {
  const StartTaskAlreadyDone(this.task);

  final TaskItem task;
}

/// 事项不在库里（可能已被删掉）。
class StartTaskNotFound extends StartTaskOutcome {
  const StartTaskNotFound();
}
