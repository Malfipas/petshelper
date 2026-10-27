import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// ideas 表的存取。classifiedAt 为空的才会送 AI 归类。
class IdeasDao extends DatabaseAccessor<AppDb> {
  IdeasDao(super.db);

  Future<List<Idea>> all() => select(db.ideas).get();

  Stream<List<Idea>> watchAll() => select(db.ideas).watch();

  Future<List<Idea>> byCategory(String categoryId) =>
      (select(db.ideas)..where((t) => t.categoryId.equals(categoryId))).get();

  Future<List<Idea>> unclassified() =>
      (select(db.ideas)..where((t) => t.classifiedAt.isNull())).get();

  Future<Idea?> byId(String id) =>
      (select(db.ideas)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertOne(IdeasCompanion companion) => into(db.ideas).insert(companion);

  Future<bool> updateRow(Idea row) => update(db.ideas).replace(row);

  Future<int> deleteById(String id) => (delete(db.ideas)..where((t) => t.id.equals(id))).go();
}
