import 'dart:async';

import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Note, TaskItem;
import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/model/planned_step.dart';
import 'package:ai_pet_assistant/domain/model/project_plan.dart';
import 'package:ai_pet_assistant/domain/port/attachment_picker.dart';
import 'package:ai_pet_assistant/domain/port/project_planner.dart';
import 'package:ai_pet_assistant/features/projects/project_ai_state.dart';
import 'package:ai_pet_assistant/features/projects/projects_notifier.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;
  late ProviderContainer container;
  final base = DateTime(2026, 10, 24, 9);
  late int nowMs;

  setUp(() {
    db = AppDb.memory();
    nowMs = base.millisecondsSinceEpoch;
    container = ProviderContainer(overrides: [appDbProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProjectListNotifier notifier() => container.read(projectListProvider.notifier);
  ProjectListState current() => container.read(projectListProvider);

  Future<ProjectListState> reloaded() async {
    await notifier().reload();
    return current();
  }

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

  group('纯函数', () {
    test('relativeSince 按天分七档', () {
      final now = DateTime(2026, 10, 24, 9);
      int at(DateTime time) => time.millisecondsSinceEpoch;

      expect(relativeSince(at(DateTime(2026, 10, 24, 8)), now), '今天');
      expect(relativeSince(at(DateTime(2026, 10, 23, 23)), now), '昨天');
      expect(relativeSince(at(DateTime(2026, 10, 21)), now), '3 天前');
      expect(relativeSince(at(DateTime(2026, 10, 16)), now), '一周前');
      expect(relativeSince(at(DateTime(2026, 10, 10)), now), '2 周前');
      expect(relativeSince(at(DateTime(2026, 9, 20)), now), '一个月前');
      expect(relativeSince(at(DateTime(2026, 7, 20)), now), '3 个月前');
      expect(relativeSince(null, now), '今天');
    });

    test('percentOf 四舍五入，没步骤算 0', () {
      expect(percentOf(2, 3), 67);
      expect(percentOf(1, 3), 33);
      expect(percentOf(3, 3), 100);
      expect(percentOf(0, 3), 0);
      expect(percentOf(0, 0), 0);
      expect(percentOf(5, 0), 0);
    });

    test('dueLabel 去前导零，空值给空串', () {
      expect(dueLabel(DateTime(2026, 10, 30).millisecondsSinceEpoch), '截止 10 月 30 日');
      expect(dueLabel(DateTime(2026, 1, 5).millisecondsSinceEpoch), '截止 1 月 5 日');
      expect(dueLabel(null), '');
    });
  });

  group('行数据', () {
    test('按创建倒序，百分比按已完成步数，下一步取最早未完成待办', () async {
      final older = await seedProject(
        '旧项目',
        createdAt: base.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      );
      await seedProject('新项目');
      await container.read(projectRepositoryProvider).replaceSteps(older, ['一', '二', '三']);
      await markStepsDone(older, 2);

      final tasks = container.read(taskRepositoryProvider);
      final first = await tasks.createForProject(projectId: older, name: '先做的', nowMs: nowMs);
      await tasks.createForProject(projectId: older, name: '后做的', nowMs: nowMs);
      await tasks.setDone(first, true, nowMs);

      final state = await reloaded();
      expect(state.rows.map((row) => row.name), ['新项目', '旧项目']);
      expect(state.rows.last.percent, 67);
      expect(state.rows.last.nextStep, '后做的');
      expect(state.rows.first.nextStep, '');
      expect(state.rows.first.percent, 0);
    });

    test('没有待办的项目下一步留空，进度也留零', () async {
      await seedProject('空的');
      final state = await reloaded();
      expect(state.rows.single.nextStep, '');
      expect(state.rows.single.percent, 0);
    });
  });

  group('新建', () {
    test('空名与重名都被挡住，建成后在最前并直接展开', () async {
      await seedProject('已有');
      await reloaded();

      notifier().toggleForm(true);
      notifier().setName('   ');
      expect(current().canSubmit, isFalse);
      expect(await notifier().create(), isFalse);

      notifier().setName('已有');
      expect(current().nameTaken, isTrue);
      expect(current().canSubmit, isFalse);
      expect(await notifier().create(), isFalse);

      notifier().setName('新写的');
      notifier().setDescription('一句说明');
      expect(current().canSubmit, isTrue);
      expect(await notifier().create(), isTrue);

      final state = current();
      expect(state.rows.first.name, '新写的');
      expect(state.openId, state.rows.first.id);
      expect(state.detail?.description, '一句说明');
      expect(state.formOpen, isFalse);
      expect(state.name, isEmpty);
    });

    test('取消新建会清掉草稿且不落库', () async {
      await reloaded();
      notifier().toggleForm(true);
      notifier().setName('写了一半');
      notifier().toggleForm(false);

      final state = current();
      expect(state.formOpen, isFalse);
      expect(state.name, isEmpty);
      expect(state.nameTaken, isFalse);
      expect(state.rows, isEmpty);
    });
  });

  group('展开与删除', () {
    test('展开进详情，返回回列表，Esc 先关弹窗再退列表', () async {
      final id = await seedProject('甲');
      await reloaded();

      await notifier().open(id);
      expect(current().openId, id);
      expect(current().detail?.name, '甲');

      notifier().askDelete();
      expect(notifier().collapse(), isTrue);
      expect(current().confirming, isFalse);
      expect(current().openId, id);

      expect(notifier().collapse(), isTrue);
      expect(current().openId, isNull);

      expect(notifier().collapse(), isFalse);
    });

    test('项目已经不在了就静静回列表，不留任何提示', () async {
      await reloaded();
      await notifier().open('p_missing');

      // 使用者 2026-10-26：项目页任何时候都不出现「这个项目已经删掉了」。
      final state = current();
      expect(state.openId, isNull);
      expect(state.flash, isEmpty);
    });

    test('确认删除后项目与它的待办一起没了', () async {
      final id = await seedProject('要删的');
      await container
          .read(taskRepositoryProvider)
          .createForProject(projectId: id, name: '里面的待办', nowMs: nowMs);
      await reloaded();
      await notifier().open(id);

      notifier().askDelete();
      await notifier().confirmDelete();

      final state = current();
      expect(state.rows, isEmpty);
      expect(state.openId, isNull);
      expect(state.detail, isNull);
      expect(await container.read(taskRepositoryProvider).byProject(id), isEmpty);
    });

  group('新建项目自带步骤 1', () {
    test('建完展开，流程条上就有「步骤 1」，当前步停在 0', () async {
      await reloaded();
      notifier().toggleForm(true);
      notifier().setName('毕业论文');
      await notifier().create();

      final opened = current().openId!;
      final state = current();
      expect(state.detailSteps.map((step) => step.name), ['步骤 1']);
      expect(state.filterStep, 0);
      expect(opened, isNotEmpty);
    });
  });

  group('AI 帮助', () {
    /// 每条件单独开一个容器，才能把拆解端口与选文件换成剧本。
    ProviderContainer boxWith(ProjectPlanner planner, {AttachmentPicker? picker}) {
      final box = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          projectPlannerProvider.overrideWithValue(planner),
          if (picker != null) attachmentPickerProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(box.dispose);
      return box;
    }

    test('展开收起，收起不清掉已经写了一半的目标', () async {
      final id = await seedProject('开题');
      final box = boxWith(_StubPlanner(const PlanNotConfigured()));
      final n = box.read(projectListProvider.notifier);
      await n.open(id);

      n.toggleAiHelp();
      n.setAiGoal('两周写完开题');
      expect(box.read(projectListProvider).aiHelp.open, isTrue);

      n.toggleAiHelp();
      expect(box.read(projectListProvider).aiHelp.open, isFalse);
      expect(box.read(projectListProvider).aiHelp.goal, '两周写完开题');
    });

    test('目标空着点拆，卡片里给一句话，一次请求都不发', () async {
      final id = await seedProject('开题');
      final planner = _StubPlanner(const PlanNotConfigured());
      final box = boxWith(planner);
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();

      await n.askAi();

      final help = box.read(projectListProvider).aiHelp;
      expect(help.phase, AiPlanPhase.failed);
      expect(help.error, contains('先写一句'));
      expect(planner.calls, 0);
    });

    test('拆成了就把回话与步骤摆出来，等着确认', () async {
      final id = await seedProject('开题');
      final box = boxWith(
        _StubPlanner(
          const PlanReady(
            ProjectPlan(
              reply: '先摸现状',
              steps: [
                PlannedStep(name: '摸现状', task: '列出已有材料'),
                PlannedStep(name: '搭骨架', task: '写三级目录'),
              ],
            ),
          ),
        ),
      );
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      n.setAiGoal('两周写完');

      await n.askAi();

      final help = box.read(projectListProvider).aiHelp;
      expect(help.phase, AiPlanPhase.ready);
      expect(help.reply, '先摸现状');
      expect(help.steps.map((s) => s.name), ['摸现状', '搭骨架']);
      expect(help.canApply, isTrue);
      // 还没点确认，库里不该有变化。
      expect((await box.read(projectRepositoryProvider).load(id)).steps, hasLength(1));
    });

    test('没配 key 时指向设置页，不说是网络问题', () async {
      final id = await seedProject('开题');
      final box = boxWith(_StubPlanner(const PlanNotConfigured()));
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      n.setAiGoal('两周写完');

      await n.askAi();

      final help = box.read(projectListProvider).aiHelp;
      expect(help.phase, AiPlanPhase.failed);
      expect(help.error, contains('设置页'));
    });

    test('请求失败的原因原样显示', () async {
      final id = await seedProject('开题');
      final box = boxWith(_StubPlanner(const PlanFailed('等太久了，请再试一次')));
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      n.setAiGoal('两周写完');

      await n.askAi();

      expect(box.read(projectListProvider).aiHelp.error, '等太久了，请再试一次');
    });

    test('正在拆的时候再点一次不会发第二个请求', () async {
      final id = await seedProject('开题');
      final planner = _PendingPlanner();
      final box = boxWith(planner);
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      n.setAiGoal('两周写完');

      final first = n.askAi();
      await Future<void>.delayed(Duration.zero);
      expect(box.read(projectListProvider).aiHelp.busy, isTrue);
      await n.askAi();
      expect(planner.calls, 1);

      planner.finish(
        const PlanReady(
          ProjectPlan(reply: '好', steps: [PlannedStep(name: '一步', task: '做事')]),
        ),
      );
      await first;
    });

    test('应用到项目后步骤落库，再点一次不会写第二份', () async {
      final id = await seedProject('开题');
      final box = boxWith(
        _StubPlanner(
          const PlanReady(
            ProjectPlan(
              reply: '先摸现状',
              steps: [PlannedStep(name: '摸现状', task: '列出已有材料')],
            ),
          ),
        ),
      );
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      n.setAiGoal('两周写完');
      await n.askAi();

      await n.applyAi();

      final state = box.read(projectListProvider);
      expect(state.aiHelp.applied, isTrue);
      expect(state.aiHelp.canApply, isFalse);
      expect(state.flash, contains('1 个步骤'));
      expect(state.detailSteps.map((s) => s.name), ['摸现状']);
      final tasks = await box.read(taskRepositoryProvider).byProject(id);
      expect(tasks.map((t) => t.name), ['列出已有材料']);

      await n.applyAi();
      expect((await box.read(projectRepositoryProvider).load(id)).steps, hasLength(1));
    });

    test('挑回来的图片与文件摆进卡片，挑的时候告诉端口还能放几个', () async {
      final id = await seedProject('开题');
      final picker = _StubPicker(
        AttachmentPicked(<AiAttachment>[
          AiAttachment.image(name: '草图.png', mimeType: 'image/png', base64: 'AAAA'),
          AiAttachment.file(name: '材料.md', content: '# 已有'),
        ]),
      );
      final box = boxWith(_StubPlanner(const PlanNotConfigured()), picker: picker);
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();

      await n.pickAiAttachments();

      final help = box.read(projectListProvider).aiHelp;
      expect(help.attachments.map((a) => a.name), ['草图.png', '材料.md']);
      expect(help.remainingSlots, 3);
      expect(picker.remaining, AiAttachment.maxCount);
    });

    test('挑文件被跳过时给一行灰提示，已经选上的不动', () async {
      final id = await seedProject('开题');
      final picker = _StubPicker(
        const AttachmentPickFailed('大图.png 超过 4MB，压一下再试'),
      );
      final box = boxWith(_StubPlanner(const PlanNotConfigured()), picker: picker);
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();

      await n.pickAiAttachments();

      final help = box.read(projectListProvider).aiHelp;
      expect(help.hint, contains('4MB'));
      expect(help.attachments, isEmpty);
      // 挑文件失败不该把卡片推进「拆失败」那一态。
      expect(help.phase, AiPlanPhase.idle);
    });

    test('只带附件也能发，附件一起交给端口', () async {
      final id = await seedProject('开题');
      final planner = _StubPlanner(
        const PlanReady(
          ProjectPlan(reply: '看着图来', steps: [PlannedStep(name: '照着图做', task: '先画线稿')]),
        ),
      );
      final picker = _StubPicker(
        AttachmentPicked(<AiAttachment>[
          AiAttachment.image(name: '草图.png', mimeType: 'image/png', base64: 'AAAA'),
        ]),
      );
      final box = boxWith(planner, picker: picker);
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      await n.pickAiAttachments();

      await n.askAi();

      expect(planner.calls, 1);
      expect(planner.goal, isEmpty);
      expect(planner.attachments.single.name, '草图.png');
      expect(box.read(projectListProvider).aiHelp.phase, AiPlanPhase.ready);
    });

    test('点叉把某个附件移掉', () async {
      final id = await seedProject('开题');
      final picker = _StubPicker(
        AttachmentPicked(<AiAttachment>[
          AiAttachment.file(name: '材料.md', content: 'x'),
        ]),
      );
      final box = boxWith(_StubPlanner(const PlanNotConfigured()), picker: picker);
      final n = box.read(projectListProvider.notifier);
      await n.open(id);
      n.toggleAiHelp();
      await n.pickAiAttachments();

      n.removeAiAttachment('材料.md');

      expect(box.read(projectListProvider).aiHelp.attachments, isEmpty);
    });
  });
  });
}

/// 按剧本回一句，并记下问了几次、带了什么。
class _StubPlanner implements ProjectPlanner {
  _StubPlanner(this.outcome);

  final PlanOutcome outcome;
  int calls = 0;
  String goal = '';
  List<AiAttachment> attachments = const <AiAttachment>[];

  @override
  Future<PlanOutcome> plan({
    required String projectName,
    required String goal,
    List<AiAttachment> attachments = const <AiAttachment>[],
  }) async {
    calls++;
    this.goal = goal;
    this.attachments = attachments;
    return outcome;
  }
}

/// 卡住不回，用来测「正在拆」时重复点击只发一次。
class _PendingPlanner implements ProjectPlanner {
  final Completer<PlanOutcome> _completer = Completer<PlanOutcome>();
  int calls = 0;

  @override
  Future<PlanOutcome> plan({
    required String projectName,
    required String goal,
    List<AiAttachment> attachments = const <AiAttachment>[],
  }) {
    calls++;
    return _completer.future;
  }

  void finish(PlanOutcome outcome) => _completer.complete(outcome);
}

/// 假的选择器：按剧本交回几个附件，并记下叫它时还剩几个空位。
class _StubPicker implements AttachmentPicker {
  _StubPicker(this.outcome);

  final AttachmentPickOutcome outcome;
  int? remaining;

  @override
  Future<AttachmentPickOutcome> pick({required int remaining}) async {
    this.remaining = remaining;
    return outcome;
  }
}
