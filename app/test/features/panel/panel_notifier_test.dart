import 'package:ai_pet_assistant/ai/chat_client.dart';
import 'package:ai_pet_assistant/app/key_configured.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/features/panel/panel_notifier.dart';
import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 面板状态的取舍：摆哪一件事、随手记写到哪、勾完成之后换到哪一件。
void main() {
  late AppDb db;
  late ProviderContainer container;
  late PanelNotifier notifier;

  /// 假时钟：计时服务的走秒靠它推进，不真等。
  late int nowMs;
  late TimerService timer;

  setUp(() {
    db = AppDb.memory();
    nowMs = 500000;
    timer = TimerService(now: () => nowMs);
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        // 服务是全局的，测试要用自己那只假时钟，才推得动秒数。
        timerServiceProvider.overrideWithValue(timer),
      ],
    );
    notifier = container.read(panelNotifierProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    timer.dispose();
    await db.close();
  });

  /// 造一个 7 步的项目，走到第 3 步（索引 2），带一条未完成待办。
  Future<(String, String)> seedProject() async {
    final projects = container.read(projectRepositoryProvider);
    final tasks = container.read(taskRepositoryProvider);
    final projectId = await projects.create(name: '毕业论文', nowMs: 1000);
    await projects.replaceSteps(projectId, ['选题', '开题', '写第三章', '写第四章', '定稿', '送审', '答辩']);
    await projects.setCurrentStep(projectId, 2);
    final taskId = await tasks.createForProject(
      projectId: projectId,
      name: '把第三章结论写成三句话',
      nowMs: 1000,
    );
    return (projectId, taskId);
  }

  group('选当前事务', () {
    test('库里什么都没有时是空态', () async {
      await notifier.refresh();
      final state = container.read(panelNotifierProvider);

      expect(state.kind, PanelKind.empty);
      expect(state.isEmpty, isTrue);
      expect(state.taskId, isNull);
    });

    test('有项目待办时走形态 A，带着步数与当前步', () async {
      await seedProject();
      await notifier.refresh();
      final state = container.read(panelNotifierProvider);

      expect(state.kind, PanelKind.project);
      expect(state.title, '毕业论文');
      expect(state.totalSteps, 7);
      // 项目 currentStep 为 2，即「第 3 步」，流程轴亮 3 段。
      expect(state.currentStep, 3);
      expect(state.stepName, '写第三章');
      // 《页面操作流程》第 4 节定死的写法：「共7步·第3步·做初稿」。
      expect(state.metaLabel, '共7步·第3步·写第三章');
      // 没填截止日期就没有这一截。
      expect(state.dueLabel, isNull);
    });

    test('只有独立事项时走形态 B，没有流程轴', () async {
      await container.read(taskRepositoryProvider).createSolo(name: '买猫粮', nowMs: 1000);
      await notifier.refresh();
      final state = container.read(panelNotifierProvider);

      expect(state.kind, PanelKind.solo);
      expect(state.title, '买猫粮');
      expect(state.hasTrack, isFalse);
    });

    test('待办都做完了就回到空态', () async {
      final (_, taskId) = await seedProject();
      await container.read(taskRepositoryProvider).setDone(taskId, true, 2000);

      await notifier.refresh();
      expect(container.read(panelNotifierProvider).isEmpty, isTrue);
    });

    test('读库出错也落空态，不把异常抛给界面', () async {
      await db.close();
      await notifier.refresh();

      expect(container.read(panelNotifierProvider).isEmpty, isTrue);
    });
  });

  group('随手记', () {
    test('写了草稿不落盘，commit 之后才写', () async {
      final (_, taskId) = await seedProject();
      await notifier.refresh();

      notifier.draftScratch('结论要三句话');
      expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId), isEmpty);

      await notifier.commitScratch();
      expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId), '结论要三句话');
    });

    test('重进面板能读回已落盘的文本', () async {
      final (_, taskId) = await seedProject();
      await notifier.refresh();
      notifier.draftScratch('先写一句');
      await notifier.commitScratch();

      await notifier.commitScratch();
      await notifier.refresh();

      expect(container.read(panelNotifierProvider).scratch, '先写一句');
      expect(container.read(panelNotifierProvider).taskId, taskId);
    });

    test('切事务时把上一件的草稿落盘，切回来还在', () async {
      final tasks = container.read(taskRepositoryProvider);
      final first = await tasks.createSolo(name: '写周报', nowMs: 1000);
      final second = await tasks.createSolo(name: '整理照片', nowMs: 1001);

      await notifier.setCurrentTask(first);
      notifier.draftScratch('周报开头先写结论');
      // 切走：草稿应当在这时落盘。
      await notifier.setCurrentTask(second);
      expect(container.read(panelNotifierProvider).taskId, second);
      expect(container.read(panelNotifierProvider).scratch, isEmpty);

      await notifier.setCurrentTask(first);
      expect(container.read(panelNotifierProvider).scratch, '周报开头先写结论');
    });
  });

  group('勾完成', () {
    test('项目事项完成后置为完成、进度史多一条，面板换到下一步', () async {
      final (projectId, taskId) = await seedProject();
      final next = await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: projectId, name: '把结论贴进正文', nowMs: 1001);
      await notifier.setCurrentTask(taskId);

      await notifier.finish();

      expect((await container.read(taskRepositoryProvider).byId(taskId))!.done, isTrue);
      final bundle = await container.read(projectRepositoryProvider).load(projectId);
      expect(bundle.progress, hasLength(1));
      final state = container.read(panelNotifierProvider);
      // 使用者 2026-10-26：项目事项完成后直接摆下一步，直到全部做完。
      expect(state.taskId, next);
      expect(state.isDone, isFalse);
    });

    test('独立事项完成后换到下一条未完成的，没有就回无事项', () async {
      // 《页面操作流程》第 4 节类型 2：标记完成之后「若有下一个独立事项则切换，
      // 否则恢复无事项状态」。上一版停在完成态的写法已作废。
      final tasks = container.read(taskRepositoryProvider);
      final first = await tasks.createSolo(name: '买猫粮', nowMs: 1000);
      final second = await tasks.createSolo(name: '交电费', nowMs: 1001);
      await notifier.setCurrentTask(first);

      await notifier.finish();

      expect((await tasks.byId(first))!.done, isTrue);
      final state = container.read(panelNotifierProvider);
      expect(state.taskId, second);
      expect(state.isDone, isFalse);

      await notifier.finish();
      expect(container.read(panelNotifierProvider).isEmpty, isTrue);
    });

    test('换一个新的面板实例再挑，会跳过已完成的那件', () async {
      final (projectId, taskId) = await seedProject();
      final next = await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: projectId, name: '把结论贴进正文', nowMs: 1001);
      await notifier.setCurrentTask(taskId);
      await notifier.finish();

      // 另起一个容器等于面板重开：没有显式指定，只能按「未完成」挑。
      final reopened = ProviderContainer(overrides: [appDbProvider.overrideWithValue(db)]);
      addTearDown(reopened.dispose);
      await reopened.read(panelNotifierProvider.notifier).refresh();

      final state = reopened.read(panelNotifierProvider);
      expect(state.taskId, next);
      expect(state.isDone, isFalse);
    });

    test('项目里没有下一步时，完成后回空态', () async {
      await seedProject();
      await notifier.refresh();

      await notifier.finish();
      final done = container.read(panelNotifierProvider);
      expect(done.isDone, isFalse);
      expect(done.isEmpty, isTrue);
    });
  });

  group('问一问', () {
    test('AI 没接通时问一句什么都不改', () async {
      await seedProject();
      await notifier.refresh();

      notifier.ask('这一步该写什么');

      final state = container.read(panelNotifierProvider);
      expect(state.aiReady, isFalse);
      expect(state.answers, isEmpty);
    });
  });

  group('计时', () {
    test('开始后进入计时态，走秒不写库', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);

      await notifier.start();
      nowMs += 3000;

      final state = container.read(panelNotifierProvider);
      expect(state.running, isTrue);
      expect(state.paused, isFalse);
      expect(timer.running!.taskId, taskId);
      // 走秒只动内存：流水没多、累计也没变。
      final tasks = container.read(taskRepositoryProvider);
      expect((await tasks.byId(taskId))!.spentSec, 0);
      expect(await tasks.totalSeconds(taskId), 0);
    });

    test('停止：落一条流水、累加秒数、标完成，面板回无事项', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 3000;

      await notifier.stop();

      final state = container.read(panelNotifierProvider);
      expect(state.running, isFalse);
      expect(state.isEmpty, isTrue);
      expect(timer.running, isNull);
      final tasks = container.read(taskRepositoryProvider);
      expect((await tasks.byId(taskId))!.done, isTrue);
      expect((await tasks.byId(taskId))!.spentSec, 3);
      expect(await tasks.totalSeconds(taskId), 3);
    });

    test('暂停只停表：不结算、不标完成，等继续', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 2000;

      await notifier.pause();

      final state = container.read(panelNotifierProvider);
      expect(state.running, isTrue);
      expect(state.paused, isTrue);
      expect(state.isDone, isFalse);
      expect(state.elapsedMs, 2000);
      expect(timer.running!.paused, isTrue);
      final tasks = container.read(taskRepositoryProvider);
      expect((await tasks.byId(taskId))!.done, isFalse);
      expect((await tasks.byId(taskId))!.spentSec, 0);
    });

    test('退回未完成：计时摆出累计值，继续从累计值接着走，不重复累加', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 2000;
      await notifier.settleRunning();

      // 使用者从第 4 页把这一件退回未完成。
      await container.read(finishTaskProvider).call(taskId: taskId, nowMs: nowMs, done: false);
      await notifier.refresh();

      var state = container.read(panelNotifierProvider);
      expect(state.isDone, isFalse);
      expect(state.running, isFalse);
      expect(state.elapsedMs, 2000);

      await notifier.continueFromSpent();
      nowMs += 3000;
      state = container.read(panelNotifierProvider);
      expect(state.running, isTrue);
      // 走秒靠 tick 推进，这里没有真时钟，直接问服务要净时长。
      expect(timer.elapsedMs(), 5000);

      await notifier.stop();
      final tasks = container.read(taskRepositoryProvider);
      // 只有新走的 3 秒进账：历史那 2 秒早在库里，不能再加一遍。
      expect((await tasks.byId(taskId))!.spentSec, 5);
      expect(await tasks.totalSeconds(taskId), 5);
    });

    test('重置计时：累计与流水一起清掉，回到「开始」', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 4000;
      await notifier.settleRunning();

      await notifier.resetSpent();

      final tasks = container.read(taskRepositoryProvider);
      expect((await tasks.byId(taskId))!.spentSec, 0);
      expect(await tasks.totalSeconds(taskId), 0);
      expect(container.read(panelNotifierProvider).elapsedMs, 0);
    });

    test('跑着点完成，先结算这一轮再标完成', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 4000;

      await notifier.finish();

      final tasks = container.read(taskRepositoryProvider);
      expect((await tasks.byId(taskId))!.done, isTrue);
      expect((await tasks.byId(taskId))!.spentSec, 4);
      expect(await tasks.totalSeconds(taskId), 4);
      expect(container.read(panelNotifierProvider).isEmpty, isTrue);
      expect(timer.running, isNull);
    });

    test('另一条在跑时，这一件开始不了', () async {
      final (projectId, taskId) = await seedProject();
      final other = await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: projectId, name: '另一件', nowMs: 1001);
      // 手工让服务先跑另一条，模拟从第 6 页点开的计时。
      timer.start(other);
      await notifier.setCurrentTask(taskId);

      await notifier.start();

      expect(container.read(panelNotifierProvider).running, isFalse);
      expect(timer.running!.taskId, other);
    });

    test('不足一秒就停止，不写流水', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();
      nowMs += 400;

      await notifier.stop();

      final tasks = container.read(taskRepositoryProvider);
      expect(await tasks.totalSeconds(taskId), 0);
      expect((await tasks.byId(taskId))!.spentSec, 0);
      expect(container.read(panelNotifierProvider).running, isFalse);
    });
  });

  group('《页面操作流程》第 4 节的两处新口径', () {
    test('时钟按 00:00:00 走，过了整点也进位', () async {
      final (_, taskId) = await seedProject();
      await notifier.setCurrentTask(taskId);
      await notifier.start();

      nowMs += 3723 * 1000;
      await notifier.settleRunning();

      expect(container.read(panelNotifierProvider).clockLabel, '01:02:03');
    });

    test('项目填了截止日期，第一行右侧那截写着「2026年10月31日 截止」', () async {
      final projectId = await container
          .read(projectRepositoryProvider)
          .create(
            name: '毕业论文',
            dueAt: DateTime(2026, 10, 31).millisecondsSinceEpoch,
            nowMs: 1000,
          );
      final taskId = await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: projectId, name: '写初稿', nowMs: 1001);
      await notifier.setCurrentTask(taskId);

      expect(container.read(panelNotifierProvider).dueLabel, '2026年10月31日 截止');
    });
  });

  group('问一问接上模型之后', () {
    /// 每条件单开容器，才能把模型客户端换成剧本。
    ProviderContainer boxWith(ChatClient client) {
      final box = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          timerServiceProvider.overrideWithValue(timer),
          chatClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(box.dispose);
      return box;
    }

    test('没配 key 时问一句什么都不改，也不发请求', () async {
      final client = _StubChat(const ChatReply('不该被问到'));
      final box = boxWith(client);
      final n = box.read(panelNotifierProvider.notifier);

      n.ask('今天做什么');
      await pumpEventQueue();

      expect(box.read(panelNotifierProvider).answers, isEmpty);
      expect(client.calls, 0);
    });

    test('配了 key：先出空气泡，回来把答案填上', () async {
      final client = _StubChat(const ChatReply('先写三级目录'));
      final box = boxWith(client);
      box.read(keyConfiguredProvider.notifier).set(true);
      final n = box.read(panelNotifierProvider.notifier);

      n.ask('怎么开始');
      // 等模型那几秒里气泡先立起来，界面不会毫无动静。
      expect(box.read(panelNotifierProvider).answers, hasLength(1));
      expect(box.read(panelNotifierProvider).answers.single.text, isEmpty);

      await pumpEventQueue();

      final answer = box.read(panelNotifierProvider).answers.single;
      expect(answer.question, '怎么开始');
      expect(answer.text, '先写三级目录');
      expect(client.user, '怎么开始');
    });

    test('请求失败把原因写进气泡，不装成正常回答', () async {
      final box = boxWith(_StubChat(const ChatError('连不上模型服务，检查网络后再试')));
      box.read(keyConfiguredProvider.notifier).set(true);
      final n = box.read(panelNotifierProvider.notifier);

      n.ask('怎么开始');
      await pumpEventQueue();

      expect(box.read(panelNotifierProvider).answers.single.text, contains('连不上'));
    });
  });
}

/// 按剧本回一句。
class _StubChat implements ChatClient {
  _StubChat(this.outcome);

  final ChatOutcome outcome;
  String? user;
  int calls = 0;

  @override
  Future<ChatOutcome> complete({
    required String system,
    required String user,
    List<AiAttachment> attachments = const <AiAttachment>[],
  }) async {
    calls++;
    this.user = user;
    return outcome;
  }
}
