import 'package:drift/drift.dart';

/// 流程中的一步。顺序用 index 表达，不另外存链表。
class Steps extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// 归属项目，对应 `projects.id`。
  TextColumn get projectId => text()();

  /// 这一步在流程里的位置，从 0 开始。
  IntColumn get index => integer()();

  TextColumn get name => text()();

  /// pending / active / done
  TextColumn get state => text().withDefault(const Constant('pending'))();
}
