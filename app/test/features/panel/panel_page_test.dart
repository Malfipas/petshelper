import 'package:ai_pet_assistant/app/key_configured.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/app/theme.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/features/panel/panel_notifier.dart';
import 'package:ai_pet_assistant/features/panel/panel_page.dart';
import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 悬停小面板画出来的东西：三种形态、流程轴段数、原型数值、以及没接模型时的禁用态。
void main() {
  late AppDb db;
  late ProviderContainer container;
  late TimerService timer;

  /// 假时钟。有的用例要推几秒出来，才能摆出「攒过时长」那一态。
  late int nowMs;

  setUp(() {
    db = AppDb.memory();
    nowMs = 500000;
    timer = TimerService(now: () => nowMs);
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        timerServiceProvider.overrideWithValue(timer),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    timer.dispose();
    await db.close();
  });

  /// 造一个 7 步的项目，走到第 3 步（索引 2），带一条未完成待办；返回待办 id。
  Future<String> seedProject() async {
    final projects = container.read(projectRepositoryProvider);
    final tasks = container.read(taskRepositoryProvider);
    final projectId = await projects.create(name: '毕业论文', nowMs: 1000);
    await projects.replaceSteps(projectId, ['选题', '开题', '写第三章', '写第四章', '定稿', '送审', '答辩']);
    await projects.setCurrentStep(projectId, 2);
    return tasks.createForProject(projectId: projectId, name: '把第三章结论写成三句话', nowMs: 1000);
  }

  /// 把面板放进一个跟真实窗口差不多宽的小格子里。
  ///
  /// [scope] 用来换成带假状态的面板（例如问答记录），默认用本文件那个容器。
  Future<void> pumpPanel(
    WidgetTester tester, {
    ProviderContainer? scope,
    Size size = const Size(280, 420),
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope ?? container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: size.width, height: size.height, child: const PanelPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Text textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey<String>(key)));

  group('三种形态', () {
    testWidgets('库里没有事项时是空态，只留一句话', (tester) async {
      await pumpPanel(tester);

      // 《页面操作流程》第 4 节：无事项状态，正中央显示「当前暂无事项」。
      expect(textOf(tester, 'panel-empty-title').data, '当前暂无事项');
      expect(find.byKey(const ValueKey<String>('panel-track')), findsNothing);
    });

    testWidgets('项目待办走形态 A：项目名、当前步、元信息、流程轴', (tester) async {
      await seedProject();
      await pumpPanel(tester);

      expect(textOf(tester, 'panel-project-name').data, '毕业论文');
      // 行 3 一句写完「共几步·第几步·步名」，不再单起一行显示步名。
      expect(textOf(tester, 'panel-meta').data, '共7步·第3步·写第三章');
      expect(find.byKey(const ValueKey<String>('panel-solo-name')), findsNothing);
    });

    testWidgets('独立事项走形态 B：只有名字，不画轴', (tester) async {
      await container.read(taskRepositoryProvider).createSolo(name: '买猫粮', nowMs: 1000);
      await pumpPanel(tester);

      expect(textOf(tester, 'panel-solo-name').data, '买猫粮');
      expect(find.byKey(const ValueKey<String>('panel-track')), findsNothing);
      // 独立事项没有截止字段，第一行右侧那一截不出现。
      expect(find.byKey(const ValueKey<String>('panel-due')), findsNothing);
    });
  });

  group('流程轴', () {
    testWidgets('7 步画 7 段，走到第 3 步亮 3 段', (tester) async {
      await seedProject();
      await pumpPanel(tester);

      for (var i = 0; i < 7; i++) {
        expect(find.byKey(ValueKey<String>('panel-track-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey<String>('panel-track-7')), findsNothing);

      for (var i = 0; i < 7; i++) {
        final segment = tester.widget<Container>(find.byKey(ValueKey<String>('panel-track-$i')));
        final color = (segment.decoration! as BoxDecoration).color;
        expect(color, i < 3 ? AppTheme.primary : AppTheme.track);
      }
    });

    testWidgets('每段鼠标停上去能看见这一步的名字', (tester) async {
      await seedProject();
      await pumpPanel(tester);

      // 原型 buildTrack 给每段挂了 tip，鼠标停在上面显示步名。
      expect(
        tester.widget<Tooltip>(find.byKey(const ValueKey<String>('panel-track-tip-0'))).message,
        '选题',
      );
      expect(
        tester.widget<Tooltip>(find.byKey(const ValueKey<String>('panel-track-tip-6'))).message,
        '答辩',
      );
    });
  });

  group('数值照原型', () {
    testWidgets('面板内边距 16、圆角 10、段高 5、段圆角 3', (tester) async {
      await seedProject();
      await pumpPanel(tester);

      final shell = tester.widget<Container>(
        find.descendant(of: find.byType(PanelPage), matching: find.byType(Container)).first,
      );
      expect(shell.padding, const EdgeInsets.all(16));
      final decoration = shell.decoration! as BoxDecoration;
      // 原型 `.panel{border-radius:var(--r)}`，--r 是 10。
      expect(decoration.borderRadius, BorderRadius.circular(AppTheme.radiusControl));
      final shadow = decoration.boxShadow!.single;
      expect(shadow.blurRadius, 32);
      expect(shadow.offset, const Offset(0, 12));

      final segment = tester.widget<Container>(find.byKey(const ValueKey<String>('panel-track-0')));
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-track-0'))).height, 5);
      expect((segment.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(3));
    });

    testWidgets('字号与按钮尺寸：项目名 15、元信息 12、标签 11、随手记与问一问同 13', (
      tester,
    ) async {
      await seedProject();
      await pumpPanel(tester);

      expect(textOf(tester, 'panel-project-name').style?.fontSize, 15);
      expect(textOf(tester, 'panel-meta').style?.fontSize, 12);
      expect(tester.widget<Text>(find.text('随手记')).style?.fontSize, 11);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey<String>('panel-scratch')))
            .style
            ?.fontSize,
        13,
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-start'))).height, 44);
      expect(find.text('开始'), findsOneWidget);
      expect(find.text('标记完成'), findsOneWidget);
    });

    // 1920×1080 上真实的面板是 480×378，固定高度的四块加起来不能把它顶爆。
    testWidgets('真实尺寸 480×378 排得下，问一问仍在最底', (tester) async {
      await seedProject();
      await pumpPanel(tester, size: const Size(480, 378));

      expect(tester.takeException(), isNull);
      final ask = tester.getRect(find.byKey(const ValueKey<String>('panel-ask')));
      final panel = tester.getRect(find.byType(PanelPage));
      expect(panel.bottom - ask.bottom, closeTo(16, 1.5));
    });

    testWidgets('随手记框与问一问框同高 38，计时条紧贴随手记下方', (tester) async {
      await seedProject();
      await pumpPanel(tester);

      final scratch = tester.getRect(find.byKey(const ValueKey<String>('panel-scratch')));
      final ask = tester.getRect(find.byKey(const ValueKey<String>('panel-ask')));
      final action = tester.getRect(find.byKey(const ValueKey<String>('panel-start')));

      expect(scratch.height, 38);
      expect(ask.height, 38);
      // 计时行（这里是还没开始时的「开始」）紧贴在随手记框正下方。
      expect(action.top - scratch.bottom, lessThanOrEqualTo(8));
      // 问一问钉在面板最底部：面板 420 高、内边距 16（描边占 1 像素）。
      final panel = tester.getRect(find.byType(PanelPage));
      expect(panel.bottom - ask.bottom, closeTo(16, 1.5));
      // 中间那块留给回答内容。
      expect(ask.top, greaterThan(action.bottom));
    });
  });

  group('没接模型时的禁用态', () {
    testWidgets('问一问只读、占位指路设置页、发送键禁用且压到 0.4', (tester) async {
      await seedProject();
      await pumpPanel(tester);

      final ask = tester.widget<TextField>(find.byKey(const ValueKey<String>('panel-ask')));
      expect(ask.readOnly, isTrue);
      expect(ask.style?.fontSize, 13);
      // 只读时字色降一档。
      expect(ask.style?.color, AppTheme.ink2);
      // 原型 `renderAi`：没配 key 时占位文字直接指到设置页。
      // 《页面操作流程》第 4 节的原话：「请前往设置页配置API key」。
      expect(ask.decoration?.hintText, '请前往设置页配置API key');
      expect(ask.decoration?.fillColor, const Color(0xFFF4F7FB));

      expect(
        tester.widget<OutlinedButton>(find.byKey(const ValueKey<String>('panel-send'))).onPressed,
        isNull,
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-send'))), const Size(42, 38));

      // 纸飞机图标逆时针转 90°：quarterTurns 顺时针计数，3 格即逆时针 90°。
      expect(
        tester
            .widget<RotatedBox>(
              find.descendant(
                of: find.byKey(const ValueKey<String>('panel-send')),
                matching: find.byType(RotatedBox),
              ),
            )
            .quarterTurns,
        3,
      );

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('panel-send')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.4);

      // 原型没有另加一行说明，占位文字自己就说清了。
      expect(find.byKey(const ValueKey<String>('panel-ask-hint')), findsNothing);
    });

    testWidgets('配了 key 之后问一问当场可写，不等重进面板', (tester) async {
      await seedProject();
      await container.read(settingsRepositoryProvider).setKeyConfigured(true);
      await pumpPanel(tester);

      final ask = tester.widget<TextField>(find.byKey(const ValueKey<String>('panel-ask')));
      expect(ask.readOnly, isFalse);
      expect(ask.decoration?.hintText, isNot('请前往设置页配置API key'));
      expect(
        tester.widget<OutlinedButton>(find.byKey(const ValueKey<String>('panel-send'))).onPressed,
        isNotNull,
      );
      expect(container.read(keyConfiguredProvider), isTrue);
    });

    testWidgets('开始键是主色 44 高，点下去能真开表', (tester) async {
      final taskId = await seedProject();
      await pumpPanel(tester);

      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey<String>('panel-start'))).onPressed,
        isNotNull,
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-start'))).height, 44);

      await tester.tap(find.byKey(const ValueKey<String>('panel-start')));
      await tester.pump();

      // 点下去之后原位换成计时条，服务里也在跑这一件。
      expect(container.read(panelNotifierProvider).running, isTrue);
      expect(timer.running?.taskId, taskId);
      expect(find.byKey(const ValueKey<String>('panel-clock')), findsOneWidget);

      timer.stop();
    });
  });

  group('随手记落盘', () {
    testWidgets('改完字失焦才写库，没失焦前库还是空的', (tester) async {
      final taskId = await seedProject();
      await pumpPanel(tester);

      await tester.enterText(find.byKey(const ValueKey<String>('panel-scratch')), '结论要三句话');
      await tester.pump();
      expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId), isEmpty);

      // 把焦点挪到问一问那一栏，随手记失焦，这时才落盘。
      await tester.tap(find.byKey(const ValueKey<String>('panel-ask')));
      await tester.pumpAndSettle();

      expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId), '结论要三句话');
    });
  });

  group('勾完成', () {
    testWidgets('项目事项点「标记完成」后换成下一步，不带完成提示', (tester) async {
      final projectId = await container
          .read(projectRepositoryProvider)
          .create(name: '毕业论文', nowMs: 1000);
      final tasks = container.read(taskRepositoryProvider);
      final first = await tasks.createForProject(projectId: projectId, name: '先把摘要写完', nowMs: 1000);
      final second = await tasks.createForProject(projectId: projectId, name: '再把结论写完', nowMs: 1001);
      await pumpPanel(tester);
      expect(container.read(panelNotifierProvider).taskId, first);

      await tester.tap(find.byKey(const ValueKey<String>('panel-finish')));
      await tester.pumpAndSettle();

      // 使用者 2026-10-26：项目事项完成后直接摆下一步，直到全部做完。
      expect(container.read(panelNotifierProvider).taskId, second);
      expect(find.byKey(const ValueKey<String>('panel-done-note')), findsNothing);
      expect(find.byKey(const ValueKey<String>('panel-start')), findsOneWidget);
    });

    testWidgets('独立事项点「标记完成」：没有下一件就回无事项', (tester) async {
      final taskId = await container
          .read(taskRepositoryProvider)
          .createSolo(name: '买猫粮', nowMs: 1000);
      await pumpPanel(tester);

      await tester.tap(find.byKey(const ValueKey<String>('panel-finish')));
      await tester.pumpAndSettle();

      // 《页面操作流程》第 4 节类型 2：没有下一个独立事项就恢复无事项状态。
      expect((await container.read(taskRepositoryProvider).byId(taskId))!.done, isTrue);
      expect(container.read(panelNotifierProvider).isEmpty, isTrue);
      expect(textOf(tester, 'panel-empty-title').data, '当前暂无事项');
    });
  });

  group('问答记录', () {
    testWidgets('有回答时按原型画成卡片，问与答分两行', (tester) async {
      final stub = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          panelNotifierProvider.overrideWith(_AnsweredPanel.new),
        ],
      );
      addTearDown(stub.dispose);
      await pumpPanel(tester, scope: stub);

      expect(find.text('你问：怎么写开头'), findsOneWidget);
      expect(find.text('先写结论，再用两句解释。'), findsOneWidget);

      final card = tester.widget<Container>(find.byKey(const ValueKey<String>('panel-answer-0')));
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.primarySoft);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(card.padding, const EdgeInsets.symmetric(horizontal: 12, vertical: 10));
    });
  });

  group('计时条', () {
    testWidgets('计时中把「开始」换成时钟与两个图标键', (tester) async {
      final taskId = await seedProject();
      final notifier = container.read(panelNotifierProvider.notifier);
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      await pumpPanel(tester);

      expect(find.byKey(const ValueKey<String>('panel-start')), findsNothing);
      // 类型 1 的 8 行里，「标记完成」是固定的一行，计时中也在。
      expect(find.byKey(const ValueKey<String>('panel-finish')), findsOneWidget);

      final clock = textOf(tester, 'panel-clock');
      // 《页面操作流程》第 4 节：以 00:00:00 的格式呈现当前计时。
      expect(clock.data, '00:00:00');
      // 原型 `.clock`：21 号、行高 1、字距 .5、等宽数字。
      expect(clock.style?.fontSize, 21);
      expect(clock.style?.height, 1);
      expect(clock.style?.letterSpacing, 0.5);
      expect(clock.style?.fontFeatures, const [FontFeature.tabularFigures()]);

      // 两个图标键都是 44 × 38。
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-pause'))), const Size(44, 38));
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-stop'))), const Size(44, 38));

      // 停止键红底白字，暂停键白底。
      final stop = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('panel-stop')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(stop.color, AppTheme.danger);
      final pause = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('panel-pause')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(pause.color, Colors.white);

      // 悬停按原型换色：普通键边与图标转主色，停止键底色压深一档。
      Material materialOf(String key) => tester.widget<Material>(
        find
            .descendant(of: find.byKey(ValueKey<String>(key)), matching: find.byType(Material))
            .first,
      );
      Color borderOf(String key) => (materialOf(key).shape! as RoundedRectangleBorder).side.color;
      Icon iconOf(String key) => tester.widget<Icon>(
        find.descendant(of: find.byKey(ValueKey<String>(key)), matching: find.byType(Icon)).first,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();

      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey<String>('panel-pause'))));
      await tester.pump(const Duration(milliseconds: 10));
      expect(borderOf('panel-pause'), AppTheme.primary);
      expect(iconOf('panel-pause').color, AppTheme.primary);

      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey<String>('panel-stop'))));
      await tester.pump(const Duration(milliseconds: 10));
      // 原型 `.timerbar button.stop:hover{background:#c8402f;border-color:#c8402f}`。
      expect(materialOf('panel-stop').color, const Color(0xFFC8402F));
      expect(iconOf('panel-stop').color, Colors.white);

      timer.stop();
    });

    testWidgets('点暂停：停表不标完成，暂停键变「开始」', (tester) async {
      final taskId = await seedProject();
      final notifier = container.read(panelNotifierProvider.notifier);
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      await pumpPanel(tester);

      await tester.tap(find.byKey(const ValueKey<String>('panel-pause')));
      await tester.pumpAndSettle();

      // 《页面操作流程》第 4 节：「点击暂停按钮，计时暂停，暂停按钮变为开始按钮」，
      // 事项状态只到「进行中」，不标完成。
      expect((await container.read(taskRepositoryProvider).byId(taskId))!.done, isFalse);
      expect(find.byKey(const ValueKey<String>('panel-clock')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('panel-resume')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('panel-pause')), findsNothing);
      expect(
        tester
            .widget<Tooltip>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey<String>('panel-resume')),
                    matching: find.byType(Tooltip),
                  )
                  .first,
            )
            .message,
        '开始',
      );
      expect(find.byKey(const ValueKey<String>('panel-stop')), findsOneWidget);

      timer.stop();
    });

    testWidgets('停过时长的这一件：时钟停在累计值，右侧给「开始」「停止」', (tester) async {
      final taskId = await seedProject();
      final notifier = container.read(panelNotifierProvider.notifier);
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 3000;
      await notifier.settleRunning();
      await pumpPanel(tester);

      expect(textOf(tester, 'panel-clock').data, '00:00:03');
      expect(find.byKey(const ValueKey<String>('panel-resume')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('panel-pause')), findsNothing);
      // 规格里没有「重置」这一档。
      expect(find.byKey(const ValueKey<String>('panel-reset')), findsNothing);
      // 类型 1 的「标记完成」是固定行，攒着时长也照在。
      expect(find.byKey(const ValueKey<String>('panel-finish')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey<String>('panel-resume'))), const Size(44, 38));
    });

    testWidgets('退回未完成后点「开始」，从累计值接着走', (tester) async {
      final taskId = await seedProject();
      final notifier = container.read(panelNotifierProvider.notifier);
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 2000;
      await notifier.settleRunning();

      // 使用者从第 4 页把这一件退回未完成，面板跟着重读。
      await container
          .read(finishTaskProvider)
          .call(taskId: taskId, nowMs: nowMs, done: false);
      await notifier.refresh();
      await pumpPanel(tester);

      expect(textOf(tester, 'panel-clock').data, '00:00:02');

      await tester.tap(find.byKey(const ValueKey<String>('panel-resume')));
      await tester.pump();

      expect(container.read(panelNotifierProvider).running, isTrue);
      expect(timer.running?.taskId, taskId);
      // 接着走之后回到「暂停 / 停止」，时钟还从累计值往上。
      expect(find.byKey(const ValueKey<String>('panel-pause')), findsOneWidget);
      expect(textOf(tester, 'panel-clock').data, '00:00:02');

      timer.stop();
    });

    testWidgets('点停止：停表、标完成，面板回无事项', (tester) async {
      final taskId = await container
          .read(taskRepositoryProvider)
          .createSolo(name: '买猫粮', nowMs: 1000);
      final notifier = container.read(panelNotifierProvider.notifier);
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      await pumpPanel(tester);

      await tester.tap(find.byKey(const ValueKey<String>('panel-stop')));
      await tester.pumpAndSettle();

      // 使用者 2026-10-26：停止＝停表 + 标完成 + 面板回无事项。
      expect(find.byKey(const ValueKey<String>('panel-clock')), findsNothing);
      expect(find.byKey(const ValueKey<String>('panel-start')), findsNothing);
      expect(find.byKey(const ValueKey<String>('panel-empty-title')), findsOneWidget);
      expect((await container.read(taskRepositoryProvider).byId(taskId))!.done, isTrue);
    });
  });
}

/// 造一个已经带问答记录的面板。B09 还没接模型，正常路径上 `answers` 永远是空的。
class _AnsweredPanel extends PanelNotifier {
  @override
  PanelState build() => const PanelState(
    kind: PanelKind.solo,
    taskId: 't-answer',
    title: '回面试邮件',
    answers: [PanelAnswer(question: '怎么写开头', text: '先写结论，再用两句解释。')],
  );
}
