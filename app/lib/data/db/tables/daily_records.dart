import 'package:drift/drift.dart';

/// 按天一条的日总结。summaryEditedAt 有值表示用户改过，AI 不再覆盖。
class DailyRecords extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// yyyy-MM-dd，一天一条。
  TextColumn get date => text().unique()();

  TextColumn get summaryText => text().withDefault(const Constant(''))();

  /// 用户最后一次改总结的时间， epoch 毫秒；没改过就是空。
  IntColumn get summaryEditedAt => integer().nullable()();

  IntColumn get createdAt => integer()();
}
