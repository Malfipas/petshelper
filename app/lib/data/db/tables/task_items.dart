import 'package:drift/drift.dart';

/// 独立事项与项目待办合成一张表，用 scope 区分归属。
/// 卡片样式、计时、随手记在两边完全一致，只差 scope 与归属 id。
class TaskItems extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// solo / project
  TextColumn get scope => text()();

  /// scope 为 project 时指向 `projects.id`，solo 时为空。
  TextColumn get projectId => text().nullable()();

  /// scope 为 project 时指向 `steps.id`，未分配步骤时为空。
  TextColumn get stepId => text().nullable()();

  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// 累计投入秒数。
  IntColumn get spentSec => integer().withDefault(const Constant(0))();

  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// 完成时间， epoch 毫秒；未完成为空。
  IntColumn get doneAt => integer().nullable()();

  /// created / moved，moved 表示从独立事项移入，带来源角标。
  TextColumn get source => text().withDefault(const Constant('created'))();

  IntColumn get createdAt => integer()();

  /// 同一步骤内的排序，越大越靠后。
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}
