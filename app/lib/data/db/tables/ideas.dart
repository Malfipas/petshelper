import 'package:drift/drift.dart';

/// 想法。classifiedAt 为空才会送 AI 归类，每条只分一次。
class Ideas extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// 对应 `categories.id`，没归类就是空。
  TextColumn get categoryId => text().nullable()();

  /// 归类时间， epoch 毫秒；没归过就是空。
  IntColumn get classifiedAt => integer().nullable()();

  IntColumn get createdAt => integer()();
}
