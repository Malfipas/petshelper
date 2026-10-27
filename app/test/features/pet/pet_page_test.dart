import 'dart:ui';

import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/features/pet/pet_bubble_view.dart';
import 'package:ai_pet_assistant/features/pet/pet_frame.dart';
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_page.dart';
import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_pet_stage_port.dart';

/// 一个带气泡占位的窗口：两个气泡摞在头顶，宠物在下面。
///
/// 高度按气泡的内容高度留：截止 120、三行播报 300，跟窗口层算出来的比例一致。
const PetFrame bubbleFrame = PetFrame(
  size: Size(240, 676),
  pet: Rect.fromLTWH(0, 436, 240, 240),
  deadlineBubble: Rect.fromLTWH(0, 308, 240, 120),
  reportBubble: Rect.fromLTWH(0, 0, 240, 300),
);

/// 面板档：宠物在右下，左边上方空出一块给悬停面板。
const PetFrame panelFrame = PetFrame(
  size: Size(400, 700),
  pet: Rect.fromLTWH(160, 460, 240, 240),
  panel: Rect.fromLTWH(0, 100, 400, 340),
);

/// 常驻态界面：形象、气泡、悬停出面板、点一下开主界面。
///
/// 用假端口记下界面推过去的档位——窗口真长什么样不在这一层验。
void main() {
  late AppDb db;
  late FakePetStagePort port;
  late ProviderContainer container;

  setUp(() {
    db = AppDb.memory();
    port = FakePetStagePort();
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        petStagePortProvider.overrideWithValue(port),
        // 界面测试不需要轮询、也不需要播报自己走，留着定时器会被当成悬挂任务。
        petPollIntervalProvider.overrideWithValue(null),
        petReportLingerProvider.overrideWithValue(null),
      ],
    );
    container.read(petFrameProvider.notifier).apply(bubbleFrame);
  });

  tearDown(() async {
    container.dispose();
    port.dispose();
    await db.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onOpenMain,
    void Function(String)? onViewProject,
    VoidCallback? onOpenSettings,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PetPage(
            onOpenMain: onOpenMain,
            onViewProject: onViewProject,
            onOpenSettings: onOpenSettings,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 把鼠标挪到某处。悬停要真指针事件，光 pump 不出面板。
  Future<TestGesture> mouseTo(WidgetTester tester, Offset at) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(at);
    await tester.pump();
    return mouse;
  }

  /// 宠物热区的中心。形象图在测试里加载不出尺寸，量它会落到框的边界上。
  Offset petCenter(WidgetTester tester) => tester.getCenter(find.byKey(petHotZoneKey));

  group('形象', () {
    testWidgets('常驻档只画宠物，画面里没有面板也没有气泡', (tester) async {
      await pumpPage(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(DeadlineBubbleView), findsNothing);
      expect(find.byType(ReportBubbleView), findsNothing);
    });

    testWidgets('悬停满 300 毫秒才把面板档推给窗口', (tester) async {
      await pumpPage(tester);
      await mouseTo(tester, petCenter(tester));

      await tester.pump(const Duration(milliseconds: 150));
      expect(port.calls, isNot(contains('panel')));

      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(petNotifierProvider).stage, PetViewStage.panel);
      expect(port.calls, contains('panel'));
    });

    testWidgets('移开之后过一会儿收回常驻档', (tester) async {
      await pumpPage(tester);
      final mouse = await mouseTo(tester, petCenter(tester));
      await tester.pump(const Duration(milliseconds: 350));
      expect(port.calls, contains('panel'));

      await mouse.moveTo(const Offset(-50, -50));
      await tester.pump(const Duration(milliseconds: 600));

      expect(container.read(petNotifierProvider).stage, PetViewStage.collapsed);
      expect(port.calls.last, 'collapsed');
    });

    testWidgets('悬停出面板后能看见项目名与当前步', (tester) async {
      final projects = container.read(projectRepositoryProvider);
      final projectId = await projects.create(name: '毕业论文', nowMs: 1000);
      await projects.replaceSteps(projectId, ['选题', '开题', '写第三章']);
      await projects.setCurrentStep(projectId, 2);
      await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: projectId, name: '把结论写成三句话', nowMs: 1000);
      container.read(petFrameProvider.notifier).apply(panelFrame);

      await pumpPage(tester);
      final mouse = await mouseTo(tester, petCenter(tester));
      await tester.pump(const Duration(milliseconds: 350));
      // 面板自己要去库里挑当前事务，多给一会儿让异步读完。
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(petNotifierProvider).stage, PetViewStage.panel);
      expect(find.text('毕业论文'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey<String>('panel-meta'))).data,
        '共3步·第3步·写第三章',
      );

      // 鼠标挪开，让悬停计时器收掉，免得留下悬挂任务。
      await mouse.moveTo(const Offset(-50, -50));
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('右键宠物先切到主界面档，再打开设置', (tester) async {
      var settings = 0;
      var opened = 0;
      await pumpPage(tester, onOpenMain: () => opened++, onOpenSettings: () => settings++);

      final gesture = await tester.startGesture(petCenter(tester), buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pump();

      // 只跳路由不切档的话，设置页会挤进收起态那个小窗里。
      expect(container.read(petNotifierProvider).stage, PetViewStage.main);
      expect(port.calls, contains('main'));
      expect(opened, 1);
      expect(settings, 1);

      // 已经在主界面档，再右键不重复摆一次窗口。
      final again = await tester.startGesture(petCenter(tester), buttons: kSecondaryMouseButton);
      await again.up();
      await tester.pump();

      expect(opened, 1);
      expect(settings, 2);
    });

    testWidgets('托盘点唤出主界面时，常驻页切展开态并叫路由开主界面', (tester) async {
      var opened = 0;
      await pumpPage(tester, onOpenMain: () => opened++);

      container.read(petNotifierProvider.notifier).requestMain();
      await tester.pump(const Duration(milliseconds: 50));

      expect(opened, 1);
      expect(container.read(petNotifierProvider).stage, PetViewStage.main);
    });

    testWidgets('点一下切展开态、把主界面档推给窗口，并叫路由开主界面', (tester) async {
      var opened = 0;
      await pumpPage(tester, onOpenMain: () => opened++);

      await tester.tapAt(petCenter(tester));
      await tester.pump();

      expect(container.read(petNotifierProvider).stage, PetViewStage.main);
      expect(port.calls, contains('main'));
      expect(opened, 1);
    });
  });

  group('气泡', () {
    testWidgets('截止与播报同时挂着时各占一块，播报最多三行', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 4; i++) {
        await container.read(projectRepositoryProvider).create(name: '项目$i', nowMs: now);
      }
      await container
          .read(projectRepositoryProvider)
          .create(name: '求职', dueAt: now + 3600 * 1000, nowMs: now);

      await pumpPage(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DeadlineBubbleView), findsOneWidget);
      expect(find.byType(ReportBubbleView), findsOneWidget);
      // 《页面操作流程》第 2 节：不写「开机播报」「还有 N 个」「15 秒后自动收起」。
      expect(find.text('开机播报'), findsNothing);
      expect(find.textContaining('还有'), findsNothing);
      expect(find.text('15 秒后自动收起'), findsNothing);
      // 底部只有右侧两个按钮：两块气泡各一对。
      expect(find.text('查看'), findsNWidgets(2));
      expect(find.text('知道了'), findsNWidgets(2));
      expect(port.bubbles?.deadlineHeight, isNotNull);
      expect(port.bubbles?.reportHeight, isNotNull);
    });

    test('气泡栈最多摆三块，多出来的先挂着', () {
      // 《页面操作流程》第 2 节：按出现时间先后从下至上排列，最多呈现三个。
      final bubbles = <PetBubble>[
        for (var i = 0; i < 4; i++)
          DeadlineBubble(
            projectId: 'p$i',
            name: '项目$i',
            headline: '将于 2026年10月31日 截止',
            urgent: false,
          ),
      ];
      final state = PetState(bubbles: bubbles);

      expect(state.bubbles, hasLength(4));
      expect(state.visibleBubbles, hasLength(3));
      expect(state.deadlines, hasLength(3));
      // 新的在前，也就是摆在上面的那一块。
      expect(state.visibleBubbles.first, same(bubbles.first));
    });

    testWidgets('点「查看」既关掉气泡，也把项目 id 交出去', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final projectId = await container
          .read(projectRepositoryProvider)
          .create(name: '求职', dueAt: now + 3600 * 1000, nowMs: now);
      String? viewed;
      await pumpPage(tester, onViewProject: (id) => viewed = id);
      await tester.pump(const Duration(milliseconds: 100));

      // 播报那条也有「查看」，只点截止那张卡上的。
      await tester.tap(
        find.descendant(of: find.byType(DeadlineBubbleView), matching: find.text('查看')),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(viewed, projectId);
      expect(port.bubbles?.deadlineHeight, isNull);
      expect(find.byType(DeadlineBubbleView), findsNothing);
    });

    testWidgets('点「知道了」关掉播报，窗口立刻缩回去', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await container.read(projectRepositoryProvider).create(name: '项目0', nowMs: now);
      await pumpPage(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ReportBubbleView), findsOneWidget);

      await tester.tap(
        find.descendant(of: find.byType(ReportBubbleView), matching: find.text('知道了')),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ReportBubbleView), findsNothing);
      expect(port.bubbles?.reportHeight, isNull);
    });

    testWidgets('Esc 把气泡全关掉：截止那张没有关闭按钮，只能这么收', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await container.read(projectRepositoryProvider).create(name: '项目0', nowMs: now);
      await pumpPage(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ReportBubbleView), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ReportBubbleView), findsNothing);
      expect(port.bubbles?.reportHeight, isNull);
    });
  });

  group('拖动', () {
    /// 主界面档的窗口：主界面居中，宠物贴桌面右缘。
    const mainFrame = PetFrame(
      size: Size(1920, 1080),
      pet: Rect.fromLTWH(1632, 598, 288, 288),
      main: Rect.fromLTWH(288, 156, 1344, 756),
    );

    /// 画布要跟帧一样大，否则宠物框落在默认 800×600 的画布外，指针压根点不到它。
    void sizeCanvas(WidgetTester tester, PetFrame frame) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = frame.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// 按住宠物左键拖一段。`moves` 是逐次位移，第一次要比 slop 大才算起手。
    Future<void> dragPet(WidgetTester tester, List<Offset> moves) async {
      final start = petCenter(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(start);
      await mouse.down(start);
      for (final move in moves) {
        await mouse.moveBy(move);
        await tester.pump();
      }
      await mouse.up();
      await tester.pump();
    }

    testWidgets('主界面档拖宠物：逐帧喂位移，抬手收尾', (tester) async {
      container.read(petNotifierProvider.notifier).openMain();
      container.read(petFrameProvider.notifier).apply(mainFrame);
      sizeCanvas(tester, mainFrame);
      await pumpPage(tester);
      expect(container.read(petNotifierProvider).stage, PetViewStage.main);

      await dragPet(tester, const [
        Offset(10, 0),
        Offset(20, 10),
        Offset(30, 20),
      ]);

      expect(port.drags, 1);
      expect(port.dragEnds, 1);
      // 起手那一下只用来过 slop，后面两次位移逐帧喂给窗口层。
      expect(port.offsets, const [Offset(20, 10), Offset(30, 20)]);
    });

    testWidgets('主界面档只是点一下：不起手拖动，也不喂位移', (tester) async {
      container.read(petNotifierProvider.notifier).openMain();
      container.read(petFrameProvider.notifier).apply(mainFrame);
      sizeCanvas(tester, mainFrame);
      await pumpPage(tester);

      final start = petCenter(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(start);
      await mouse.down(start);
      // 只挪 2 像素，没过 4 像素的 slop，应当当点击处理。
      await mouse.moveBy(const Offset(2, 0));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(port.drags, 0);
      expect(port.offsets, isEmpty);
    });

    testWidgets('常驻档拖宠物交给系统，不在这里喂位移', (tester) async {
      sizeCanvas(tester, bubbleFrame);
      await pumpPage(tester);

      await dragPet(tester, const [Offset(10, 0), Offset(20, 10)]);

      expect(port.drags, 1);
      // 常驻档窗口就是宠物本身，整窗跟手由窗口层接管。
      expect(port.offsets, isEmpty);
    });
  });
}
