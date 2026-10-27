import 'package:drift/drift.dart';

/// 项目容器。组织方式固定为流程顺序，不存甘特图那些东西。
class Projects extends Table {
  /// 应用生成的文本主键（带前缀，如 `p_1710000000000`）。
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// 截止日期， epoch 毫秒；没有截止就是空。
  IntColumn get dueAt => integer().nullable()();

  /// 当前推进到第几步，从 0 开始；还没开始就是 -1。
  IntColumn get currentStep => integer().withDefault(const Constant(-1))();

  IntColumn get createdAt => integer()();
}
