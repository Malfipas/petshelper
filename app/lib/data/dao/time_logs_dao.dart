import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// time_logs 表的存取。一次执行一条，停止即写。
class TimeLogsDao extends DatabaseAccessor<AppDb> {
  TimeLogsDao(super.db);

  Future<List<TimeLog>> all() => select(db.timeLogs).get();

  Future<List<TimeLog>> byTask(String taskId) =>
      (select(db.timeLogs)..where((t) => t.taskId.equals(taskId))).get();

  Future<int> totalSecondsByTask(String taskId) async {
    final rows = await byTask(taskId);
    return rows.fold<int>(0, (sum, r) => sum + r.seconds);
  }

  /// 某个时间段内的流水，按开始时间排序。记录页按天取数用。
  Future<List<TimeLog>> between(int fromMs, int toMs) =>
      (select(db.timeLogs)
            ..where(
              (t) =>
                  t.startedAt.isBiggerOrEqualValue(fromMs) & t.startedAt.isSmallerThanValue(toMs),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
          .get();

  Future<int> insertOne(TimeLogsCompanion companion) => into(db.timeLogs).insert(companion);

  Future<int> deleteByTask(String taskId) =>
      (delete(db.timeLogs)..where((t) => t.taskId.equals(taskId))).go();

  /// 事项换 id 时把流水整体改挂过去，记录页的投入不丢。
  Future<int> reassign(String fromTaskId, String toTaskId) => (update(
    db.timeLogs,
  )..where((t) => t.taskId.equals(fromTaskId))).write(TimeLogsCompanion(taskId: Value(toTaskId)));
}
