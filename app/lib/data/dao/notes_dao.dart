import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// notes 表的存取。随手记按 ownerType + ownerId 挂。
class NotesDao extends DatabaseAccessor<AppDb> {
  NotesDao(super.db);

  Future<List<Note>> all() => select(db.notes).get();

  Future<List<Note>> byOwner(String ownerType, String ownerId) => (select(
    db.notes,
  )..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))).get();

  /// 某一类 owner 下的全部随手记。进度史一列要读几十条，逐条查太碎。
  Future<List<Note>> byOwnerType(String ownerType) =>
      (select(db.notes)..where((t) => t.ownerType.equals(ownerType))).get();

  /// 某一类 owner 下、ownerId 以 [prefix] 开头的那些。
  ///
  /// 记录页的感想按 `日期|组键|条目` 存，一天一次就能取全，不必逐条查。
  Future<List<Note>> byOwnerTypePrefix(String ownerType, String prefix) =>
      (select(db.notes)..where(
        (t) => t.ownerType.equals(ownerType) & t.ownerId.like('$prefix%'),
      )).get();

  Future<Note?> byOwnerSingle(String ownerType, String ownerId) => (select(
    db.notes,
  )..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))).getSingleOrNull();

  Stream<List<Note>> watchByOwner(String ownerType, String ownerId) => (select(
    db.notes,
  )..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))).watch();

  Future<int> insertOne(NotesCompanion companion) => into(db.notes).insert(companion);

  Future<bool> updateRow(Note row) => update(db.notes).replace(row);

  Future<int> deleteByOwner(String ownerType, String ownerId) => (delete(
    db.notes,
  )..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))).go();

  Future<int> deleteById(String id) => (delete(db.notes)..where((t) => t.id.equals(id))).go();
}
