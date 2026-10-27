import '../model/note.dart';
import '../model/task_item.dart';
import '../port/note_gateway.dart';
import '../port/project_gateway.dart';
import '../port/task_gateway.dart';

/// 完成或退回一件事。
///
/// 勾上完成时，项目里的那条还要留一行进度史，随手记跟过去；重复点不会再写一行
/// 进度史——完成是状态，不是事件。
///
/// 退回（PRD 483「再点退回未完成」）只把状态翻回去，不动已经写下的进度史：
/// 那条史是「那天确实做完过」的事实，删它就等于改了历史。
class FinishTask {
  const FinishTask({required this.tasks, required this.projects, required this.notes});

  final TaskGateway tasks;
  final ProjectGateway projects;
  final NoteGateway notes;

  Future<FinishTaskOutcome> call({
    required String taskId,
    required int nowMs,
    bool done = true,
  }) async {
    final task = await tasks.byId(taskId);
    if (task == null) return const FinishTaskNotFound();

    if (!done) {
      if (!task.done) return FinishTaskAlreadyOpen(task);
      await tasks.setDone(taskId, false, nowMs);
      return FinishTaskReopened(task);
    }

    if (task.done) return FinishTaskAlreadyDone(task);

    await tasks.setDone(taskId, true, nowMs);

    final note = await notes.textOf(NoteOwner.task, taskId);
    final projectId = task.projectId;
    if (projectId == null) {
      return FinishTaskFinished(task: task, entryId: null, noteMoved: false);
    }

    final bundle = await projects.load(projectId);
    final entryId = await projects.addProgress(
      projectId: projectId,
      stepIndex: bundle.indexOfStep(task.stepId),
      content: '完成「${task.name}」',
      nowMs: nowMs,
    );

    var noteMoved = false;
    if (note.trim().isNotEmpty) {
      await notes.save(NoteOwner.history, entryId, note, nowMs);
      await notes.save(NoteOwner.task, taskId, '', nowMs);
      noteMoved = true;
    }

    return FinishTaskFinished(task: task, entryId: entryId, noteMoved: noteMoved);
  }
}

/// 完成的结果。密封，调用方要把每种情况写全。
sealed class FinishTaskOutcome {
  const FinishTaskOutcome();
}

/// 完成了。[entryId] 为 null 表示这是独立事项，没有进度史可留。
class FinishTaskFinished extends FinishTaskOutcome {
  const FinishTaskFinished({required this.task, required this.entryId, required this.noteMoved});

  final TaskItem task;
  final String? entryId;
  final bool noteMoved;
}

/// 之前就完成了，这次什么都没写。
class FinishTaskAlreadyDone extends FinishTaskOutcome {
  const FinishTaskAlreadyDone(this.task);

  final TaskItem task;
}

/// 退回未完成：状态翻回去了，进度史与随手记都不动。
class FinishTaskReopened extends FinishTaskOutcome {
  const FinishTaskReopened(this.task);

  final TaskItem task;
}

/// 本来就没完成，没什么可退的。
class FinishTaskAlreadyOpen extends FinishTaskOutcome {
  const FinishTaskAlreadyOpen(this.task);

  final TaskItem task;
}

/// 事项不在库里（可能已被删掉）。
class FinishTaskNotFound extends FinishTaskOutcome {
  const FinishTaskNotFound();
}
