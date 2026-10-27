import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/domain/model/settings.dart';
import 'package:ai_pet_assistant/features/pet/pet_message.dart';
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 常驻态的账：播报只出一次、截止按档去重、悬停计时、点一下进主界面。
///
/// 库用内存库：这一层要验的是「读了库之后怎么摆气泡」，不是 SQL 本身。
void main() {
  late AppDb db;
  late ProviderContainer container;

  setUp(() {
    db = AppDb.memory();
    container = ProviderContainer(overrides: [appDbProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch;

  /// 等到条件成立。_load 是异步的，读一次 provider 不会立刻有气泡。
  Future<void> waitFor(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: '等不到期望的状态');
  }

  PetNotifier notifier() => container.read(petNotifierProvider.notifier);
  PetState state() => container.read(petNotifierProvider);

  Future<String> project({required String name, int? dueAt, List<String> steps = const []}) async {
    final projects = container.read(projectRepositoryProvider);
    final id = await projects.create(name: name, dueAt: dueAt, nowMs: now);
    if (steps.isNotEmpty) {
      await projects.replaceSteps(id, steps);
      await projects.setCurrentStep(id, 0);
    }
    return id;
  }

  group('首屏', () {
    test('播报每个项目一行，最多三行，剩下的说还有几个', () async {
      for (var i = 0; i < 5; i++) {
        await project(name: '项目$i', steps: ['第一步']);
      }

      notifier();
      await waitFor(() => state().report != null);

      final report = state().report!;
      expect(report.rows, hasLength(PetNotifier.maxReportRows));
      expect(report.more, 2);
      expect(report.rows.first.name, '项目0');
    });

    test('播报不点会自己收：时长走 provider，测试按 30 毫秒推进', () async {
      final quick = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          petReportLingerProvider.overrideWithValue(const Duration(milliseconds: 30)),
        ],
      );
      addTearDown(quick.dispose);
      await project(name: '项目0');

      quick.read(petNotifierProvider.notifier);
      final limit = DateTime.now().add(const Duration(seconds: 3));
      while (quick.read(petNotifierProvider).report == null && DateTime.now().isBefore(limit)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(quick.read(petNotifierProvider).report, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(quick.read(petNotifierProvider).report, isNull);
    });

    test('播报只出一次：再看一次截止也不会再冒出来', () async {
      await project(name: '配音练习', steps: ['对稿']);
      notifier();
      await waitFor(() => state().report != null);

      await notifier().refreshDeadlines();

      expect(state().bubbles.whereType<ReportBubble>(), hasLength(1));
    });

    test('侧别恒为右缘，高度跟着设置走', () async {
      // 使用者 2026-10-26：只做右缘，设置里残留的左侧不再生效。
      await container.read(settingsRepositoryProvider).setSide(PetSide.left);
      await container.read(settingsRepositoryProvider).setAnchorY(0.2);

      notifier();
      // 首屏默认 0.5，等 _load 把设置读回来再判。
      await waitFor(() => (state().anchorY - 0.2).abs() < 0.0001);

      expect(state().side, PetSide.right);
      expect(state().anchorY, closeTo(0.2, 0.0001));
    });

    test('一个项目都没有时只显示形象，不出气泡', () async {
      notifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(state().hasBubbles, isFalse);
    });
  });

  group('截止', () {
    test('24 小时内提醒一次，2 小时档再提醒一次并标紧急', () async {
      final id = await project(
        name: '求职',
        dueAt: now + const Duration(hours: 3).inMilliseconds,
        steps: ['回面试邮件'],
      );
      notifier();
      await waitFor(() => state().deadline != null);

      expect(state().deadline!.urgent, isFalse);
      expect(state().deadline!.name, '求职 · 回面试邮件');

      await container
          .read(projectRepositoryProvider)
          .setDueAt(id, now + const Duration(minutes: 90).inMilliseconds);
      await notifier().refreshDeadlines();

      expect(state().deadline!.urgent, isTrue);
      expect(state().bubbles.whereType<DeadlineBubble>(), hasLength(1));
    });

    test('同一档不重复提醒：连着看三次还是一条', () async {
      await project(name: '求职', dueAt: now + 3600 * 1000);
      notifier();
      await waitFor(() => state().deadline != null);

      await notifier().refreshDeadlines();
      await notifier().refreshDeadlines();

      expect(state().bubbles.whereType<DeadlineBubble>(), hasLength(1));
    });

    test('已经过期的截止不提醒', () async {
      await project(name: '求职', dueAt: now - 3600 * 1000);
      notifier();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(state().deadline, isNull);
    });

    test('截止气泡与播报能同时挂着', () async {
      await project(name: '求职', dueAt: now + 3600 * 1000);
      await project(name: '配音练习');

      notifier();
      await waitFor(() => state().deadline != null && state().report != null);

      expect(state().hasBubbles, isTrue);
      expect(state().bubbles, hasLength(2));
    });
  });

  group('悬停与切档', () {
    test('悬停满 300 毫秒才出面板，早一点不算', () async {
      notifier();
      await waitFor(() => true);

      notifier().hoverEnter();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(state().stage, PetViewStage.collapsed);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(state().stage, PetViewStage.panel);
    });

    test('移开后留一点余量才收，挪到面板上不会闪', () async {
      notifier();
      await waitFor(() => true);
      notifier().hoverEnter();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      notifier().hoverExit();
      expect(state().stage, PetViewStage.panel);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(state().stage, PetViewStage.collapsed);
    });

    test('点一下进主界面档，再点回来', () async {
      notifier();
      await waitFor(() => true);

      notifier().openMain();
      expect(state().stage, PetViewStage.main);

      notifier().collapse();
      expect(state().stage, PetViewStage.collapsed);
    });

    test('拖动起手先收面板，免得窗口被面板档占着', () async {
      notifier();
      await waitFor(() => true);
      notifier().hoverEnter();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(state().stage, PetViewStage.panel);

      notifier().onDragStart();

      expect(state().stage, PetViewStage.collapsed);
    });

    test('托盘点唤出主界面：只打一下闸，导航交给界面', () {
      final n = notifier();
      final before = n.mainRequests.value;

      n.requestMain();

      expect(n.mainRequests.value, before + 1);
      // 它自己不切档——切档与导航是界面那一步的事，这里想越位就会与点击冲突。
      expect(state().stage, PetViewStage.collapsed);
    });

    test('拖过一轮后指针还停在宠物上，也不弹面板', () async {
      notifier();
      await waitFor(() => true);

      notifier().onDragStart();
      notifier().hoverEnter();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(state().stage, PetViewStage.collapsed);

      // 指针离开再回来才恢复：原型 `dragSuppress` 就是这么清的。
      notifier().hoverExit();
      notifier().hoverEnter();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(state().stage, PetViewStage.panel);
    });

    test('主界面档里悬停不再弹面板', () async {
      notifier();
      await waitFor(() => true);
      notifier().openMain();

      notifier().hoverEnter();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(state().stage, PetViewStage.main);
    });
  });

  group('关气泡', () {
    test('关掉一档不影响另一档', () async {
      await project(name: '求职', dueAt: now + 3600 * 1000);
      await project(name: '配音练习');
      notifier();
      await waitFor(() => state().deadline != null && state().report != null);

      notifier().dismiss(PetBubbleKind.deadline);

      expect(state().deadline, isNull);
      expect(state().report, isNotNull);
    });

    test('「知道了」只收掉那一个项目的气泡，别家的还挂着', () async {
      // 《页面操作流程》第 3 节：一条截止气泡对一个项目，各收各的。
      await project(name: '求职', dueAt: now + 3600 * 1000);
      await project(name: '毕业论文', dueAt: now + 3600 * 1000);
      notifier();
      await waitFor(() => state().deadlines.length >= 2);

      final first = state().deadlines.first;
      notifier().dismissDeadline(first.projectId);

      expect(state().deadlines, hasLength(1));
      expect(state().deadlines.single.projectId, isNot(first.projectId));
    });

    test('气泡栈最多摆三块，多出来的先挂着', () async {
      for (var i = 0; i < 4; i++) {
        await project(name: '项目$i', dueAt: now + 3600 * 1000);
      }
      notifier();
      await waitFor(() => state().bubbles.length >= 4);

      expect(state().visibleBubbles, hasLength(3));
      expect(state().visibleBubbles.first, same(state().bubbles.first));
    });
  });
}
