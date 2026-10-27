import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// projects 表的存取。只做单表的事，跨表的事到 Repository。
class ProjectsDao extends DatabaseAccessor<AppDb> {
  ProjectsDao(super.db);

  Future<List<Project>> all() => select(db.projects).get();

  Stream<List<Project>> watchAll() => select(db.projects).watch();

  Future<Project?> byId(String id) =>
      (select(db.projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertOne(ProjectsCompanion companion) => into(db.projects).insert(companion);

  Future<bool> updateRow(Project row) => update(db.projects).replace(row);

  Future<int> deleteById(String id) => (delete(db.projects)..where((t) => t.id.equals(id))).go();

  Future<void> insertAll(List<ProjectsCompanion> rows) async {
    await batch((b) => b.insertAll(db.projects, rows));
  }
}
