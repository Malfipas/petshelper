import 'package:drift/drift.dart';

/// 一次执行的流水。停止即写一条，不填任何字段。
class TimeLogs extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// 对应 `task_items.id`。
  TextColumn get taskId => text()();

  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer()();
  IntColumn get seconds => integer()();
}
