import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart'
    hide Note, Project, ProgressEntry, Step, TaskItem;
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/domain/model/step.dart';
import 'package:ai_pet_assistant/domain/model/task_item.dart';
import 'package:ai_pet_assistant/features/panel/panel_notifier.dart';
import 'package:ai_pet_assistant/features/projects/projects_notifier.dart';
import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// B15 的待办读写与详情里那一摞状态。
///
/// 上半截压数据层：末尾新增、相邻换位、挂步骤；下半截压状态机：取数跟着筛选、
/// 勾选落库、新增的落点。界面尺寸与文案在 `projects_page_test.dart` 里量。
void main() {
  late AppDb db;
  late ProviderContainer container;
  late TimerService timer;
  final base = DateTime(2026, 10, 24, 9);
  late int nowMs;

  setUp(() {
    db = AppDb.memory();
    nowMs = base.millisecondsSinceEpoch;
    timer = TimerService(now: () => nowMs);
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        timerServiceProvider.overrideWithValue(timer),
        projectListProvider.overrideWith(
          () => ProjectListNotifier(
            now: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
            // 600 毫秒的等待在测试里压到 20，中间态还看得到，整套又不用干等。
            doneDelay: const Duration(milliseconds: 20),
            flashDelay: const Duration(milliseconds: 40),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    timer.dispose();
    await db.close();
  });

  ProjectListNotifier notifier() => container.read(projectListProvider.notifier);
  ProjectListState current() => container.read(projectListProvider);

  /// 建一个可能带步骤的项目，返回 id。
  Future<String> seed(String name, [List<String> steps = const []]) async {
    final repo = container.read(projectRepositoryProvider);
    final id = await repo.create(name: name, nowMs: nowMs);
    if (steps.isNotEmpty) await repo.replaceSteps(id, steps);
    return id;
  }

  Future<List<Step>> stepsOf(String id) async {
    final bundle = await container.read(projectRepositoryProvider).load(id);
    return [...bundle.steps]..sort((a, b) => a.index.compareTo(b.index));
  }

  /// 挂在某一步末尾新增一条，`orderIndex` 由 Repository 取末尾。
  Future<String> addItem(String projectId, String stepId, String name) => container
      .read(taskRepositoryProvider)
      .addToStep(projectId: projectId, stepId: stepId, name: name, nowMs: nowMs);

  group('数据层 · 末尾新增', () {
    test('orderIndex 取该步最大加一；删过中间一条也不撞号', () async {
      final id = await seed('甲', ['一', '二']);
      final steps = await stepsOf(id);
      final tasks = container.read(taskRepositoryProvider);

      final a = await addItem(id, steps[0].id, 'A');
      final b = await addItem(id, steps[0].id, 'B');
      final c = await addItem(id, steps[1].id, 'C');

      expect((await tasks.byId(a))!.orderIndex, 0);
      expect((await tasks.byId(b))!.orderIndex, 1);
      // 另一步自己从头数，不跟这一步连着。
      expect((await tasks.byId(c))!.orderIndex, 0);

      await tasks.delete(a);
      final d = await addItem(id, steps[0].id, 'D');
      expect((await tasks.byId(d))!.orderIndex, 2);
    });

    test('新增的事项是项目的待办，没挂步骤时没有 stepId', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;

      final added = await addItem(id, step.id, '补第三章');
      final task = await container.read(taskRepositoryProvider).byId(added);

      expect(task!.scope, TaskScope.project);
      expect(task.projectId, id);
      expect(task.stepId, step.id);
      expect(task.done, isFalse);
    });
  });

  group('数据层 · 相邻换位', () {
    test('中间两条互换编号；到头返 false 且不动库', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final tasks = container.read(taskRepositoryProvider);
      final a = await addItem(id, step.id, 'A');
      final b = await addItem(id, step.id, 'B');
      final c = await addItem(id, step.id, 'C');

      expect(await tasks.moveOrder(b, -1), isTrue);
      expect((await tasks.byId(b))!.orderIndex, 0);
      expect((await tasks.byId(a))!.orderIndex, 1);
      expect((await tasks.byId(c))!.orderIndex, 2);

      // B 已经在头、C 已经在尾，两下都返回 false，编号原样。
      expect(await tasks.moveOrder(b, -1), isFalse);
      expect(await tasks.moveOrder(c, 1), isFalse);
      expect((await tasks.byId(b))!.orderIndex, 0);
      expect((await tasks.byId(c))!.orderIndex, 2);
    });

    test('跨步不换：另一条在别的步里时，同一步只剩自己就返 false', () async {
      final id = await seed('甲', ['一', '二']);
      final steps = await stepsOf(id);
      final tasks = container.read(taskRepositoryProvider);
      final a = await addItem(id, steps[0].id, 'A');
      final solo = await addItem(id, steps[1].id, 'S');

      expect(await tasks.moveOrder(solo, 1), isFalse);
      expect((await tasks.byId(solo))!.stepId, steps[1].id);
      expect((await tasks.byId(solo))!.orderIndex, 0);
      expect((await tasks.byId(a))!.orderIndex, 0);
      // 不存在的那条也当没发生。
      expect(await tasks.moveOrder('t_missing', 1), isFalse);
    });
  });

  group('数据层 · 挂步骤', () {
    test('挂过去排在末尾，原来的位置空出来', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final tasks = container.read(taskRepositoryProvider);
      await addItem(id, step.id, '已经在步里的');
      final moved = await tasks.createForProject(
        projectId: id,
        name: '从独立事项移入的',
        nowMs: nowMs,
        source: TaskSource.moved,
      );
      expect((await tasks.byId(moved))!.stepId, isNull);

      await tasks.assignToStep(taskId: moved, stepId: step.id);

      final after = (await tasks.byId(moved))!;
      expect(after.stepId, step.id);
      expect(after.orderIndex, 1);
    });
  });

  group('数据层 · 随手记', () {
    test('写进去读得回，写空白等于清掉', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final taskId = await addItem(id, step.id, 'A');
      final notes = container.read(noteRepositoryProvider);

      await notes.save(NoteOwner.task, taskId, '写了一半', nowMs);
      expect(await notes.textOf(NoteOwner.task, taskId), '写了一半');

      await notes.save(NoteOwner.task, taskId, '', nowMs);
      expect(await notes.textOf(NoteOwner.task, taskId), '');
    });
  });

  group('状态机 · 取数', () {
    test('展开只列当前步未完成的事项；未分配的进移入块', () async {
      final id = await seed('甲', ['一', '二', '三']);
      final steps = await stepsOf(id);
      final tasks = container.read(taskRepositoryProvider);
      final a = await addItem(id, steps[0].id, 'A');
      final b = await addItem(id, steps[0].id, 'B');
      final c = await addItem(id, steps[1].id, 'C');
      final done = await addItem(id, steps[0].id, '做过的');
      await tasks.setDone(done, true, nowMs);
      final moved = await tasks.createForProject(
        projectId: id,
        name: '移来的',
        nowMs: nowMs,
        source: TaskSource.moved,
      );

      await notifier().reload();
      await notifier().open(id);

      // 没起步的项目默认筛第一步。
      expect(current().filterStep, 0);
      expect(current().detailTasks.map((task) => task.id), [a, b]);
      expect(current().movedTasks.map((task) => task.id), [moved]);

      await notifier().clearFilter();
      expect(current().filterStep, isNull);
      // 不筛就是三步里全部未完成，按 orderIndex 排。
      expect(current().detailTasks.map((task) => task.id), [a, b, c]);

      await notifier().tapSegment(1);
      expect(current().filterStep, 1);
      expect(current().detailTasks.map((task) => task.id), [c]);
    });

    test('一条待办都没有时列表是空的，筛选停在新建自带的步骤 1', () async {
      final id = await seed('空的');
      await notifier().reload();
      await notifier().open(id);

      // 使用者 2026-10-26：新建项目自带「步骤 1」，所以这里不再是没步骤的空流程。
      expect(current().detailSteps.map((step) => step.name), ['步骤 1']);
      expect(current().filterStep, 0);
      expect(current().detailTasks, isEmpty);
      expect(current().movedTasks, isEmpty);
    });

    test('随手记跟着事项一起读进状态，清空后也从状态里消失', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final taskId = await addItem(id, step.id, 'A');
      await container.read(noteRepositoryProvider).save(NoteOwner.task, taskId, '写了一半', nowMs);
      await notifier().reload();
      await notifier().open(id);

      expect(current().notes[taskId], '写了一半');

      await notifier().saveNote(taskId, '   ');
      expect(current().notes.containsKey(taskId), isFalse);
      expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId), '');
    });
  });

  group('状态机 · 勾完成', () {
    test('先挂进 pendingDone，到点落库移出，只写一条进度史', () async {
      final id = await seed('甲', ['一', '二']);
      final steps = await stepsOf(id);
      final taskId = await addItem(id, steps[0].id, 'A');
      await container.read(noteRepositoryProvider).save(NoteOwner.task, taskId, '这一步的成果', nowMs);
      await notifier().reload();
      await notifier().open(id);

      final pending = notifier().toggleTaskDone(taskId);
      expect(current().pendingDone, contains(taskId));
      await pending;

      final tasks = container.read(taskRepositoryProvider);
      expect((await tasks.byId(taskId))!.done, isTrue);
      expect((await tasks.byId(taskId))!.doneAt, nowMs);
      final bundle = await container.read(projectRepositoryProvider).load(id);
      expect(bundle.progress.map((entry) => entry.content), ['完成「A」']);

      // 再点一次：已经完成，进度史不追加第二条。
      await notifier().toggleTaskDone(taskId);
      expect(
        (await container.read(projectRepositoryProvider).load(id)).progress
            .map((entry) => entry.content),
        ['完成「A」'],
      );
      expect(current().pendingDone, isEmpty);
      expect(current().detailTasks, isEmpty);
    });

    test('勾完顺手刷新列表卡片，下一步跟着换', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final first = await addItem(id, step.id, '先做的');
      final second = await addItem(id, step.id, '后做的');
      await notifier().reload();
      await notifier().open(id);

      await notifier().toggleTaskDone(first);

      expect(current().detailTasks.map((task) => task.id), [second]);
      expect(current().rows.single.nextStep, '后做的');
    });
  });

  group('状态机 · 换位与挂步骤', () {
    test('↑↓ 改状态里的顺序，也改库里的编号', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final a = await addItem(id, step.id, 'A');
      final b = await addItem(id, step.id, 'B');
      await notifier().reload();
      await notifier().open(id);

      await notifier().moveTask(b, -1);
      expect(current().detailTasks.map((task) => task.id), [b, a]);

      await notifier().moveTask(a, -1);
      expect(current().detailTasks.map((task) => task.id), [a, b]);

      // 到头不动：状态与库都保持原样。
      await notifier().moveTask(a, -1);
      expect(current().detailTasks.map((task) => task.id), [a, b]);
      expect((await container.read(taskRepositoryProvider).byId(a))!.orderIndex, 0);
    });

    test('选步骤后从移入块消失，筛选切到该步并闪一下', () async {
      final id = await seed('甲', ['一', '二']);
      final steps = await stepsOf(id);
      final tasks = container.read(taskRepositoryProvider);
      final already = await addItem(id, steps[1].id, '第二步的');
      final moved = await tasks.createForProject(
        projectId: id,
        name: '移来的',
        nowMs: nowMs,
        source: TaskSource.moved,
      );
      await notifier().reload();
      await notifier().open(id);

      notifier().askAssign(moved);
      expect(current().assigningTaskId, moved);

      await notifier().assignStep(moved, steps[1].id);

      expect(current().assigningTaskId, isNull);
      expect(current().movedTasks, isEmpty);
      expect(current().filterStep, 1);
      expect(current().flashTaskId, moved);
      expect(current().detailTasks.map((task) => task.id), [already, moved]);
      expect((await tasks.byId(moved))!.stepId, steps[1].id);
    });

    test('取消选步骤只收下拉，不改库', () async {
      final id = await seed('甲', ['一']);
      final moved = await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: id, name: '移来的', nowMs: nowMs, source: TaskSource.moved);
      await notifier().reload();
      await notifier().open(id);

      notifier().askAssign(moved);
      notifier().cancelAssign();

      expect(current().assigningTaskId, isNull);
      expect(current().movedTasks.map((task) => task.id), [moved]);
      expect((await container.read(taskRepositoryProvider).byId(moved))!.stepId, isNull);
    });
  });

  group('状态机 · 行内新增', () {
    test('提交后落该步末尾、切筛选、闪一下', () async {
      final id = await seed('甲', ['一', '二']);
      final steps = await stepsOf(id);
      await container.read(projectRepositoryProvider).setCurrentStep(id, 1);
      await notifier().reload();
      await notifier().open(id);
      expect(current().filterStep, 1);

      notifier().openAddTask(steps[0].id);
      expect(current().addTaskFor, steps[0].id);

      final ok = await notifier().addTask('  补第三章  ');

      expect(ok, isTrue);
      expect(current().addTaskFor, isNull);
      expect(current().filterStep, 0);
      final added = current().detailTasks.single;
      expect(added.name, '补第三章');
      expect(added.stepId, steps[0].id);
      expect(added.orderIndex, 0);
      expect(current().flashTaskId, added.id);
      expect((await stepsOf(id)).first.id, steps[0].id);
    });

    test('内容空白不写库，输入行还开着', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      await notifier().reload();
      await notifier().open(id);
      notifier().openAddTask(step.id);

      expect(await notifier().addTask('   '), isFalse);
      expect(current().addTaskFor, step.id);
      expect(await container.read(taskRepositoryProvider).byProject(id), isEmpty);
    });

    test('闪一下到点自己复原', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      await notifier().reload();
      await notifier().open(id);
      notifier().openAddTask(step.id);

      await notifier().addTask('闪一下');
      expect(current().flashTaskId, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(current().flashTaskId, isNull);
    });
  });

  group('状态机 · 开始', () {
    test('开表并成为面板的当前事务；第二件在跑时不再接', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final first = await addItem(id, step.id, 'A');
      final second = await addItem(id, step.id, 'B');
      await notifier().reload();
      await notifier().open(id);

      expect(await notifier().startTask(first), isTrue);
      final panel = container.read(panelNotifierProvider);
      expect(panel.running, isTrue);
      expect(panel.taskId, first);

      // 只有一只表：另一件在跑时点第二件，返回 false 且面板不被顶掉。
      expect(await notifier().startTask(second), isFalse);
      expect(container.read(panelNotifierProvider).taskId, first);
    });

    test('已完成的与不存在的不开表', () async {
      final id = await seed('甲', ['一']);
      final step = (await stepsOf(id)).first;
      final taskId = await addItem(id, step.id, 'A');
      await container.read(taskRepositoryProvider).setDone(taskId, true, nowMs);
      await notifier().reload();
      await notifier().open(id);

      expect(await notifier().startTask(taskId), isFalse);
      expect(await notifier().startTask('t_missing'), isFalse);
      expect(container.read(panelNotifierProvider).running, isFalse);
    });
  });

  test('Esc 五层：弹窗 > 行内新增 > 选步骤 > 编辑器 > 详情', () async {
    final id = await seed('甲', ['一']);
    final step = (await stepsOf(id)).first;
    final moved = await container
        .read(taskRepositoryProvider)
        .createForProject(projectId: id, name: '移来的', nowMs: nowMs, source: TaskSource.moved);
    await notifier().reload();
    await notifier().open(id);
    notifier().toggleFlowEdit();
    notifier().openAddTask(step.id);
    notifier().askAssign(moved);
    notifier().askDelete();

    expect(notifier().collapse(), isTrue);
    expect(current().confirming, isFalse);
    expect(current().addTaskFor, step.id);

    expect(notifier().collapse(), isTrue);
    expect(current().addTaskFor, isNull);
    expect(current().assigningTaskId, moved);

    expect(notifier().collapse(), isTrue);
    expect(current().assigningTaskId, isNull);
    expect(current().flowEditing, isTrue);

    expect(notifier().collapse(), isTrue);
    expect(current().flowEditing, isFalse);
    expect(current().openId, id);

    expect(notifier().collapse(), isTrue);
    expect(current().openId, isNull);

    expect(notifier().collapse(), isFalse);
  });
}
