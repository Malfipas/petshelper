import 'task_item.dart';

/// 一天里某条事项的投入。记录页按天分组时用。
///
/// 读模型，不是表：由流水按事项聚合出来。
/// 当天只点「标记完成」、没跑过秒的事也在这份清单里——那种 [seconds] 为 0，
/// [atMs] 取完成时刻，否则记录页的右栏会把它们整条漏掉。
class TaskDayEntry {
  const TaskDayEntry({required this.task, required this.seconds, this.atMs});

  final TaskItem task;

  /// 当天在这一件上记的秒数；没开表是 0。
  final int seconds;

  /// 当天这一条的时刻：最后一段流水的结束时刻，没开表就用完成时刻。
  final int? atMs;

  Duration get spent => Duration(seconds: seconds);

  /// 当天是否真的计过时。右栏据此区分「投入 20 分钟」与「没计时」。
  bool get timed => seconds > 0;
}
