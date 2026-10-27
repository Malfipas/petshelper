import 'dart:io';

import 'package:ai_pet_assistant/data/db/app_db.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 十二张表，建库后必须都在。
const _expectedTables = <String>[
  'categories',
  'chat_messages',
  'daily_records',
  'ideas',
  'notes',
  'progress_entries',
  'projects',
  'revisions',
  'settings',
  'steps',
  'task_items',
  'time_logs',
];

void main() {
  group('建库', () {
    late AppDb db;

    setUp(() {
      db = AppDb.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('打开即建齐十二张表', () async {
      final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
      final names = rows.map((r) => r.data['name'] as String).toSet();
      for (final table in _expectedTables) {
        expect(names.contains(table), isTrue, reason: '缺少表 $table');
      }
      expect(
        names.length,
        _expectedTables.length,
        reason: '多出了不该有的表：${names.difference(_expectedTables.toSet())}',
      );
    });

    test('schema 版本为 1', () async {
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], 1);
    });
  });

  group('读写往返', () {
    late AppDb db;

    setUp(() {
      db = AppDb.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('项目、步骤、事项能存能改能删', () async {
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p1',
              name: '毕业论文',
              createdAt: 1000,
              dueAt: const Value(2000),
              currentStep: const Value(1),
            ),
          );
      await db
          .into(db.steps)
          .insert(StepsCompanion.insert(id: 's1', projectId: 'p1', index: 0, name: '读文献'));
      await db
          .into(db.taskItems)
          .insert(
            TaskItemsCompanion.insert(
              id: 't1',
              scope: 'project',
              name: '读两篇参考文献',
              createdAt: 1000,
              projectId: const Value('p1'),
              stepId: const Value('s1'),
            ),
          );

      final project = await db.select(db.projects).getSingle();
      expect(project.name, '毕业论文');
      expect(project.dueAt, 2000);
      expect(project.currentStep, 1);

      final items = await db.select(db.taskItems).get();
      expect(items, hasLength(1));
      expect(items.first.scope, 'project');
      expect(items.first.stepId, 's1');
      expect(items.first.done, isFalse);

      await (db.update(db.taskItems)..where((t) => t.id.equals('t1'))).write(
        const TaskItemsCompanion(done: Value(true), spentSec: Value(90)),
      );
      final updated = await db.select(db.taskItems).getSingle();
      expect(updated.done, isTrue);
      expect(updated.spentSec, 90);

      await (db.delete(db.taskItems)..where((t) => t.id.equals('t1'))).go();
      expect(await db.select(db.taskItems).get(), isEmpty);
    });

    test('随手记按 owner 挂，事项与进度史各挂各的', () async {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: 'n1',
              ownerType: 'task',
              ownerId: 't1',
              body: '顺手把页码标了',
              updatedAt: 1000,
            ),
          );
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: 'n2',
              ownerType: 'history',
              ownerId: 'h1',
              body: '这一步走得顺',
              updatedAt: 1000,
            ),
          );

      final byTask = await (db.select(db.notes)..where((n) => n.ownerId.equals('t1'))).getSingle();
      expect(byTask.body, '顺手把页码标了');
      expect(await db.select(db.notes).get(), hasLength(2));
    });
  });

  group('迁移', () {
    test('v1 的库能升级到 v2：加一列且旧数据还在', () async {
      final tmp = await Directory.systemTemp.createTemp('drift_migration_test');
      final file = File(p.join(tmp.path, 'migrate.db'));

      // 先用当前 schema（v1）建库并写一条数据。
      final v1 = AppDb(NativeDatabase(file));
      await v1
          .into(v1.projects)
          .insert(ProjectsCompanion.insert(id: 'p1', name: '毕业论文', createdAt: 1000));
      await v1.close();

      // 再用一个 schemaVersion 为 2 的子类打开，升级时给 settings 加一列。
      final v2 = _V2Db(NativeDatabase(file));
      try {
        final cols = await v2.customSelect('PRAGMA table_info(settings)').get();
        final names = cols.map((r) => r.data['name'] as String).toList();
        expect(names.contains('locale'), isTrue, reason: '升级后应多出 locale 一列');

        final version = await v2.customSelect('PRAGMA user_version').getSingle();
        expect(version.data['user_version'], 2);

        final projects = await v2.select(v2.projects).get();
        expect(projects, hasLength(1));
        expect(projects.first.name, '毕业论文');
      } finally {
        await v2.close();
        tmp.deleteSync(recursive: true);
      }
    });
  });
}

/// 测试专用：把 schema 推到 2，升级时给 settings 加一列。
/// 这一列是纯 SQL 加的，drift 的数据类还不知道它，只用来证明迁移机制通。
class _V2Db extends AppDb {
  _V2Db(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement('ALTER TABLE settings ADD COLUMN locale TEXT');
      }
    },
  );
}
