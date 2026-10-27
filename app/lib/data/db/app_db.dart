import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'migrations/migrations.dart';
import 'tables/categories.dart';
import 'tables/chat_messages.dart';
import 'tables/daily_records.dart';
import 'tables/ideas.dart';
import 'tables/notes.dart';
import 'tables/progress_entries.dart';
import 'tables/projects.dart';
import 'tables/revisions.dart';
import 'tables/settings.dart';
import 'tables/steps.dart';
import 'tables/task_items.dart';
import 'tables/time_logs.dart';

part 'app_db.g.dart';

/// 应用数据库。当前 schema 版本 1，十二张表。
///
/// 界面不直接用这个类，一律经 Repository；换存储不用改界面。
@DriftDatabase(
  tables: [
    Categories,
    ChatMessages,
    DailyRecords,
    Ideas,
    Notes,
    ProgressEntries,
    Projects,
    Revisions,
    Settings,
    Steps,
    TaskItems,
    TimeLogs,
  ],
)
class AppDb extends _$AppDb {
  AppDb(super.executor);

  /// 测试与内存库用这个。
  AppDb.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => buildMigrationStrategy();

  /// 打开应用数据库。文件落在应用数据目录下的 `app.db`，
  /// 首次打开自动建表；关掉重开数据还在。
  static Future<AppDb> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    final db = AppDb(NativeDatabase(file));
    // 连接是懒开的，跑一句把建表在这时候做掉，不等第一次查询。
    await db.customSelect('SELECT 1').get();
    return db;
  }
}
