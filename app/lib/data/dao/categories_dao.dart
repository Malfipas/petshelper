import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// categories 表的存取。分类只由 AI 生成，用户可改名。
class CategoriesDao extends DatabaseAccessor<AppDb> {
  CategoriesDao(super.db);

  Future<List<Category>> all() => select(db.categories).get();

  Stream<List<Category>> watchAll() => select(db.categories).watch();

  Future<Category?> byId(String id) =>
      (select(db.categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Category?> byName(String name) =>
      (select(db.categories)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertOne(CategoriesCompanion companion) => into(db.categories).insert(companion);

  Future<bool> updateRow(Category row) => update(db.categories).replace(row);

  Future<int> deleteById(String id) => (delete(db.categories)..where((t) => t.id.equals(id))).go();
}
