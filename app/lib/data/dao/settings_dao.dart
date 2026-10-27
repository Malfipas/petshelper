import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// settings 表的存取。只有一行，id 固定为 `app`。
/// API key 本身不在这张表里，这里只记配没配。
class SettingsDao extends DatabaseAccessor<AppDb> {
  static const rowId = 'app';

  SettingsDao(super.db);

  Future<Setting?> current() =>
      (select(db.settings)..where((t) => t.id.equals(rowId))).getSingleOrNull();

  Stream<Setting?> watchCurrent() =>
      (select(db.settings)..where((t) => t.id.equals(rowId))).watchSingleOrNull();

  /// 取到当前设置，没有就建一行默认的。
  ///
  /// 用 `insertOrIgnore`：两个调用同时发现没有这一行时会各自插一次，
  /// 后来那个撞唯一键就整页挂掉——记录页要读「配没配 key」，一开页就是两处并发。
  Future<Setting> ensureRow() async {
    final existing = await current();
    if (existing != null) return existing;
    await into(
      db.settings,
    ).insert(const SettingsCompanion(id: Value(rowId)), mode: InsertMode.insertOrIgnore);
    return (await current())!;
  }

  Future<bool> updateRow(Setting row) => update(db.settings).replace(row);
}
