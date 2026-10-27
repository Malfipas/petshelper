import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// steps 表的存取。
class StepsDao extends DatabaseAccessor<AppDb> {
  StepsDao(super.db);

  /// 全部步骤。开机播报要一次算完所有项目的进度，不能一个项目查一次。
  Future<List<Step>> all() => select(db.steps).get();

  Future<List<Step>> byProject(String projectId) =>
      (select(db.steps)..where((t) => t.projectId.equals(projectId))).get();

  Stream<List<Step>> watchByProject(String projectId) =>
      (select(db.steps)..where((t) => t.projectId.equals(projectId))).watch();

  Future<Step?> byId(String id) =>
      (select(db.steps)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertOne(StepsCompanion companion) => into(db.steps).insert(companion);

  Future<bool> updateRow(Step row) => update(db.steps).replace(row);

  Future<void> replaceProjectSteps(String projectId, List<StepsCompanion> rows) async {
    await transaction(() async {
      await (delete(db.steps)..where((t) => t.projectId.equals(projectId))).go();
      await batch((b) => b.insertAll(db.steps, rows));
    });
  }

  Future<int> deleteById(String id) => (delete(db.steps)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByProject(String projectId) =>
      (delete(db.steps)..where((t) => t.projectId.equals(projectId))).go();
}
