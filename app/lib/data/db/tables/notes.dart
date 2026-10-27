import 'package:drift/drift.dart';

/// 随手记。按 ownerType + ownerId 挂在事项或进度史条目上，
/// 一个 owner 只留一行，正文为空的写入直接删行。
class Notes extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// task / history
  TextColumn get ownerType => text()();

  /// 对应 `task_items.id` 或 `progress_entries.id`。
  TextColumn get ownerId => text()();

  TextColumn get body => text()();

  IntColumn get updatedAt => integer()();
}
