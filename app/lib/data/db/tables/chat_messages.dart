import 'package:drift/drift.dart';

/// 执行中的对话，按事务隔离。
class ChatMessages extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// panel / project
  TextColumn get ownerType => text()();

  /// 对应 `task_items.id` 或项目名。
  TextColumn get ownerId => text()();

  /// user / ai
  TextColumn get role => text()();

  /// 消息正文。不叫 text，那是 drift 的方法名，会撞。
  TextColumn get content => text()();

  IntColumn get at => integer()();
}
