import 'package:ai_pet_assistant/app/app.dart';
import 'package:ai_pet_assistant/app/main_shell.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/app/theme.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Note, TaskItem;
import 'package:ai_pet_assistant/domain/model/task_item.dart';
import 'package:ai_pet_assistant/features/panel/panel_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_frame.dart';
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:ai_pet_assistant/features/projects/project_todo.dart';
import 'package:ai_pet_assistant/features/projects/projects_notifier.dart';
import 'package:ai_pet_assistant/features/projects/projects_page.dart';
import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_pet_stage_port.dart';

/// 项目页的界面行为。
///
/// 断言只写原型上看得见的东西：谁在页头、卡片长什么样、点一下落到哪。
/// 百分比与相对日期的算法在 `projects_notifier_test.dart` 里覆盖，这里不重复。
void main() {
  late AppDb db;
  late ProviderContainer container;
  late TimerService timer;
  late FakePetStagePort port;
  late int nowMs;

  final base = DateTime(2026, 10, 24, 9);

  /// 面板档的窗口，整壳用例要真有路由与窗口框才落得下去。
  const appFrame = PetFrame(
    size: Size(800, 600),
    pet: Rect.fromLTWH(560, 360, 240, 240),
    panel: Rect.fromLTWH(380, 100, 390, 380),
    main: Rect.fromLTWH(0, 0, 800, 600),
  );

  setUp(() {
    db = AppDb.memory();
    port = FakePetStagePort();
    nowMs = base.millisecondsSinceEpoch;
    timer = TimerService(now: () => nowMs);
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        timerServiceProvider.overrideWithValue(timer),
        petStagePortProvider.overrideWithValue(port),
        petPollIntervalProvider.overrideWithValue(null),
        petReportLingerProvider.overrideWithValue(null),
        // 相对日期按 `nowMs` 算，测试不会因为跑的时间跨天而翻成「昨天」。
        projectListProvider.overrideWith(
          () => ProjectListNotifier(now: () => DateTime.fromMillisecondsSinceEpoch(nowMs)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    port.dispose();
    timer.dispose();
    await db.close();
  });

  Future<String> seedProject(String name, {String description = '', int? dueAt, int? createdAt}) {
    return container
        .read(projectRepositoryProvider)
        .create(name: name, description: description, dueAt: dueAt, nowMs: createdAt ?? nowMs);
  }

  /// 造「已完成 N 步」：步骤状态只有流程推进才会改，测试里直接落库。
  Future<void> markStepsDone(String projectId, int count) async {
    await (db.update(db.steps)
          ..where((row) => row.projectId.equals(projectId) & row.index.isSmallerThanValue(count)))
        .write(const StepsCompanion(state: Value<String>('done')));
  }

  /// 只装这一页，不带路由与窗口。
  Future<void> pumpPage(WidgetTester tester, {String? projectId}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 704, height: 560, child: ProjectsPage(projectId: projectId)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 桌宠页有常驻待机动画，`pumpAndSettle` 等不到静止，这里按帧推进。
  Future<void> settle(WidgetTester tester, {int steps = 20}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    container.read(petFrameProvider.notifier).apply(appFrame);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AiPetApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openProjectsTab(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('tab-projects')));
    await tester.pumpAndSettle();
  }

  testWidgets('页头写着「我的项目」、件数与新建键', (tester) async {
    await seedProject('甲');
    await pumpPage(tester);

    final title = tester.widget<Text>(find.text('我的项目'));
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(find.text('1 个项目'), findsOneWidget);

    final newBtn = tester.getSize(find.byKey(const ValueKey<String>('proj-new')));
    expect(newBtn.height, 34);
  });

  testWidgets('空态只说一句话，正中不再摆第二枚新建按钮', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const ValueKey<String>('proj-empty')), findsOneWidget);
    expect(find.text('还没有项目'), findsOneWidget);
    // 使用者 2026-10-26：撤掉空态正中那枚入口，入口只留顶上的一处。
    expect(find.byKey(const ValueKey<String>('proj-empty-new')), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('项目卡标记键：首个未完成步骤的首个未完成事项进面板，表不走', (tester) async {
    final id = await seedProject('毕业论文');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['开题', '做初稿']);
    final steps = (await container.read(projectRepositoryProvider).load(id)).steps;
    final firstStep = steps.reduce((a, b) => a.index <= b.index ? a : b);
    final firstId = await container.read(taskRepositoryProvider).createForProject(
      projectId: id,
      name: '写开题报告',
      stepId: firstStep.id,
      nowMs: nowMs,
    );
    await pumpApp(tester);
    await openProjectsTab(tester);

    await tester.tap(find.byKey(ValueKey<String>('proj-mark-$id')));
    await settle(tester);

    // 《页面操作流程》第 7 节：项目名右侧的标记键把首个未完成事项摆进小任务窗口，不开始计时。
    final panel = container.read(panelNotifierProvider);
    expect(panel.taskId, firstId);
    expect(panel.running, isFalse);
    expect(find.byKey(const ValueKey<String>('panel-start')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('main-shell')), findsNothing);
  });

  testWidgets('详情页截止日期随时可改：没设时显示「设置截止日期」，点开是日期选择器', (tester) async {
    final id = await seedProject('毕业论文');
    await pumpPage(tester, projectId: id);

    // 《页面操作流程》第 7 节：新建时没选截止日期，也能在详情里补上。
    expect(find.byKey(const ValueKey<String>('proj-due-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('proj-due-empty')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // 收掉弹层，别把它留给下一条用例。
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('已经设过截止日期的项目，那一格照样能点开重设', (tester) async {
    final id = await seedProject(
      '有截止的',
      dueAt: DateTime(2026, 10, 31).millisecondsSinceEpoch,
    );
    await pumpPage(tester, projectId: id);

    final due = find.byKey(const ValueKey<String>('proj-due'));
    expect(due, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('proj-due-empty')), findsNothing);

    await tester.tap(due);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
  });

  testWidgets('新建表单：空名点不动、重名给红字、取消不落库', (tester) async {
    await seedProject('已有');
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey<String>('proj-new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-form')), findsOneWidget);

    // 名还空着，确定是禁用的，点了也不落库。
    await tester.tap(find.byKey(const ValueKey<String>('proj-form-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-form')), findsOneWidget);
    expect(find.text('1 个项目'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('proj-form-name')), '已有');
    await tester.pumpAndSettle();
    expect(find.text('已有同名项目'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('proj-form-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-form')), findsNothing);
    expect(find.text('1 个项目'), findsOneWidget);
  });

  testWidgets('建成后新项目在最上面，并直接进它的空详情', (tester) async {
    await seedProject('旧的');
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey<String>('proj-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('proj-form-name')), '新写的');
    await tester.enterText(find.byKey(const ValueKey<String>('proj-form-desc')), '一句说明');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('proj-form-ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('proj-form')), findsNothing);
    final title = tester.widget<Text>(find.byKey(const ValueKey<String>('proj-title')));
    expect(title.data, '新写的');
    expect(find.text('一句说明'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('proj-sub')), findsOneWidget);
  });

  testWidgets('卡片：百分比、4 像素进度条、下一步与最近推进', (tester) async {
    final id = await seedProject('写论文');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写正文', '修订', '定稿']);
    await markStepsDone(id, 2);
    await container
        .read(taskRepositoryProvider)
        .createForProject(projectId: id, name: '补第三章', nowMs: nowMs);
    await pumpPage(tester);

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('最近推进：今天'), findsOneWidget);
    expect(find.textContaining('下一步'), findsOneWidget);
    expect(find.textContaining('补第三章'), findsOneWidget);

    final card = tester.getSize(find.byKey(ValueKey<String>('proj-card-$id')));
    final bar = tester.getSize(find.byKey(ValueKey<String>('proj-bar-$id')));
    expect(bar.height, 4);
    // 卡内宽要扣两侧内边距 18 与一像素边框。
    expect(bar.width, closeTo((card.width - 38) * 0.5, 3));
  });

  testWidgets('点卡片进详情，返回键回列表', (tester) async {
    final id = await seedProject('甲');
    await pumpPage(tester);

    await tester.tap(find.byKey(ValueKey<String>('proj-card-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-title')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('proj-card-$id')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('proj-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-title')), findsNothing);
    expect(find.byKey(ValueKey<String>('proj-card-$id')), findsOneWidget);
  });

  testWidgets('详情头部：标题 20、说明与截止、进度行、两枚 32 高按钮', (tester) async {
    final id = await seedProject(
      '写论文',
      description: '三个月内交',
      dueAt: DateTime(2026, 10, 30).millisecondsSinceEpoch,
    );
    await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写正文', '修订']);
    await markStepsDone(id, 1);
    await pumpPage(tester, projectId: id);

    final title = tester.widget<Text>(find.byKey(const ValueKey<String>('proj-title')));
    expect(title.style?.fontSize, 20);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(find.text('三个月内交'), findsOneWidget);
    expect(find.text('截止 10 月 30 日'), findsOneWidget);

    final sub = tester.widget<Text>(find.byKey(const ValueKey<String>('proj-sub')));
    expect(sub.data, '33% · 已完成 1/3 步 · 最近推进 今天');

    expect(tester.getSize(find.byKey(const ValueKey<String>('proj-back'))).height, 32);
    expect(tester.getSize(find.byKey(const ValueKey<String>('proj-del'))).height, 32);
  });

  testWidgets('删除弹窗：文案带项目名，取消后仍停在详情', (tester) async {
    final id = await seedProject('要删的');
    await pumpPage(tester, projectId: id);

    await tester.tap(find.byKey(const ValueKey<String>('proj-del')));
    await tester.pumpAndSettle();

    expect(find.text('删除「要删的」？'), findsOneWidget);
    expect(find.text('项目所有数据将被一并删除。'), findsOneWidget);
    final box = tester.getSize(find.byKey(const ValueKey<String>('proj-confirm')));
    expect(box.width, 360);
    expect(tester.getSize(find.byKey(const ValueKey<String>('proj-cancel-delete'))).height, 34);
    expect(tester.getSize(find.byKey(const ValueKey<String>('proj-ok-delete'))).height, 34);

    await tester.tap(find.byKey(const ValueKey<String>('proj-cancel-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-confirm')), findsNothing);
    expect(find.byKey(const ValueKey<String>('proj-title')), findsOneWidget);
  });

  testWidgets('确认删除后回到列表，项目也没了', (tester) async {
    final id = await seedProject('要删的');
    await pumpPage(tester, projectId: id);

    await tester.tap(find.byKey(const ValueKey<String>('proj-del')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('proj-ok-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey<String>('proj-card-$id')), findsNothing);
    expect(find.byKey(const ValueKey<String>('proj-empty')), findsOneWidget);
    expect(find.text('0 个项目'), findsOneWidget);
  });

  testWidgets('地址带 id 直接展开那个项目', (tester) async {
    final id = await seedProject('甲的');
    await pumpPage(tester, projectId: id);

    expect(find.byKey(const ValueKey<String>('proj-title')), findsOneWidget);
  });

  testWidgets('地址里的 id 失效就停在列表，一个字都不提示', (tester) async {
    final id = await seedProject('甲的');
    await pumpPage(tester, projectId: 'p_missing');

    expect(find.byKey(const ValueKey<String>('proj-title')), findsNothing);
    expect(find.byKey(ValueKey<String>('proj-card-$id')), findsOneWidget);
    // 使用者 2026-10-26：这句提示从项目页彻底删掉。
    expect(find.text('这个项目已经删掉了'), findsNothing);
  });

  testWidgets('整壳里从面板路由带 id 进来也直接展开', (tester) async {
    final id = await seedProject('甲的');
    await pumpApp(tester);
    await openProjectsTab(tester);

    final router = GoRouter.of(tester.element(find.byType(MainShell)));
    router.go('/main/projects?id=$id');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('proj-title')), findsOneWidget);
  });

  testWidgets('Esc 先关删除弹窗，再退列表，最后收壳', (tester) async {
    final id = await seedProject('甲的');
    await pumpApp(tester);
    await openProjectsTab(tester);

    await tester.tap(find.byKey(ValueKey<String>('proj-card-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('proj-del')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-confirm')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-confirm')), findsNothing);
    expect(find.byKey(const ValueKey<String>('proj-title')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-title')), findsNothing);
    expect(find.byKey(ValueKey<String>('proj-card-$id')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('main-shell')), findsNothing);
  });

  testWidgets('流程条：段数等于步数、5 高、圆角 3、未完成灰底、已完成主色', (tester) async {
    final id = await seedProject('写论文');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写正文', '修订']);
    await markStepsDone(id, 1);
    await pumpPage(tester, projectId: id);

    expect(find.byKey(const ValueKey<String>('flow-seg-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('flow-seg-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('flow-seg-3')), findsNothing);

    final first = find.byKey(const ValueKey<String>('flow-seg-0'));
    final firstFill = find.descendant(of: first, matching: find.byType(AnimatedContainer));
    expect(tester.getSize(firstFill).height, 5);
    final firstDeco = tester.widget<AnimatedContainer>(firstFill).decoration! as BoxDecoration;
    expect(firstDeco.color, AppTheme.primary);
    expect(firstDeco.borderRadius, BorderRadius.circular(3));

    final second = find.byKey(const ValueKey<String>('flow-seg-1'));
    final secondDeco =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(of: second, matching: find.byType(AnimatedContainer)),
                )
                .decoration!
            as BoxDecoration;
    expect(secondDeco.color, AppTheme.track);

    // 分段条按步骤等分，段间留 5。
    expect(tester.getRect(first).width, closeTo(tester.getRect(second).width, 0.5));
    expect(tester.getRect(first).right + 5, closeTo(tester.getRect(second).left, 0.5));

    // 进详情默认筛第 1 步：那一段套 2 像素主色描边。
    final outline = tester
        .widgetList<DecoratedBox>(find.descendant(of: first, matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((deco) => deco.border != null);
    expect((outline.border! as Border).top.width, 2);
    expect((outline.border! as Border).top.color, AppTheme.primary);

    // 「编辑流程」26 高、12 号主色。
    expect(tester.getSize(find.byKey(const ValueKey<String>('flow-edit'))).height, 26);
    final editText = tester.widget<Text>(find.text('编辑流程'));
    expect(editText.style?.fontSize, 12);
    expect(editText.style?.color, AppTheme.primary);
  });

  testWidgets('点一段出筛选提示行，再点同段或点 × 清掉', (tester) async {
    final id = await seedProject('写论文');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写正文', '修订']);
    await pumpPage(tester, projectId: id);

    // 进详情默认筛第 1 步。
    expect(find.text('第 1 步 · 选题'), findsOneWidget);
    final tip = tester.widget<Container>(find.byKey(const ValueKey<String>('flow-tip')));
    final deco = tip.decoration! as BoxDecoration;
    expect(deco.color, AppTheme.accentSoft);
    expect(deco.borderRadius, BorderRadius.circular(8));
    expect((deco.border! as Border).top.color, const Color(0xFFCFDCFB));
    expect(tip.padding, const EdgeInsets.symmetric(horizontal: 10, vertical: 5));

    final label = tester.widget<Text>(find.text('第 1 步 · 选题'));
    expect(label.style?.fontSize, 12);
    expect(label.style?.color, AppTheme.primary);
    expect(tester.widget<Text>(find.text('×')).style?.fontSize, 13);

    await tester.tap(find.byKey(const ValueKey<String>('flow-seg-1')));
    await tester.pumpAndSettle();
    expect(find.text('第 2 步 · 写正文'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('flow-seg-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-tip')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('flow-seg-2')));
    await tester.pumpAndSettle();
    expect(find.text('第 3 步 · 修订'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('flow-tip-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-tip')), findsNothing);
  });

  testWidgets('编辑流程：文案切换与编辑器数值（序号 22、输入 32、小键 28、底键 30）', (tester) async {
    final id = await seedProject('写论文');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写正文']);
    await pumpPage(tester, projectId: id);

    await tester.tap(find.byKey(const ValueKey<String>('flow-edit')));
    await tester.pumpAndSettle();

    expect(find.text('收起编辑'), findsOneWidget);
    final editor = tester.widget<Container>(find.byKey(const ValueKey<String>('flow-editor')));
    expect(editor.padding, const EdgeInsets.symmetric(horizontal: 14, vertical: 12));
    final editorDeco = editor.decoration! as BoxDecoration;
    expect(editorDeco.color, const Color(0xFFF7F9FD));
    expect(editorDeco.borderRadius, BorderRadius.circular(12));

    final steps = (await container.read(projectRepositoryProvider).load(id)).steps;
    final first = steps.firstWhere((step) => step.index == 0);

    final no = find.byKey(ValueKey<String>('flow-no-${first.id}'));
    expect(tester.getSize(no).width, 22);
    expect(tester.widget<Text>(no).data, '1');
    expect(tester.widget<Text>(no).style?.fontSize, 12);

    final name = find.byKey(ValueKey<String>('flow-name-${first.id}'));
    expect(tester.getSize(name).height, 32);
    expect(tester.widget<TextField>(name).maxLength, 12);

    for (final kind in ['up', 'down', 'del']) {
      final key = ValueKey<String>('flow-$kind-${first.id}');
      expect(tester.getSize(find.byKey(key)).height, 28);
      expect(find.byKey(key), findsOneWidget);
    }

    expect(tester.getSize(find.byKey(const ValueKey<String>('flow-add'))).height, 30);
    expect(tester.getSize(find.byKey(const ValueKey<String>('flow-done'))).height, 30);

    await tester.tap(find.byKey(const ValueKey<String>('flow-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-editor')), findsNothing);
    expect(find.text('编辑流程'), findsOneWidget);
  });

  testWidgets('改名同步到提示行；加一步与删一步改变段数', (tester) async {
    final id = await seedProject('写论文');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写正文', '修订']);
    await pumpPage(tester, projectId: id);
    await tester.tap(find.byKey(const ValueKey<String>('flow-edit')));
    await tester.pumpAndSettle();

    final steps = (await container.read(projectRepositoryProvider).load(id)).steps;
    final first = steps.firstWhere((step) => step.index == 0);

    await tester.enterText(find.byKey(ValueKey<String>('flow-name-${first.id}')), '开题');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('第 1 步 · 开题'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('flow-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-seg-3')), findsOneWidget);
    expect(find.text('新步骤 4'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey<String>('flow-del-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-seg-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('flow-seg-3')), findsNothing);
    // 删掉第 1 步后默认筛选落回新的第 1 步。
    expect(find.text('第 1 步 · 写正文'), findsOneWidget);
  });

  testWidgets('Esc 先收流程编辑器，再退列表', (tester) async {
    final id = await seedProject('甲的');
    await container.read(projectRepositoryProvider).replaceSteps(id, ['一']);
    await pumpApp(tester);
    await openProjectsTab(tester);

    await tester.tap(find.byKey(ValueKey<String>('proj-card-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('flow-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-editor')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flow-editor')), findsNothing);
    expect(find.byKey(const ValueKey<String>('proj-title')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('proj-title')), findsNothing);
    expect(find.byKey(ValueKey<String>('proj-card-$id')), findsOneWidget);
  });

  group('B15 本项目待办', () {
    /// 挂在某一步末尾新增一条；已做时长直接落库，不经计时。
    Future<String> addTodo(String projectId, String stepId, String name, {int spentSec = 0}) async {
      final id = await container
          .read(taskRepositoryProvider)
          .addToStep(projectId: projectId, stepId: stepId, name: name, nowMs: nowMs);
      if (spentSec > 0) {
        await (db.update(db.taskItems)..where((row) => row.id.equals(id))).write(
          TaskItemsCompanion(spentSec: Value<int>(spentSec)),
        );
      }
      return id;
    }

    testWidgets('卡片按原型量：72 高、勾选框 18、名称 15/600；随手记收进编辑页', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题', '写正文']);
      final step = (await repo.load(id)).steps.firstWhere((s) => s.index == 0);
      final taskId = await addTodo(id, step.id, '查三篇综述');
      await pumpPage(tester, projectId: id);

      final card = tester.widget<Container>(find.byKey(ValueKey<String>('todo-$taskId')));
      expect(card.constraints!.minHeight, 72);
      expect((card.decoration as BoxDecoration).borderRadius, BorderRadius.circular(12));
      expect(
        tester.getSize(find.byKey(ValueKey<String>('todo-check-$taskId'))),
        const Size(18, 18),
      );
      expect(
        tester.getSize(find.byKey(ValueKey<String>('todo-start-$taskId'))),
        const Size(88, 32),
      );
      expect(tester.getSize(find.byKey(ValueKey<String>('todo-up-$taskId'))), const Size(24, 24));
      expect(tester.getSize(find.byKey(ValueKey<String>('todo-down-$taskId'))), const Size(24, 24));

      final name = tester.widget<Text>(find.byKey(ValueKey<String>('todo-name-$taskId')));
      expect(name.style!.fontSize, 15);
      expect(name.style!.fontWeight, FontWeight.w600);

      final meta = tester.widget<Text>(find.byKey(ValueKey<String>('todo-meta-$taskId')));
      expect(meta.data, '第 1 步 · 选题');
      expect(meta.style!.fontSize, 12);

      // 使用者 2026-10-26：项目事项不再行内记随手记，点行头展开的是同一块编辑页。
      expect(find.byKey(ValueKey<String>('todo-detail-$taskId')), findsNothing);
      await tester.tap(find.byKey(ValueKey<String>('todo-head-$taskId')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey<String>('todo-detail-$taskId')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('solo-detail-note'))).height,
        closeTo(56, 4),
      );
      expect(find.byKey(const ValueKey<String>('solo-save')), findsOneWidget);
    });

    testWidgets('元信息带已做分钟；下一步那一格的事项挂角标', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题', '写正文']);
      final steps = (await repo.load(id)).steps;
      final first = await addTodo(
        id,
        steps.firstWhere((s) => s.index == 0).id,
        '查综述',
        spentSec: 130,
      );
      final second = await addTodo(id, steps.firstWhere((s) => s.index == 1).id, '写引言');
      await repo.setCurrentStep(id, 1);
      await pumpPage(tester, projectId: id);
      // 默认筛着第 2 步，清掉筛才同时看得到两条。
      await tester.tap(find.byKey(const ValueKey<String>('flow-tip-clear')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(ValueKey<String>('todo-meta-$first'))).data,
        '第 1 步 · 选题 · 已做 3 分钟',
      );
      // 项目停在第 2 步，第 1 步那条不是「下一步」。
      expect(find.byKey(ValueKey<String>('todo-next-$first')), findsNothing);
      expect(find.byKey(ValueKey<String>('todo-next-$second')), findsOneWidget);
    });

    testWidgets('勾一下先画完成态，600 毫秒后移出列表', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题']);
      final step = (await repo.load(id)).steps.first;
      final taskId = await addTodo(id, step.id, '查三篇综述');
      await pumpPage(tester, projectId: id);

      await tester.tap(find.byKey(ValueKey<String>('todo-check-$taskId')));
      await tester.pump();

      final name = tester.widget<Text>(find.byKey(ValueKey<String>('todo-name-$taskId')));
      expect(name.style!.decoration, TextDecoration.lineThrough);
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(ValueKey<String>('todo-check-$taskId')),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration as BoxDecoration).color, AppTheme.primary);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey<String>('todo-$taskId')), findsNothing);
      expect(find.byType(ProjectTodoRow), findsNothing);
    });

    testWidgets('未分配事项列在移入块，选步骤后进待办', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题']);
      final moved = await container
          .read(taskRepositoryProvider)
          .createForProject(
            projectId: id,
            name: '从独立事项移入的',
            nowMs: nowMs,
            source: TaskSource.moved,
          );
      await pumpPage(tester, projectId: id);

      expect(find.byKey(const ValueKey<String>('moved-head')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('moved-count'))).data, '1 件');
      expect(find.byKey(ValueKey<String>('moved-src-$moved')), findsOneWidget);
      expect(find.text('从独立事项移入 · 10/24'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(ValueKey<String>('moved-assign-$moved'))),
        const Size(88, 32),
      );

      await tester.tap(find.byKey(ValueKey<String>('moved-assign-$moved')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(ValueKey<String>('moved-select-$moved'))).height, 30);
      expect(tester.getSize(find.byKey(ValueKey<String>('moved-cancel-$moved'))).height, 28);

      await tester.tap(find.byKey(ValueKey<String>('moved-select-$moved')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 · 选题').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('moved-head')), findsNothing);
      expect(find.byKey(ValueKey<String>('todo-$moved')), findsOneWidget);
      final task = await container.read(taskRepositoryProvider).byId(moved);
      expect(task!.stepId, isNotNull);

      // 把新增后的 1.2 秒闪烁走完，免得测试收尾时还挂着定时器。
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });

    testWidgets('编辑器行尾的加号就地新增，提交后落进待办', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题', '写正文']);
      final step = (await repo.load(id)).steps.firstWhere((s) => s.index == 0);
      await pumpPage(tester, projectId: id);
      await tester.tap(find.byKey(const ValueKey<String>('flow-edit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey<String>('flow-todo-${step.id}')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(ValueKey<String>('flow-todo-name-${step.id}'))).height, 30);
      expect(tester.getSize(find.byKey(ValueKey<String>('flow-todo-ok-${step.id}'))).height, 28);
      expect(
        tester.getSize(find.byKey(ValueKey<String>('flow-todo-cancel-${step.id}'))).height,
        28,
      );

      await tester.enterText(find.byKey(ValueKey<String>('flow-todo-name-${step.id}')), '补第三章');
      await tester.pump();
      await tester.tap(find.byKey(ValueKey<String>('flow-todo-ok-${step.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('flow-addrow-${step.id}')), findsNothing);
      final tasks = await container.read(taskRepositoryProvider).byProject(id);
      expect(tasks.map((task) => task.name), ['补第三章']);
      expect(find.byKey(ValueKey<String>('todo-${tasks.single.id}')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey<String>('todo-meta-${tasks.single.id}'))).data,
        '第 1 步 · 选题',
      );

      // 把新增后的 1.2 秒闪烁走完，免得测试收尾时还挂着定时器。
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });

    testWidgets('空白提交不新增，输入行还留着', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题']);
      final step = (await repo.load(id)).steps.first;
      await pumpPage(tester, projectId: id);
      await tester.tap(find.byKey(const ValueKey<String>('flow-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey<String>('flow-todo-${step.id}')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(ValueKey<String>('flow-todo-name-${step.id}')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(ValueKey<String>('flow-todo-ok-${step.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('flow-addrow-${step.id}')), findsOneWidget);
      expect(await container.read(taskRepositoryProvider).byProject(id), isEmpty);
    });

    testWidgets('没有待办也没有移入时不画这两块', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      await pumpPage(tester, projectId: id);

      expect(find.byType(ProjectTodoRow), findsNothing);
      expect(find.byKey(const ValueKey<String>('moved-head')), findsNothing);
    });
  });

  group('进度史与时间轴', () {
    /// 直接落一条进度史，`at` 决定它落进哪一档文案。
    Future<String> seedEntry(String projectId, int stepIndex, String content, DateTime at) =>
        container
            .read(projectRepositoryProvider)
            .addProgress(
              projectId: projectId,
              stepIndex: stepIndex,
              content: content,
              nowMs: at.millisecondsSinceEpoch,
            );

    /// 滚到进度史那一块再点，详情是单列滚动的，最下面一屏默认看不见。
    Future<void> reach(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('一条进展都没有时，标题与切换键照样在', (tester) async {
      // 《页面操作流程》第 6 节：标题与切换按钮一直存在，即使下方没有内容。
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      await pumpPage(tester, projectId: id);
      await reach(tester, find.byKey(const ValueKey<String>('hist-title')));

      expect(find.byKey(const ValueKey<String>('hist-title')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('hist-axis')), findsOneWidget);
      expect(find.text('进度史'), findsOneWidget);
      // 底下没有内容，也就没有一条记录可点。
      expect(find.byKey(const ValueKey<String>('hist-row-0')), findsNothing);
    });

    testWidgets('勾完一件待办，进度史当场冒出一条，不用退出重进', (tester) async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题']);
      final step = (await repo.load(id)).steps.first;
      final taskId = await container.read(taskRepositoryProvider).createForProject(
        projectId: id,
        name: '查综述',
        stepId: step.id,
        nowMs: base.millisecondsSinceEpoch,
      );
      await pumpPage(tester, projectId: id);
      // 标题常驻，但没有内容时下面一条记录都没有。
      expect(find.byKey(const ValueKey<String>('hist-title')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey<String>('todo-check-$taskId')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // 使用者 2026-10-26：以前这一块得退出重进才看得见，等于「无法触发」。
      await reach(tester, find.byKey(const ValueKey<String>('hist-title')));
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('hist-title'))).data, '进度史');
      expect(container.read(projectListProvider).detailProgress, hasLength(1));

      await tester.tap(find.byKey(const ValueKey<String>('hist-axis')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('hist-title'))).data, '时间轴');
      expect(find.byKey(const ValueKey<String>('hist-axis-list')), findsOneWidget);
    });

    testWidgets('时刻列 88 宽、正文 14 号行高 1.6、步骤标签 11 号内边距 1/7', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      final entry = await seedEntry(id, 0, '选题定了', base.subtract(const Duration(hours: 1)));
      await pumpPage(tester, projectId: id);
      await reach(tester, find.byKey(ValueKey<String>('hist-when-$entry')));

      final whenBox = tester.getSize(
        find
            .ancestor(
              of: find.byKey(ValueKey<String>('hist-when-$entry')),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(whenBox.width, 88);

      final text = tester.widget<Text>(find.byKey(ValueKey<String>('hist-text-$entry')));
      expect(text.style?.fontSize, 14);
      expect(text.style?.height, 1.6);

      final tag = tester.widget<Text>(find.text('第 1 步'));
      expect(tag.style?.fontSize, 11);
      final tagBox = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey<String>('hist-step-$entry')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(tagBox.padding, const EdgeInsets.symmetric(horizontal: 7, vertical: 1));

      // 时刻文案按时钟落成「今天 08:00」，不是原始毫秒。
      expect(
        tester.widget<Text>(find.byKey(ValueKey<String>('hist-when-$entry'))).data,
        '今天 08:00',
      );
    });

    testWidgets('切到时间轴：标题与键互换，按天分组，正文 13 号', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题', '写稿']);
      final old = await seedEntry(id, 0, '选题定了', DateTime(2026, 10, 23, 21, 40));
      final fresh = await seedEntry(id, 1, '正文写了三节', base.subtract(const Duration(minutes: 5)));
      await pumpPage(tester, projectId: id);

      await reach(tester, find.byKey(const ValueKey<String>('hist-axis')));
      await tester.tap(find.byKey(const ValueKey<String>('hist-axis')));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('hist-title'))).data, '时间轴');
      expect(find.text('进度史'), findsOneWidget); // 键上换成回列表那一侧
      expect(find.byKey(const ValueKey<String>('hist-axis-list')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('hist-day-昨天')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('hist-day-今天')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('hist-tl-$old')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('hist-tl-$fresh')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey<String>('hist-text-$old'))).style?.fontSize,
        13,
      );
    });

    testWidgets('点「编辑」改正文，保存后上屏并出现「改过 1 次」', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      final entry = await seedEntry(id, 0, '选题定了', base.subtract(const Duration(minutes: 1)));
      await pumpPage(tester, projectId: id);

      await reach(tester, find.byKey(ValueKey<String>('hist-edit-$entry')));
      await tester.tap(find.byKey(ValueKey<String>('hist-edit-$entry')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('hist-editin-$entry')), findsOneWidget);
      expect(tester.getSize(find.byKey(ValueKey<String>('hist-save-$entry'))).height, 28);
      expect(tester.getSize(find.byKey(ValueKey<String>('hist-cancel-$entry'))).height, 28);

      await tester.enterText(find.byKey(ValueKey<String>('hist-editin-$entry')), '选题定了，收窄到第三章');
      await tester.pump();
      await tester.tap(find.byKey(ValueKey<String>('hist-save-$entry')));
      await tester.pumpAndSettle();

      expect(find.text('选题定了，收窄到第三章'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('hist-revs-$entry')),
          matching: find.text('改过 1 次'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('时间轴里改完正文，还停在时间轴', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      final entry = await seedEntry(id, 0, '选题定了', base.subtract(const Duration(minutes: 1)));
      await pumpPage(tester, projectId: id);

      await reach(tester, find.byKey(const ValueKey<String>('hist-axis')));
      await tester.tap(find.byKey(const ValueKey<String>('hist-axis')));
      await tester.pumpAndSettle();

      await reach(tester, find.byKey(ValueKey<String>('hist-edit-$entry')));
      await tester.tap(find.byKey(ValueKey<String>('hist-edit-$entry')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ValueKey<String>('hist-editin-$entry')), '选题收窄了');
      await tester.pump();
      await tester.tap(find.byKey(ValueKey<String>('hist-save-$entry')));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('hist-title'))).data, '时间轴');
      expect(find.byKey(const ValueKey<String>('hist-axis-list')), findsOneWidget);
      expect(find.text('选题收窄了'), findsOneWidget);
    });

    testWidgets('「改过 N 次」展开修订链，再点收起', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      final entry = await seedEntry(id, 0, '选题定了', base.subtract(const Duration(minutes: 30)));
      await container
          .read(projectRepositoryProvider)
          .reviseProgress(entry, '选题定了', '选题定了·改', base.millisecondsSinceEpoch);
      await pumpPage(tester, projectId: id);

      await reach(tester, find.byKey(ValueKey<String>('hist-revs-$entry')));
      await tester.tap(find.byKey(ValueKey<String>('hist-revs-$entry')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('hist-revbox-$entry')), findsOneWidget);
      expect(find.textContaining('选题定了 → 选题定了·改'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey<String>('hist-revs-$entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey<String>('hist-revbox-$entry')), findsNothing);
    });

    testWidgets('随手记：没记时提示「还没记」，写完后上屏并可再改', (tester) async {
      final id = await seedProject('写论文');
      await container.read(projectRepositoryProvider).replaceSteps(id, ['选题']);
      final entry = await seedEntry(id, 0, '选题定了', base.subtract(const Duration(minutes: 30)));
      await pumpPage(tester, projectId: id);

      await reach(tester, find.byKey(ValueKey<String>('hist-notebtn-$entry')));
      expect(find.text('还没记'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey<String>('hist-notebtn-$entry')));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(ValueKey<String>('hist-notesave-$entry'))).height, 26);
      await tester.enterText(find.byKey(ValueKey<String>('hist-notein-$entry')), '导师说要收窄');
      await tester.pump();
      await tester.tap(find.byKey(ValueKey<String>('hist-notesave-$entry')));
      await tester.pumpAndSettle();

      expect(find.text('导师说要收窄'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('hist-notebtn-$entry')),
          matching: find.text('改随手记'),
        ),
        findsOneWidget,
      );
    });

  group('项目事项复用独立事项的编辑页', () {
    Future<(String, String)> seedTodo() async {
      final id = await seedProject('写论文');
      final repo = container.read(projectRepositoryProvider);
      await repo.replaceSteps(id, ['选题']);
      final step = (await repo.load(id)).steps.first;
      final taskId = await container.read(taskRepositoryProvider).createForProject(
        projectId: id,
        name: '查综述',
        stepId: step.id,
        nowMs: base.millisecondsSinceEpoch,
      );
      return (id, taskId);
    }

    testWidgets('点行头展开同一块编辑页：随手记与保存都走同一套', (tester) async {
      final (id, taskId) = await seedTodo();
      await pumpPage(tester, projectId: id);

      await tester.tap(find.byKey(ValueKey<String>('todo-head-$taskId')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('todo-detail-$taskId')), findsOneWidget);
      // 项目事项不做「明天自动移出」，那句完成提示不画。
      expect(find.textContaining('明天自动从列表移出'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey<String>('solo-detail-note')), '收了 12 篇');
      // 详情页多了 AI 帮助块之后，编辑页的保存键掉到视口下沿以外，先滚过去。
      await tester.ensureVisible(find.byKey(const ValueKey<String>('solo-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('solo-save')));
      await tester.pumpAndSettle();

      expect(container.read(projectListProvider).notes[taskId], '收了 12 篇');
      expect(find.byKey(ValueKey<String>('todo-detail-$taskId')), findsOneWidget);
    });

    testWidgets('编辑页删除要过二次确认，确认后这条待办消失', (tester) async {
      final (id, taskId) = await seedTodo();
      await pumpPage(tester, projectId: id);
      await tester.tap(find.byKey(ValueKey<String>('todo-head-$taskId')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey<String>('solo-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('solo-delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('confirm-overlay')), findsOneWidget);
      expect(find.text('相关数据将不会被保留'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('confirm-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey<String>('todo-row-$taskId')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey<String>('solo-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('solo-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('confirm-ok')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('todo-row-$taskId')), findsNothing);
      expect(find.byKey(ValueKey<String>('todo-detail-$taskId')), findsNothing);
    });
  });
  });
}
