import 'package:drift/drift.dart';

/// 改动留痕。日总结与进度史可改，但每次改都记在这里。
class Revisions extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// dailyRecord / progressEntry
  TextColumn get targetType => text()();

  TextColumn get targetId => text()();

  /// 改之前的内容。
  TextColumn get before => text()();

  /// 改之后的内容。
  TextColumn get after => text()();

  IntColumn get at => integer()();
}
