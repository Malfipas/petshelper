import '../model/task_day_entry.dart';
import '../model/task_item.dart';

/// 用例读写事项要用的最小接口，由 `TaskRepository` 实现。
///
/// 用例只声明自己需要的方法，不引用整个 Repository：这样测用例时给个假实现就够，
/// 也不会把 data 层拖进 domain。
abstract interface class TaskGateway {
  Future<TaskItem?> byId(String id);

  /// 某一天动过的事项：当天开过表的，以及当天被标记完成的（后者常常没有流水）。
  Future<List<TaskDayEntry>> entriesForDay(int fromMs, int toMs);

  /// 某一天里做完的事项，按完成时间倒序。
  Future<List<TaskItem>> doneBetween(int fromMs, int toMs);

  /// 勾完成 / 取消勾选。完成时间只在勾上时记。
  Future<void> setDone(String id, bool done, int nowMs);

  /// 把这一段的秒数累加到事项上。
  Future<void> accumulateSpent(String id, int seconds);

  /// 写一条执行流水。
  Future<String> logSession({
    required String taskId,
    required int startedAt,
    required int endedAt,
    required int seconds,
  });

  /// 在项目里新建一条待办，可带已积累的投入秒数。
  Future<String> createForProject({
    required String projectId,
    required String name,
    String? stepId,
    String description = '',
    required int nowMs,
    int spentSec = 0,
    TaskSource source = TaskSource.created,
  });

  /// 删事项：连它的流水与随手记一起清掉。
  Future<void> delete(String id);
}
