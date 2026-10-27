import '../model/task_item.dart';
import '../port/task_gateway.dart';

/// 停止计时：把这一段落成流水，并把秒数累加到事项上。
///
/// 不足一秒的段落不写流水——手抖点两下不该在记录页留下一条 0 秒的记录。
class StopTask {
  const StopTask(this._tasks);

  final TaskGateway _tasks;

  Future<StopTaskOutcome> call({
    required String taskId,
    required int startedAt,
    required int endedAt,
  }) async {
    final task = await _tasks.byId(taskId);
    if (task == null) return const StopTaskNotFound();
    final seconds = (endedAt - startedAt) ~/ 1000;
    if (seconds <= 0) return StopTaskTooShort(task);
    final logId = await _tasks.logSession(
      taskId: taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      seconds: seconds,
    );
    await _tasks.accumulateSpent(taskId, seconds);
    return StopTaskStopped(task: task, logId: logId, seconds: seconds);
  }
}

/// 停止的结果。密封，调用方要把每种情况写全。
sealed class StopTaskOutcome {
  const StopTaskOutcome();
}

/// 结算完成，流水已落。
class StopTaskStopped extends StopTaskOutcome {
  const StopTaskStopped({required this.task, required this.logId, required this.seconds});

  final TaskItem task;
  final String logId;
  final int seconds;
}

/// 这一段不到一秒，什么都没写。
class StopTaskTooShort extends StopTaskOutcome {
  const StopTaskTooShort(this.task);

  final TaskItem task;
}

/// 事项不在库里（可能已被删掉）。
class StopTaskNotFound extends StopTaskOutcome {
  const StopTaskNotFound();
}
