import 'package:drift/drift.dart';

/// 设置，只有一行，id 固定为 `app`。
/// API key 本身不在这张表里，只在系统安全存储；这里只记配没配。
class Settings extends Table {
  /// 固定为 `app`。
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  BoolColumn get keyConfigured => boolean().withDefault(const Constant(false))();

  TextColumn get demoUrl => text().withDefault(const Constant(''))();
  TextColumn get repoUrl => text().withDefault(const Constant(''))();

  BoolColumn get bubbleEnabled => boolean().withDefault(const Constant(true))();

  /// 桌宠贴左侧还是右侧：left / right。
  TextColumn get side => text().withDefault(const Constant('left'))();

  /// 桌宠在侧边的纵向位置，0 到 1。
  RealColumn get anchorY => real().withDefault(const Constant(0.5))();
}
