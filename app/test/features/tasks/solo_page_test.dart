import 'package:ai_pet_assistant/app/app.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/app/theme.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Note, TaskItem;
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/features/panel/panel_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_frame.dart';
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:ai_pet_assistant/features/tasks/solo_notifier.dart';
import 'package:ai_pet_assistant/features/tasks/solo_page.dart';
import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_pet_stage_port.dart';

/// 独立事项页的界面行为。
///
/// 断言只写原型上看得见的东西：谁在前、按钮长什么样、点一下之后落在哪。
/// 日期文案与排序规则在 `solo_notifier_test.dart` 里覆盖，这里不重复。
void main() {
  late AppDb db;
  late ProviderContainer container;
  late TimerService timer;
  late FakePetStagePort port;
  late int nowMs;

  /// 固定「现在」，创建时间与相对日期才有确定答案。
  final base = DateTime(2026, 10, 24, 9);

  /// 面板档的窗口：宠物在右下，左上留一块给悬停面板。
  /// 真窗口由窗口层算，这里给一个固定值，好让面板有地方落。
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
        // 轮询与播报留守都靠定时器，界面测试不留悬挂任务。
        petPollIntervalProvider.overrideWithValue(null),
        petReportLingerProvider.overrideWithValue(null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    port.dispose();
    timer.dispose();
    await db.close();
  });

  Future<String> seed(String name, {String description = ''}) => container
      .read(taskRepositoryProvider)
      .createSolo(name: name, description: description, nowMs: nowMs);

  /// 只装这一页，不带路由与窗口：界面本身不依赖 go_router。
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: 704, height: 560, child: SoloPage())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 计时起来之后不能用 `pumpAndSettle`：走秒每秒一帧，永远等不到静止。
  Future<void> settle(WidgetTester tester, {int steps = 15}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// 整壳一起装：点「开始」之后要落到桌宠页，得真有路由与窗口框。
  Future<void> pumpApp(WidgetTester tester) async {
    container.read(petFrameProvider.notifier).apply(appFrame);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AiPetApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('页头写着「独立事项」，空态只说一句话', (tester) async {
    await pumpPage(tester);

    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('solo-title'))).data, '独立事项');
    // 新建入口只留页头右上角那一个，空态不再重复放蓝色按钮。
    expect(find.byKey(const ValueKey<String>('solo-new')), findsOneWidget);
    expect(find.text('还没有独立事项'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('solo-empty-new')), findsNothing);
    expect(find.byKey(const ValueKey<String>('solo-list')), findsNothing);
  });

  testWidgets('新建只问名称与说明，名称空着不让确定', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey<String>('solo-new')));
    await tester.pumpAndSettle();

    final form = find.byKey(const ValueKey<String>('solo-form'));
    expect(find.descendant(of: form, matching: find.byType(TextField)), findsNWidgets(2));
    expect(find.text('事项名称'), findsOneWidget);
    expect(find.text('事项说明'), findsOneWidget);

    GestureDetector okButton() => tester.widget<GestureDetector>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('solo-form-ok')),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(okButton().onTap, isNull);

    await tester.enterText(find.byKey(const ValueKey<String>('solo-form-name')), '买菜');
    await tester.pump();
    expect(okButton().onTap, isNotNull);

    await tester.enterText(find.byKey(const ValueKey<String>('solo-form-desc')), '顺路带牛奶');
    await tester.tap(find.byKey(const ValueKey<String>('solo-form-ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('solo-form')), findsNothing);
    expect(find.text('买菜'), findsOneWidget);
    expect(find.text('顺路带牛奶'), findsOneWidget);
  });

  testWidgets('名称列占四成二，说明再长也不把行撑高', (tester) async {
    final long = await seed('长说明', description: '说明' * 80);
    final short = await seed('短说明', description: '短');
    await pumpPage(tester);
    // 面板会自己挑一条当当前事务；当前行左边多一条竖条、内边距也窄 3 像素，
    // 把它固定在「短说明」上，量「长说明」那一行的名称列才不会两头算。
    await container.read(panelNotifierProvider.notifier).setCurrentTask(short);
    await tester.pumpAndSettle();

    final longSize = tester.getSize(find.byKey(ValueKey<String>('solo-row-$long')));
    final shortSize = tester.getSize(find.byKey(ValueKey<String>('solo-row-$short')));
    expect(longSize.height, shortSize.height);

    final nameBox = tester.widget<SizedBox>(
      find.ancestor(of: find.text('长说明'), matching: find.byType(SizedBox)).first,
    );
    // 卡片的 1 像素边框不算进内容宽，名称列拿的是「卡片内宽」的四成二。
    expect(nameBox.width, closeTo((longSize.width - 2) * 0.42, 0.01));
    // 说明列垂直居中对齐，不随名称那两行的位置往下掉。
    expect(
      tester
          .widget<Align>(
            find.ancestor(of: find.text('说明' * 80), matching: find.byType(Align)).first,
          )
          .alignment,
      Alignment.centerLeft,
    );
  });

  testWidgets('多选框三态：空心、泛黄、实底白勾', (tester) async {
    final id = await seed('写周报');
    await pumpPage(tester);

    final check = find.byKey(ValueKey<String>('solo-check-$id'));
    Container boxOf() =>
        tester.widget<Container>(find.descendant(of: check, matching: find.byType(Container)));

    final idle = boxOf();
    expect(idle.decoration, isA<BoxDecoration>());
    final idleDeco = idle.decoration! as BoxDecoration;
    expect(idleDeco.color, Colors.white);
    expect((idleDeco.border! as Border).top.color, const Color(0xFFCBD5E1));
    expect((idleDeco.border! as Border).top.width, 2);
    expect(idleDeco.borderRadius, BorderRadius.circular(6));
    expect(
      tester.getSize(find.descendant(of: check, matching: find.byType(Container))),
      const Size(18, 18),
    );

    await container.read(soloListProvider.notifier).start(id);
    await settle(tester);
    final running = boxOf().decoration! as BoxDecoration;
    expect(running.color, const Color(0xFFFEF3C7));
    expect((running.border! as Border).top.color, const Color(0xFFF0B429));

    await container.read(soloListProvider.notifier).toggleDone(id);
    await settle(tester);
    final done = boxOf().decoration! as BoxDecoration;
    expect(done.color, AppTheme.primary);
    expect(find.descendant(of: check, matching: find.byIcon(Icons.check)), findsOneWidget);

    timer.dispose();
    await tester.pump();
  });

  testWidgets('点行头展开详情，同时只留一条', (tester) async {
    final first = await seed('甲');
    final second = await seed('乙');
    await pumpPage(tester);

    await tester.tap(find.text('甲'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('solo-detail-$first')), findsOneWidget);
    // 累计精确到秒：一秒都没计过就是 0 秒。
    expect(find.text('累计 0 秒'), findsOneWidget);
    // 两个输入框的提示词按 2026-10-25 的口径换了。
    expect(find.text('事项说明'), findsWidgets);
    expect(find.text('随手记'), findsOneWidget);
    expect(find.text('在此处记录你的成果'), findsOneWidget);

    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('solo-detail-$first')), findsNothing);
    expect(find.byKey(ValueKey<String>('solo-detail-$second')), findsOneWidget);
  });

  testWidgets('输入停下自动存，点保存收起详情并留一句提示', (tester) async {
    final id = await seed('原名');
    await pumpPage(tester);
    await tester.tap(find.text('原名'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('solo-detail-name')), '新名');
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    expect((await container.read(taskRepositoryProvider).byId(id))!.name, '新名');
    // 自动存既不收起，也不弹提示。
    expect(find.byKey(ValueKey<String>('solo-detail-$id')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('solo-flash')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('solo-save')));
    await settle(tester);
    expect(find.byKey(ValueKey<String>('solo-detail-$id')), findsNothing);
    expect(find.text('已保存 · 新名'), findsOneWidget);

    // 提示一两秒后自己消失，不需要谁去关。
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey<String>('solo-flash')), findsNothing);
  });

  testWidgets('删除要过二次确认；取消不动，确认才删且退回空态', (tester) async {
    final id = await seed('要删的');
    await pumpPage(tester);
    await tester.tap(find.text('要删的'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('solo-delete')));
    await tester.pumpAndSettle();

    // 使用者 2026-10-26：删之前先问一句，提示「相关数据将不会被保留」。
    expect(find.byKey(const ValueKey<String>('confirm-overlay')), findsOneWidget);
    expect(find.text('相关数据将不会被保留'), findsOneWidget);
    expect(find.byKey(ValueKey<String>('solo-row-$id')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('confirm-overlay')), findsNothing);
    expect(find.byKey(ValueKey<String>('solo-row-$id')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('solo-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirm-ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey<String>('solo-row-$id')), findsNothing);
    expect(find.byKey(const ValueKey<String>('solo-empty')), findsOneWidget);
  });

  testWidgets('编辑页随手记不自动存，点保存才落库', (tester) async {
    final id = await seed('随手记的那件');
    await pumpPage(tester);
    await tester.tap(find.text('随手记的那件'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('solo-detail-note')),
      '今天推进到第三章',
    );
    // 等到自动保存那个 600 毫秒的点过去，库里仍然没有这句话。
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(
      await container.read(noteRepositoryProvider).textOf(NoteOwner.task, id),
      isEmpty,
    );

    await tester.tap(find.byKey(const ValueKey<String>('solo-save')));
    await settle(tester);

    expect(
      await container.read(noteRepositoryProvider).textOf(NoteOwner.task, id),
      '今天推进到第三章',
    );

    // 让「已保存」那句提示自己消失，别留一个待办的定时器给下一用例。
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('计时中行内走秒，点暂停转成泛黄的待继续态', (tester) async {
    final id = await seed('计时中的事');
    await pumpPage(tester);
    await container.read(soloListProvider.notifier).start(id);
    await settle(tester);

    final clock = find.byKey(ValueKey<String>('solo-clock-$id'));
    expect(clock, findsOneWidget);
    // 计时一律按 00:00:00 的格式走，《页面操作流程》第 4 节。
    expect(find.descendant(of: clock, matching: find.text('00:00:00')), findsOneWidget);

    nowMs += 65000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.descendant(of: clock, matching: find.text('00:01:05')), findsOneWidget);

    // 使用者 2026-10-26：暂停只是停表等继续，这一行不打勾、秒数也不结算。
    await container.read(panelNotifierProvider.notifier).pause();
    await settle(tester);

    final task = await container.read(taskRepositoryProvider).byId(id);
    expect(task!.done, isFalse);
    expect(task.spentSec, 0);
    // 时钟位换成泛黄的暂停态按钮，这一行仍在原位。
    expect(find.byKey(ValueKey<String>('solo-clock-$id')), findsOneWidget);
    final paused = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey<String>('solo-clock-$id')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((paused.decoration! as BoxDecoration).color, AppTheme.warmSoft);

    timer.dispose();
    await tester.pump();
  });

  testWidgets('页头小字报件数：一件没有写 0 个，建一条变 1 个', (tester) async {
    await pumpPage(tester);
    // 《页面操作流程》第 6 节：标题下还有一行小字报当前事项数，示例「0个项目」。
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('solo-count'))).data, '0个项目');

    await tester.tap(find.byKey(const ValueKey<String>('solo-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('solo-form-name')), '写周报');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('solo-form-ok')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('solo-count'))).data, '1个项目');
  });

  testWidgets('行尾标记键：把这一件摆进面板但表不走，已完成的行没有这个键', (tester) async {
    final id = await seed('被标记的事');
    final doneId = await seed('已经做完的');
    await container.read(soloListProvider.notifier).toggleDone(doneId);
    await pumpApp(tester);

    // 《页面操作流程》第 6 节：已完成的事项不再属于「要做的事」，不给标记键。
    expect(find.byKey(ValueKey<String>('solo-mark-$doneId')), findsNothing);

    await tester.tap(find.byKey(ValueKey<String>('solo-mark-$id')));
    await settle(tester, steps: 30);

    // 摆进小任务窗口但不开始计时：面板有这一件，时钟位还停在「开始」。
    final panel = container.read(panelNotifierProvider);
    expect(panel.taskId, id);
    expect(panel.running, isFalse);
    expect(find.byKey(const ValueKey<String>('main-shell')), findsNothing);
    expect(find.byKey(const ValueKey<String>('panel-clock')), findsNothing);
    expect(find.byKey(const ValueKey<String>('panel-start')), findsOneWidget);
  });

  testWidgets('点开始：主界面收起，面板直接进计时', (tester) async {
    final id = await seed('开始这一件');
    await pumpApp(tester);
    expect(find.byKey(const ValueKey<String>('main-shell')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey<String>('solo-start-$id')));
    await settle(tester, steps: 30);

    expect(find.byKey(const ValueKey<String>('main-shell')), findsNothing);
    expect(find.byKey(const ValueKey<String>('page-pet')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('panel-clock')), findsOneWidget);

    timer.dispose();
    await tester.pump();
  });

  testWidgets('Esc 先收详情，第二下才收壳', (tester) async {
    final id = await seed('展开的');
    await pumpApp(tester);
    await tester.tap(find.text('展开的'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('solo-detail-$id')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('main-shell')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('solo-detail-$id')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    // 桌宠页有常驻的待机动画，settle 等不到静止，这里按帧数推进。
    await settle(tester, steps: 20);
    expect(find.byKey(const ValueKey<String>('main-shell')), findsNothing);
  });
}
