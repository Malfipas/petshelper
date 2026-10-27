import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// progress_entries 表的存取。进度史只按流程顺序排。
class ProgressEntriesDao extends DatabaseAccessor<AppDb> {
  ProgressEntriesDao(super.db);

  /// 全部进度史。开机播报只取每个项目最近一条的时间，一次读完再分组。
  Future<List<ProgressEntry>> all() => select(db.progressEntries).get();

  Future<List<ProgressEntry>> byProject(String projectId) =>
      (select(db.progressEntries)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.stepIndex)]))
          .get();

  Stream<List<ProgressEntry>> watchByProject(String projectId) =>
      (select(db.progressEntries)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.stepIndex)]))
          .watch();

  Future<ProgressEntry?> byId(String id) =>
      (select(db.progressEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertOne(ProgressEntriesCompanion companion) =>
      into(db.progressEntries).insert(companion);

  Future<bool> updateRow(ProgressEntry row) => update(db.progressEntries).replace(row);

  Future<int> deleteById(String id) =>
      (delete(db.progressEntries)..where((t) => t.id.equals(id))).go();

  /// 删掉第 `removedIndex` 步后，把后面的进度史编号各前移一位。
  ///
  /// 指向被删那一步的记录保持原编号不动：它记的是当时的位置，
  /// 越界由进度史自己容错，不在这里猜它该并到哪一步。
  Future<void> shiftAfter(String projectId, int removedIndex) async {
    final rows =
        await (select(db.progressEntries)..where(
              (t) => t.projectId.equals(projectId) & t.stepIndex.isBiggerThanValue(removedIndex),
            ))
            .get();
    for (final row in rows) {
      await updateRow(row.copyWith(stepIndex: row.stepIndex - 1));
    }
  }
}
