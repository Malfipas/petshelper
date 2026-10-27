/// 一次执行的流水。停止计时时写一条，之后不再改。
///
/// 记录页的每日投入、每月的项目色条都从这张表聚合出来，所以字段只填不修。
class TimeLog {
  const TimeLog({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.endedAt,
    required this.seconds,
  });

  final String id;
  final String taskId;
  final int startedAt;
  final int endedAt;

  /// 这一段计入的秒数。暂停的时间不算在里面，所以不一定等于起止之差。
  final int seconds;

  Duration get duration => Duration(seconds: seconds);
}
