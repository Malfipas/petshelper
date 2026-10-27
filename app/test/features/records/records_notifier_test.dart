import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart';
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/features/records/records_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录页左栏的取数与切月规则。
///
/// 数据全从 Repository 造：建事项、记流水、勾完成，页面只读。
void main() {
  late AppDb db;
  late ProviderContainer container;

  /// 固定「今天」：2026-10-24 是周六。
  final base = DateTime(2026, 10, 24, 9);

  setUp(() {
    db = AppDb.memory();
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        recordCalendarProvider.overrideWith(
          () => RecordCalendarNotifier(now: () => base),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 页面一建就异步读一遍月数据，测试要等它落定。
  Future<RecordCalendarNotifier> boot() async {
    final notifier = container.read(recordCalendarProvider.notifier);
    await notifier.refresh();
    return notifier;
  }

  Future<String> seedSolo(String name) => container
      .read(taskRepositoryProvider)
      .createSolo(name: name, nowMs: base.millisecondsSinceEpoch);

  Future<String> seedProject(String name, int createdAtMs) =>
      container.read(projectRepositoryProvider).create(name: name, nowMs: createdAtMs);

  Future<String> seedTaskIn(String projectId, String name, {String? stepId}) =>
      container
          .read(taskRepositoryProvider)
          .createForProject(
            projectId: projectId,
            name: name,
            stepId: stepId,
            nowMs: base.millisecondsSinceEpoch,
          );

  /// 重建项目的步骤，按顺序返回步骤 id。
  ///
  /// 新建项目自带「步骤 1」，这里整组换掉，测试才能按自己的流程编号断言。
  Future<List<String>> replaceSteps(String projectId, List<String> names) async {
    final projects = container.read(projectRepositoryProvider);
    await projects.replaceSteps(projectId, names);
    final bundle = await projects.load(projectId);
    final steps = bundle.steps.toList()..sort((a, b) => a.index.compareTo(b.index));
    return [for (final step in steps) step.id];
  }

  /// 项目当前推进到第几步（0 基）。
  Future<void> setCurrentStep(String projectId, int index) =>
      container.read(projectRepositoryProvider).setCurrentStep(projectId, index);

  /// 在某个时刻记一段投入。
  Future<void> log(String taskId, DateTime at, int seconds) => container
      .read(taskRepositoryProvider)
      .logSession(
        taskId: taskId,
        startedAt: at.millisecondsSinceEpoch,
        endedAt: at.millisecondsSinceEpoch + seconds * 1000,
        seconds: seconds,
      );

  Future<void> finish(String taskId, DateTime at) => container
      .read(taskRepositoryProvider)
      .setDone(taskId, true, at.millisecondsSinceEpoch);

  test('打开就落在今天所在的月：六行七列，选中今天', () async {
    await boot();
    final state = container.read(recordCalendarProvider);

    expect(state.year, 2026);
    expect(state.month, 10);
    expect(state.selected, '2026-10-24');
    expect(state.cells, hasLength(42));
    expect(state.loading, isFalse);
  });

  test('一天完成两件、开了两段表：格子报件数，色带独立事项在前', () async {
    final solo = await seedSolo('写周报');
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await log(task, DateTime(2026, 10, 23, 11), 1200);
    await finish(solo, DateTime(2026, 10, 23, 10, 10));
    await finish(task, DateTime(2026, 10, 23, 11, 20));

    await boot();
    final stat = container.read(recordCalendarProvider).statOf('2026-10-23');

    expect(stat, isNotNull);
    expect(stat!.doneCount, 2);
    expect(stat.segments.map((segment) => segment.key).toList(), [soloKey, project]);
    expect(stat.segments.first.seconds, 600);
    expect(stat.segments.last.seconds, 1200);
  });

  test('项目色按新建先后固定：先建的是第一色，后建的第二色', () async {
    final first = await seedProject('先建的', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final second = await seedProject('后建的', DateTime(2026, 2, 1).millisecondsSinceEpoch);
    await log(await seedTaskIn(first, 'A'), DateTime(2026, 10, 20, 10), 60);
    await log(await seedTaskIn(second, 'B'), DateTime(2026, 10, 20, 11), 60);

    await boot();
    final colors = container.read(recordCalendarProvider).projectColors;

    expect(colors[first], projectPalette[0]);
    expect(colors[second], projectPalette[1]);
  });

  test('切上个月：月份跟着退，选中落到那个月 1 号', () async {
    final notifier = await boot();
    await notifier.previousMonth();

    final state = container.read(recordCalendarProvider);
    expect(state.year, 2026);
    expect(state.month, 9);
    expect(state.selected, '2026-09-01');
    expect(state.cells.first.date, DateTime(2026, 8, 31));
  });

  test('切过月再点「今天」：月份与选中一起回来', () async {
    final notifier = await boot();
    await notifier.previousMonth();
    await notifier.previousMonth();
    await notifier.goToday();

    final state = container.read(recordCalendarProvider);
    expect(state.month, 10);
    expect(state.selected, '2026-10-24');
  });

  test('点日期只换右栏：件数、推进的项目数与清单跟着走', () async {
    final solo = await seedSolo('写周报');
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await log(task, DateTime(2026, 10, 23, 11), 1200);
    await finish(task, DateTime(2026, 10, 23, 11, 20));

    final notifier = await boot();
    await notifier.select('2026-10-23');

    var state = container.read(recordCalendarProvider);
    expect(state.selected, '2026-10-23');
    expect(state.dayEntries, hasLength(2));
    expect(state.dayDoneCount, 1);
    expect(state.dayProjectCount, 1);
    // 独立事项一组在前，项目一组在后。
    expect(state.dayGroups.map((group) => group.key), [soloKey, project]);
    expect(state.dayGroups.last.items.single.task.id, task);

    await notifier.select('2026-10-24');
    state = container.read(recordCalendarProvider);
    expect(state.dayEntries, isEmpty);
    expect(state.dayDoneCount, 0);
    expect(state.dayProjectCount, 0);
  });

  test('图例点一下高亮，再点同一个键取消', () async {
    final solo = await seedSolo('写周报');
    await log(solo, DateTime(2026, 10, 23, 10), 600);

    final notifier = await boot();
    expect(container.read(recordCalendarProvider).legend.single.key, soloKey);

    notifier.toggleHighlight(soloKey);
    expect(container.read(recordCalendarProvider).highlight, soloKey);

    notifier.toggleHighlight(soloKey);
    expect(container.read(recordCalendarProvider).highlight, isNull);
  });

  test('项目事项只点「标记完成」、没跑过秒：件数算 1，推进项目也算 1', () async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    // 没有流水：面板里点「标记完成」只写 doneAt。
    await finish(task, DateTime(2026, 10, 23, 15));

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final state = container.read(recordCalendarProvider);

    // 件数把项目事项一起算（PRD「完成 5 件 · 推进 2 个项目」），但推进不能因此掉成 0。
    expect(state.dayDoneCount, 1);
    expect(state.dayProjectCount, 1);
    expect(state.dayProjects['2026-10-23'], {project});
    // 没开表就没有投入，色带不画。
    expect(state.statOf('2026-10-23')!.segments, isEmpty);
    // 但右栏里得有这一条，不然点开这天看不到做完了什么。
    expect(state.dayEntries.single.task.id, task);
    final group = state.dayGroups.single;
    expect(group.name, '毕业论文');
    expect(group.items.single.task.id, task);
    expect(group.seconds, 0);
  });

  test('同一天一个项目既开了表又完成了一件：项目只算一次', () async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final first = await seedTaskIn(project, '写第三章');
    final second = await seedTaskIn(project, '整理图表');
    await log(first, DateTime(2026, 10, 23, 10), 900);
    await finish(second, DateTime(2026, 10, 23, 16));

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final state = container.read(recordCalendarProvider);

    expect(state.dayDoneCount, 1);
    expect(state.dayProjectCount, 1);
    expect(state.statOf('2026-10-23')!.segments.map((segment) => segment.key), [project]);
  });

  test('只完成独立事项的日子：推进项目数为 0', () async {
    final solo = await seedSolo('写周报');
    await finish(solo, DateTime(2026, 10, 23, 15));

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final state = container.read(recordCalendarProvider);

    expect(state.dayDoneCount, 1);
    expect(state.dayProjectCount, 0);
    expect(state.dayProjects['2026-10-23'], isNull);
  });

  test('项目组头：当前步/总步，当天收尾那一步写「已完成，进入下一步」', () async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final steps = await replaceSteps(project, ['开题', '写第三章', '对图表']);
    await setCurrentStep(project, 1);

    final pick = await seedTaskIn(project, '选题', stepId: steps[0]);
    final read = await seedTaskIn(project, '查资料', stepId: steps[0]);
    final write = await seedTaskIn(project, '写正文', stepId: steps[1]);
    await finish(pick, DateTime(2026, 10, 23, 10));
    await finish(read, DateTime(2026, 10, 23, 15));
    await log(write, DateTime(2026, 10, 23, 16), 600);

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final group = container.read(recordCalendarProvider).dayGroups.single;

    expect(group.stepNow, 2);
    expect(group.stepTotal, 3);
    // 开题这一步当天全做完了，说明里直接点出下一步。
    expect(group.stepNote, '第 1 步 开题 → 已完成，进入第 2 步 写第三章');
  });

  test('那一步还剩没做完的事，推进说明写「推进中」', () async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final steps = await replaceSteps(project, ['开题']);
    await setCurrentStep(project, 0);

    final pick = await seedTaskIn(project, '选题', stepId: steps[0]);
    await seedTaskIn(project, '查资料', stepId: steps[0]);
    await finish(pick, DateTime(2026, 10, 23, 15));

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final group = container.read(recordCalendarProvider).dayGroups.single;

    expect(group.stepNote, '第 1 步 开题 推进中');
  });

  test('没有步骤的项目：组头不报 3/7，也不出推进说明', () async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    await replaceSteps(project, const <String>[]);
    final task = await seedTaskIn(project, '写第三章');
    await finish(task, DateTime(2026, 10, 23, 15));

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final group = container.read(recordCalendarProvider).dayGroups.single;

    expect(group.stepTotal, 0);
    expect(stepBadge(group.stepNow, group.stepTotal), '');
    expect(group.stepNote, isNull);
  });

  test('组内条目按当天时刻升序：先做的在上', () async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final early = await seedTaskIn(project, '写第三章');
    final late = await seedTaskIn(project, '整理图表');
    await log(late, DateTime(2026, 10, 23, 20), 300);
    await log(early, DateTime(2026, 10, 23, 10), 600);

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final group = container.read(recordCalendarProvider).dayGroups.single;

    expect(group.items.map((item) => item.task.id), [early, late]);
  });

  test('项目组按当天投入从多到少；独立事项组固定排在最前', () async {
    final solo = await seedSolo('写周报');
    final heavy = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final light = await seedProject('健身计划', DateTime(2026, 1, 2).millisecondsSinceEpoch);
    final soloTask = solo;
    final heavyTask = await seedTaskIn(heavy, '写第三章');
    final lightTask = await seedTaskIn(light, '跑步');
    await log(soloTask, DateTime(2026, 10, 23, 9), 300);
    await log(heavyTask, DateTime(2026, 10, 23, 11), 3600);
    await log(lightTask, DateTime(2026, 10, 23, 19), 1200);

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final groups = container.read(recordCalendarProvider).dayGroups;

    expect(groups.map((group) => group.key), [soloKey, heavy, light]);
    expect(groupSummaryLabel(groups[1]), '推进 1 项 · 60 分钟');
  });

  test('点一条展开再点收起；换日期后都回到收起', () async {
    final solo = await seedSolo('写周报');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await log(solo, DateTime(2026, 10, 24, 10), 600);

    final notifier = await boot();
    await notifier.select('2026-10-23');
    notifier.toggleOpen(solo);
    expect(container.read(recordCalendarProvider).openKeys, {solo});

    notifier.toggleOpen(solo);
    expect(container.read(recordCalendarProvider).openKeys, isEmpty);

    notifier.toggleOpen(solo);
    await notifier.select('2026-10-24');
    expect(container.read(recordCalendarProvider).openKeys, isEmpty);
  });

  test('今日小结的投入合计按当天所有条目累加', () async {
    final solo = await seedSolo('写周报');
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await log(task, DateTime(2026, 10, 23, 11), 900);

    final notifier = await boot();
    await notifier.select('2026-10-23');
    final state = container.read(recordCalendarProvider);

    expect(state.daySeconds, 1500);
    expect(groupMinutesLabel(state.daySeconds), '25 分钟');
  });

  test('一件没有的月份：件数 0、没有色带、图例空着', () async {
    await boot();
    final state = container.read(recordCalendarProvider);

    expect(state.stats, isEmpty);
    expect(state.legend, isEmpty);
    expect(state.statOf('2026-10-24'), isNull);
    expect(state.dayEntries, isEmpty);
  });

  group('感想与总结', () {
    test('写下的感想读得回来，重新加载也还在', () async {
      final solo = await seedSolo('整理照片');
      await log(solo, DateTime(2026, 10, 23, 9), 600);
      final notifier = await boot();
      await notifier.select('2026-10-23');
      final key = entryTextKey('2026-10-23', soloKey, solo);

      expect(container.read(recordCalendarProvider).textsOf(key).thought, isEmpty);
      await notifier.saveThought(groupKey: soloKey, itemId: solo, text: '今天顺手多了');
      expect(container.read(recordCalendarProvider).textsOf(key).thought, '今天顺手多了');

      await notifier.refresh();
      expect(container.read(recordCalendarProvider).textsOf(key).thought, '今天顺手多了');
    });

    test('今日小结的感想与条目的感想各存一条', () async {
      final solo = await seedSolo('写周报');
      await log(solo, DateTime(2026, 10, 24, 9), 600);
      final notifier = await boot();
      final dayKey = dayTextKey('2026-10-24');
      final itemKey = entryTextKey('2026-10-24', soloKey, solo);

      await notifier.saveDayThought('今天先理了思路');
      final state = container.read(recordCalendarProvider);
      expect(state.textsOf(dayKey).thought, '今天先理了思路');
      expect(state.textsOf(itemKey).thought, isEmpty);

      await notifier.saveThought(groupKey: soloKey, itemId: solo, text: '顺手');
      final next = container.read(recordCalendarProvider);
      expect(next.textsOf(itemKey).thought, '顺手');
      expect(next.textsOf(dayKey).thought, '今天先理了思路');
    });

    test('把感想清空就是删掉', () async {
      final solo = await seedSolo('写周报');
      final notifier = await boot();
      await notifier.saveThought(groupKey: soloKey, itemId: solo, text: '先说一句');
      await notifier.saveThought(groupKey: soloKey, itemId: solo, text: '');

      expect(
        container.read(recordCalendarProvider).textsOf(entryTextKey('2026-10-24', soloKey, solo)).thought,
        isEmpty,
      );
    });

    test('改过的总结盖过生成值，重新加载也不变', () async {
      final solo = await seedSolo('写周报');
      await log(solo, DateTime(2026, 10, 24, 9), 600);
      final notifier = await boot();
      final key = entryTextKey('2026-10-24', soloKey, solo);

      await notifier.saveEntrySummary(groupKey: soloKey, taskId: solo, text: '我自己写的一段');
      await notifier.refresh();

      final texts = container.read(recordCalendarProvider).textsOf(key);
      expect(texts.userSummary, '我自己写的一段');
      expect(texts.summaryOf(hasKey: true).kind, EntrySummaryKind.mine);
    });

    test('没配 key 时状态里就是没配；配上之后重新加载变成配了', () async {
      final notifier = await boot();
      expect(container.read(recordCalendarProvider).hasKey, isFalse);

      await container.read(settingsRepositoryProvider).setKeyConfigured(true);
      await notifier.refresh();
      expect(container.read(recordCalendarProvider).hasKey, isTrue);
    });

    test('没配 key 时那条走降级：正文就是随手记原文', () async {
      final solo = await seedSolo('写周报');
      await log(solo, DateTime(2026, 10, 24, 9), 600);
      await container
          .read(noteRepositoryProvider)
          .save(NoteOwner.task, solo, '记了两句', base.millisecondsSinceEpoch);
      await boot();
      final state = container.read(recordCalendarProvider);
      final key = entryTextKey('2026-10-24', soloKey, solo);

      expect(state.textsOf(key).scratch, '记了两句');
      final summary = state.textsOf(key).summaryOf(hasKey: state.hasKey);
      expect(summary.kind, EntrySummaryKind.degraded);
      expect(summary.text, '记了两句');
    });
  });
}
