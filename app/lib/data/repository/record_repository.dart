import 'package:drift/drift.dart';

import '../../domain/model/daily_record.dart';
import '../../domain/model/revision.dart';
import '../../domain/port/record_gateway.dart';
import '../dao/daily_records_dao.dart';
import '../dao/revisions_dao.dart';
import '../dao/task_items_dao.dart';
import '../dao/time_logs_dao.dart';
import '../db/app_db.dart' as db;
import '../id.dart';
import '../mapping/row_mappers.dart';

/// 记录页的取数入口。
///
/// 管三张表：daily_records、time_logs（按天聚合）、revisions（日总结改动留痕）。
class RecordRepository implements RecordGateway {
  RecordRepository(db.AppDb database)
    : _records = DailyRecordsDao(database),
      _logs = TimeLogsDao(database),
      _tasks = TaskItemsDao(database),
      _revisions = RevisionsDao(database);

  final DailyRecordsDao _records;
  final TimeLogsDao _logs;
  final TaskItemsDao _tasks;
  final RevisionsDao _revisions;

  /// 独立事项在日历底部那条色带里的键。
  static const soloKey = '__solo__';

  /// 某一天的日总结，没有就空。日期用 yyyy-MM-dd。
  @override
  Future<DailyRecord?> byDate(String date) async {
    final row = await _records.byDate(date);
    return row?.toDomain();
  }

  /// 一个月的日总结，按日期倒序。日历上打点用。
  Future<List<DailyRecord>> month(String yearMonth) async =>
      (await _records.monthOf(yearMonth)).map((row) => row.toDomain()).toList();

  /// 没有就建一条空的，返回这一天的记录。
  Future<DailyRecord> ensureDay(String date, int nowMs) async {
    final existing = await _records.byDate(date);
    if (existing != null) return existing.toDomain();
    await _records.insertOne(
      db.DailyRecordsCompanion.insert(id: newId('d'), date: date, createdAt: nowMs),
    );
    final created = await _records.byDate(date);
    return created!.toDomain();
  }

  /// AI 写总结：直接盖掉正文，不动机改标记。
  @override
  Future<void> setSummary(String date, String text, int nowMs) async {
    await ensureDay(date, nowMs);
    final row = await _records.byDate(date);
    if (row == null) return;
    await _records.updateRow(row.copyWith(summaryText: text));
  }

  /// 用户改总结：记一条修订再落新正文，并打上已改标记（之后 AI 不再覆盖）。
  Future<void> reviseSummary(String date, String after, int nowMs) async {
    final row = await _records.byDate(date);
    if (row == null) return;
    await _revisions.insertOne(
      db.RevisionsCompanion.insert(
        id: newId('r'),
        targetType: RevisionTarget.dailyRecord.dbValue,
        targetId: row.id,
        before: row.summaryText,
        after: after,
        at: nowMs,
      ),
    );
    await _records.updateRow(row.copyWith(summaryText: after, summaryEditedAt: Value(nowMs)));
  }

  Future<List<Revision>> revisionsOf(String date) async {
    final row = await _records.byDate(date);
    if (row == null) return const [];
    final rows = await _revisions.byTarget(RevisionTarget.dailyRecord.dbValue, row.id);
    return rows.map((revision) => revision.toDomain()).toList();
  }

  /// 一个月的每日投入，按项目拆，单位秒。
  ///
  /// 独立事项归到 [soloKey]；事项删了还留着的孤儿流水跳过。
  Future<Map<String, int>> monthSecondsByProject(String yearMonth) async {
    final start = DateTime.parse('$yearMonth-01T00:00:00');
    final end = DateTime(start.year, start.month + 1, 1);
    final rows = await _logs.between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    if (rows.isEmpty) return const {};
    final secondsByKey = <String, int>{};
    for (final log in rows) {
      final task = await _tasks.byId(log.taskId);
      if (task == null) continue;
      final key = task.scope == 'solo' ? soloKey : (task.projectId ?? soloKey);
      secondsByKey[key] = (secondsByKey[key] ?? 0) + log.seconds;
    }
    return secondsByKey;
  }

  /// 一个月里每天的投入，先按天再按项目拆：`{'2026-10-23': {soloKey: 1800, 'p1': 900}}`。
  ///
  /// 与 [monthSecondsByProject] 同一口径：按流水开始时间归日，独立事项归 [soloKey]，
  /// 事项删了还留着的孤儿流水跳过。日历每格的色带由它拼。
  Future<Map<String, Map<String, int>>> daySecondsByProject(String yearMonth) async {
    final start = DateTime.parse('$yearMonth-01T00:00:00');
    final end = DateTime(start.year, start.month + 1, 1);
    final rows = await _logs.between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    if (rows.isEmpty) return const {};

    // 同一条事项一天里可能有好几段流水，事项只查一次。
    final tasks = <String, db.TaskItem?>{};
    final byDay = <String, Map<String, int>>{};
    for (final log in rows) {
      var task = tasks[log.taskId];
      if (task == null && !tasks.containsKey(log.taskId)) {
        task = await _tasks.byId(log.taskId);
        tasks[log.taskId] = task;
      }
      if (task == null) continue;
      final key = task.scope == 'solo' ? soloKey : (task.projectId ?? soloKey);
      final at = DateTime.fromMillisecondsSinceEpoch(log.startedAt);
      final day =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      final perKey = byDay.putIfAbsent(day, () => <String, int>{});
      perKey[key] = (perKey[key] ?? 0) + log.seconds;
    }
    return byDay;
  }
}
