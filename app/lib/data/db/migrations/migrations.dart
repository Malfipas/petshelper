import 'package:drift/drift.dart';

/// 迁移按版本一步步走，每加一个版本在这里补一个 case。
/// 规矩：只加不改不删；真要改旧列，就新建一列、写过去、旧列留着。
/// 每个 case 必须幂等——跑到一半断了，重跑不能出错。
///
/// 当前版本 1，还没有升级路径。下面第一个 case 是样板，
/// 等真要加字段时照着写，并把 [schemaVersion] 推到 2。
///
/// ```dart
/// if (from < 2) {
///   await m.addColumn(database.settings, database.settings.locale);
/// }
/// ```
///
/// 加列之外还可能要的几种：
/// - 建索引：`await m.createIndex(database.taskItems, 'idx_task_step');`
/// - 回填数据：`await customStatement('UPDATE ...');`
/// - 建新表：`await m.createTable(database.someNewTable);`
MigrationStrategy buildMigrationStrategy() {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // 版本 2 起在这里补 case。当前没有可升级的路径。
    },
    beforeOpen: (details) async {
      // 打开前统一开的开关放这里，例如外键约束：
      // await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
