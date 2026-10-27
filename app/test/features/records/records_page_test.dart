import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart';
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/features/records/records_notifier.dart';
import 'package:ai_pet_assistant/features/records/records_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 第 5 页左栏的界面：格子怎么画、图例怎么高亮、切月与点日期落在哪。
///
/// 色带的拼法与图例的排序在 `records_calendar_test.dart` 覆盖，这里只看像素。
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

  /// 只装记录页，不带路由与窗口。
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: 704, height: 560, child: RecordsPage())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  /// 整组换掉项目步骤，按顺序返回步骤 id。
  Future<List<String>> replaceSteps(String projectId, List<String> names) async {
    final projects = container.read(projectRepositoryProvider);
    await projects.replaceSteps(projectId, names);
    final bundle = await projects.load(projectId);
    final steps = bundle.steps.toList()..sort((a, b) => a.index.compareTo(b.index));
    return [for (final step in steps) step.id];
  }

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

  /// 10 月 23 日：写周报 10 分钟，毕业论文的「写第三章」20 分钟并完成。
  Future<({String solo, String project, String task})> seedOctober() async {
    final solo = await seedSolo('写周报');
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await log(task, DateTime(2026, 10, 23, 11), 1200);
    await finish(task, DateTime(2026, 10, 23, 11, 20));
    return (solo: solo, project: project, task: task);
  }

  Finder cellOf(String date) => find.byKey(ValueKey<String>('records-cell-$date'));

  testWidgets('左栏月历六行七列，右栏报今天且空态只说一句话', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const ValueKey<String>('page-records')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-month'))).data,
        '2026 年 10 月');
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-title'))).data,
        '10 月 24 日 周六');
    expect(cellOf('2026-10-24'), findsOneWidget);
    // 六行七列一共 42 格。
    final cells = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('records-cell-'),
    );
    expect(cells, findsNWidgets(42));
    expect(find.text('这天没有记录'), findsOneWidget);
  });

  testWidgets('件数只写在有完成的日子，0 不写', (tester) async {
    await seedOctober();
    await pumpPage(tester);

    expect(find.byKey(const ValueKey<String>('records-count-2026-10-23')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('records-count-2026-10-24')), findsNothing);
  });

  testWidgets('色带按投入分段：独立事项一段、项目一段，再多没有了', (tester) async {
    await seedOctober();
    await pumpPage(tester);

    expect(find.byKey(const ValueKey<String>('records-bar-2026-10-23')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('records-seg-2026-10-23-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('records-seg-2026-10-23-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('records-seg-2026-10-23-2')), findsNothing);
  });

  testWidgets('点图例只高亮那一项，其余色段压到 25%', (tester) async {
    final seeded = await seedOctober();
    await pumpPage(tester);

    Opacity segment(int index) => tester.widget<Opacity>(
      find.byKey(ValueKey<String>('records-seg-2026-10-23-$index')),
    );
    expect(segment(0).opacity, 1);
    expect(segment(1).opacity, 1);

    await tester.tap(find.byKey(ValueKey<String>('records-legend-${seeded.project}')));
    await tester.pumpAndSettle();

    // 第 0 段是独立事项，被项目的高亮压暗；第 1 段是选中的项目。
    expect(segment(0).opacity, 0.25);
    expect(segment(1).opacity, 1);

    await tester.tap(find.byKey(ValueKey<String>('records-legend-${seeded.project}')));
    await tester.pumpAndSettle();
    expect(segment(0).opacity, 1);
  });

  testWidgets('点箭头换月，点「今天」回来', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey<String>('records-prev')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-month'))).data,
        '2026 年 9 月');
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-title'))).data,
        '9 月 1 日 周二');

    await tester.tap(find.byKey(const ValueKey<String>('records-today')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-month'))).data,
        '2026 年 10 月');
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-title'))).data,
        '10 月 24 日 周六');
  });

  testWidgets('点一格：右栏换成那天，件数与推进的项目数跟着变', (tester) async {
    await seedOctober();
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-title'))).data,
        '10 月 23 日 周五');
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-summary'))).data,
        '完成 1 件 · 推进 1 个项目');
    expect(find.byKey(const ValueKey<String>('records-day-list')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('records-day-empty')), findsNothing);

    await tester.tap(cellOf('2026-10-25'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('records-day-empty')), findsOneWidget);
  });

  testWidgets('项目事项只点「标记完成」、没跑过秒：右栏照样报推进 1 个项目', (tester) async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    await finish(task, DateTime(2026, 10, 23, 15));
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-summary'))).data,
        '完成 1 件 · 推进 1 个项目');
    expect(find.byKey(const ValueKey<String>('records-count-2026-10-23')), findsOneWidget);
    // 没开表就没有色带，格子只留件数。
    expect(find.byKey(const ValueKey<String>('records-bar-2026-10-23')), findsNothing);
  });

  testWidgets('右栏顶部是今日小结，独立事项组排在项目组上面', (tester) async {
    final seeded = await seedOctober();
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('records-day-summary-block')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-summary-facts'))).data,
        '完成 1 件 · 推进 1 个项目 · 投入 30 分钟');

    final solo = find.byKey(const ValueKey<String>('records-group-name-$soloKey'));
    final project = find.byKey(ValueKey<String>('records-group-name-${seeded.project}'));
    expect(solo, findsOneWidget);
    expect(project, findsOneWidget);
    expect(tester.getTopLeft(solo).dy, lessThan(tester.getTopLeft(project).dy));
  });

  testWidgets('项目组头报 2/3、距截止与当天那行推进说明', (tester) async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final steps = await replaceSteps(project, ['开题', '写第三章', '对图表']);
    await container.read(projectRepositoryProvider).setCurrentStep(project, 1);
    await container
        .read(projectRepositoryProvider)
        .setDueAt(project, DateTime(2026, 11, 15).millisecondsSinceEpoch);
    final pick = await seedTaskIn(project, '选题', stepId: steps[0]);
    await finish(pick, DateTime(2026, 10, 23, 10));
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('距截止 23 天'), findsOneWidget);
    expect(find.text('第 1 步 开题 → 已完成，进入第 2 步 写第三章'), findsOneWidget);
    expect(tester.widget<Text>(
      find.byKey(ValueKey<String>('records-group-summary-$project')),
    ).data, '推进 1 项 · 0 分钟');
  });

  testWidgets('条目默认收起，点开露当天明细，再点收起；换日期回来仍是收起', (tester) async {
    final seeded = await seedOctober();
    await log(seeded.solo, DateTime(2026, 10, 24, 9), 300);
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();

    final entryFind = find.byKey(ValueKey<String>('records-day-entry-${seeded.task}'));
    final bodyFind = find.byKey(ValueKey<String>('records-day-body-${seeded.task}'));
    expect(entryFind, findsOneWidget);
    expect(bodyFind, findsNothing);
    // 收起时右上是「20 分钟 · 11:20」。
    expect(find.text('20 分钟 · 11:20'), findsOneWidget);

    await tester.tap(entryFind);
    await tester.pumpAndSettle();
    expect(bodyFind, findsOneWidget);
    expect(find.text('11:20 结束，当天投入 20 分钟。'), findsOneWidget);

    await tester.tap(entryFind);
    await tester.pumpAndSettle();
    expect(bodyFind, findsNothing);

    await tester.tap(entryFind);
    await tester.pumpAndSettle();
    await tester.tap(cellOf('2026-10-24'));
    await tester.pumpAndSettle();
    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();
    expect(bodyFind, findsNothing);
  });

  testWidgets('只标记完成的项目事项也有一条：只报时刻，不提计时', (tester) async {
    final project = await seedProject('毕业论文', DateTime(2026, 1, 1).millisecondsSinceEpoch);
    final task = await seedTaskIn(project, '写第三章');
    await finish(task, DateTime(2026, 10, 23, 15));
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();

    final entryFind = find.byKey(ValueKey<String>('records-day-entry-$task'));
    final bodyFind = find.byKey(ValueKey<String>('records-day-body-$task'));
    expect(entryFind, findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.textContaining('没计时'), findsNothing);

    // 没计时也照样能展开：展开区里还有总结与感想，只是不该有计时那行。
    await tester.tap(entryFind);
    await tester.pumpAndSettle();
    expect(bodyFind, findsNothing);
    expect(find.byKey(ValueKey<String>('records-summary-$task')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('records-thought-$task')), findsOneWidget);
  });

  /// 编辑态里按 Ctrl+Enter 保存。
  Future<void> pressCtrlEnter(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('没配 key：日期下方一行配置提示，展开后那条总结降级成随手记', (tester) async {
    final solo = await seedSolo('写周报');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await container
        .read(noteRepositoryProvider)
        .save(NoteOwner.task, solo, '顺手把模板也改了', base.millisecondsSinceEpoch);
    await pumpPage(tester);

    expect(find.text('请前往设置页配置API key以启用AI总结功能'), findsOneWidget);
    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('records-day-entry-$solo')));
    await tester.pumpAndSettle();

    expect(find.text('未配置 API key，先按随手记整合'), findsNothing);
    expect(find.text('顺手把模板也改了'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
  });

  testWidgets('没写过总结：按钮是「写总结」，写完变正文再变「编辑」', (tester) async {
    final solo = await seedSolo('写周报');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('records-day-entry-$solo')));
    await tester.pumpAndSettle();

    expect(find.text('写总结'), findsOneWidget);
    await tester.tap(find.text('写总结'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '上午把周报的框架定下来了');
    await pressCtrlEnter(tester);

    expect(find.text('上午把周报的框架定下来了'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('感想：虚线框点开写一句，保存后变正文，删除回到虚线框', (tester) async {
    final solo = await seedSolo('写周报');
    await log(solo, DateTime(2026, 10, 23, 10), 600);
    await pumpPage(tester);

    await tester.tap(cellOf('2026-10-23'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('records-day-entry-$solo')));
    await tester.pumpAndSettle();

    // 今日小结与这条各有一个空感想框，这里只点条目里那个。
    final itemThought = find.byKey(ValueKey<String>('records-thought-$solo'));
    await tester.tap(find.descendant(of: itemThought, matching: find.text('今天收获了什么？')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '先列提纲比直接写快');
    await pressCtrlEnter(tester);

    expect(find.text('先列提纲比直接写快'), findsOneWidget);
    expect(find.descendant(of: itemThought, matching: find.text('今天收获了什么？')), findsNothing);

    await tester.tap(find.descendant(of: itemThought, matching: find.text('删除')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: itemThought, matching: find.text('今天收获了什么？')), findsOneWidget);
  });

  testWidgets('今日小结：没配 key 时日期下方挂配置提示，配上后显示日总结', (tester) async {
    final solo = await seedSolo('写周报');
    await log(solo, DateTime(2026, 10, 24, 9), 600);
    await pumpPage(tester);
    expect(find.text('请前往设置页配置API key以启用AI总结功能'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('records-day-summary-ai')), findsNothing);

    await container.read(settingsRepositoryProvider).setKeyConfigured(true);
    await container
        .read(recordRepositoryProvider)
        .setSummary('2026-10-24', '上午推完了第三章，下午在收尾。', base.millisecondsSinceEpoch);
    await container.read(recordCalendarProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('请前往设置页配置API key以启用AI总结功能'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('records-day-summary-ai'))).data,
      '上午推完了第三章，下午在收尾。',
    );
    expect(find.text('今天收获了什么？'), findsWidgets);
  });
}
