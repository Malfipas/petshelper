import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart'
    hide Note, Project, ProgressEntry, Step, TaskItem;
import 'package:ai_pet_assistant/domain/model/project.dart';
import 'package:ai_pet_assistant/domain/model/project_bundle.dart';
import 'package:ai_pet_assistant/domain/model/step.dart';
import 'package:ai_pet_assistant/features/projects/projects_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// B14 的分段条与流程编辑。
///
/// 上半截压数据层：改一步、加一步、换位、删一步落到库里的真实样子；
/// 下半截压状态机：默认筛选、点段与清筛、编辑器开合、Esc 三层。
/// 界面尺寸与文案在 `projects_page_test.dart` 里量。
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

  Future<ProjectBundle> bundleOf(String id) => container.read(projectRepositoryProvider).load(id);

  /// 步骤表没有排序保证，测试里按 `index` 排好再比对。
  List<Step> byIndex(List<Step> steps) => [...steps]..sort((a, b) => a.index.compareTo(b.index));

  /// 建一个带步骤的项目，返回项目 id。
  Future<String> seedWithSteps(String name, List<String> steps) async {
    final id = await container.read(projectRepositoryProvider).create(name: name, nowMs: nowMs);
    await container.read(projectRepositoryProvider).replaceSteps(id, steps);
    return id;
  }

  Future<List<Step>> stepsOf(String id) async => byIndex((await bundleOf(id)).steps);

  group('数据层 · 改一步', () {
    test('改名只动名字；步骤已经不在了就当作没发生', () async {
      final id = await seedWithSteps('写论文', ['选题', '写正文']);
      final repo = container.read(projectRepositoryProvider);
      final first = (await stepsOf(id)).first;

      await repo.renameStep(first.id, '开题');

      expect((await stepsOf(id)).map((step) => step.name), ['开题', '写正文']);

      await repo.renameStep('s_missing', '不存在');
      expect((await stepsOf(id)).map((step) => step.name), ['开题', '写正文']);
    });
  });

  group('数据层 · 加一步', () {
    test('追加在末尾，编号取现有最大加一', () async {
      final id = await seedWithSteps('写论文', ['选题', '写正文', '修订']);
      final repo = container.read(projectRepositoryProvider);

      final added = await repo.addStep(id, name: '定稿');

      final after = await stepsOf(id);
      expect(after.map((step) => step.name), ['选题', '写正文', '修订', '定稿']);
      expect(after.map((step) => step.index), [0, 1, 2, 3]);
      expect(after.last.id, added);
      // 建项目那一步就把 currentStep 定在 0，加步骤不会把它打回 -1。
      expect((await bundleOf(id)).project!.currentStep, 0);
    });

    test('删过中间一步之后再追加，编号不与剩下的撞上', () async {
      final id = await seedWithSteps('写论文', ['一', '二', '三']);
      final repo = container.read(projectRepositoryProvider);
      final middle = (await stepsOf(id))[1];

      await repo.deleteStep(middle.id);
      await repo.addStep(id, name: '四');

      final after = await stepsOf(id);
      expect(after.map((step) => step.name), ['一', '三', '四']);
      expect(after.map((step) => step.index), [0, 1, 2]);
    });
  });

  group('数据层 · 上下换位', () {
    test('换编号、换待办归属、换进度史编号；到头返回 false', () async {
      final id = await seedWithSteps('写论文', ['一', '二', '三']);
      final repo = container.read(projectRepositoryProvider);
      final tasks = container.read(taskRepositoryProvider);
      final steps = await stepsOf(id);
      final first = steps[0];
      final second = steps[1];

      final onFirst = await tasks.createForProject(
        projectId: id,
        name: '第一步的事',
        stepId: first.id,
        nowMs: nowMs,
      );
      final onSecond = await tasks.createForProject(
        projectId: id,
        name: '第二步的事',
        stepId: second.id,
        nowMs: nowMs,
      );
      await repo.addProgress(projectId: id, stepIndex: 0, content: '记在第一步', nowMs: nowMs);
      await repo.addProgress(projectId: id, stepIndex: 1, content: '记在第二步', nowMs: nowMs);

      expect(await repo.moveStep(first.id, 1), isTrue);

      final after = await stepsOf(id);
      expect(after.map((step) => step.name), ['二', '一', '三']);
      expect(after.map((step) => step.index), [0, 1, 2]);
      // 换位后「第一步」这个位置上是原来第二步，两件事的归属跟着位置一起换。
      expect((await tasks.byId(onFirst))!.stepId, second.id);
      expect((await tasks.byId(onSecond))!.stepId, first.id);
      final progress = {
        for (final entry in (await bundleOf(id)).progress) entry.content: entry.stepIndex,
      };
      expect(progress, {'记在第一步': 1, '记在第二步': 0});

      // 已经在头尾：不写库，返回 false。
      expect(await repo.moveStep(second.id, -1), isFalse);
      expect(await repo.moveStep(after.last.id, 1), isFalse);
      expect(await repo.moveStep('s_missing', 1), isFalse);
      expect((await stepsOf(id)).map((step) => step.name), ['二', '一', '三']);
    });
  });

  group('数据层 · 删一步', () {
    test('待办转未分配，后面的编号与进度史各前移一位', () async {
      final id = await seedWithSteps('写论文', ['一', '二', '三']);
      final repo = container.read(projectRepositoryProvider);
      final tasks = container.read(taskRepositoryProvider);
      final steps = await stepsOf(id);
      final middle = steps[1];

      final task = await tasks.createForProject(
        projectId: id,
        name: '挂在第二步上',
        stepId: middle.id,
        nowMs: nowMs,
      );
      await repo.addProgress(projectId: id, stepIndex: 1, content: '在被删的那步', nowMs: nowMs);
      await repo.addProgress(projectId: id, stepIndex: 2, content: '在第三步', nowMs: nowMs);

      await repo.deleteStep(middle.id);

      final after = await stepsOf(id);
      expect(after.map((step) => step.name), ['一', '三']);
      expect(after.map((step) => step.index), [0, 1]);
      // 事项本身不删，只是退回未分配。
      expect((await tasks.byId(task))!.stepId, isNull);

      final progress = {
        for (final entry in (await bundleOf(id)).progress) entry.content: entry.stepIndex,
      };
      // 指向被删那一步的记录留在原编号，后面那步前移，于是两条都落在 1 上。
      expect(progress, {'在被删的那步': 1, '在第三步': 1});

      // 再删一次同一个 id：查不到行，什么都不发生。
      await repo.deleteStep(middle.id);
      expect((await stepsOf(id)).length, 2);
    });

    test('currentStep 三种收敛：删前面的减一、删当前的不动、越界收到末位', () async {
      final repo = container.read(projectRepositoryProvider);

      final before = await seedWithSteps('删前面', ['一', '二', '三']);
      await repo.setCurrentStep(before, 2);
      await repo.deleteStep((await stepsOf(before))[0].id);
      expect((await bundleOf(before)).project!.currentStep, 1);

      final itself = await seedWithSteps('删当前', ['一', '二', '三']);
      await repo.setCurrentStep(itself, 1);
      await repo.deleteStep((await stepsOf(itself))[1].id);
      expect((await bundleOf(itself)).project!.currentStep, 1);

      final tail = await seedWithSteps('删末尾', ['一', '二', '三']);
      await repo.setCurrentStep(tail, 2);
      await repo.deleteStep((await stepsOf(tail))[2].id);
      expect((await bundleOf(tail)).project!.currentStep, 1);
    });

    test('删光最后一步，currentStep 回到 -1', () async {
      final id = await seedWithSteps('就一步', ['唯一的一步']);
      final repo = container.read(projectRepositoryProvider);
      await repo.setCurrentStep(id, 0);

      await repo.deleteStep((await stepsOf(id)).single.id);

      final after = await bundleOf(id);
      expect(after.steps, isEmpty);
      expect(after.project!.currentStep, -1);
    });
  });

  group('状态机 · 默认筛选', () {
    test('filterFor：起步前给 0，越界收末位，没步骤不筛', () {
      Project project(int currentStep) =>
          Project(id: 'p1', name: '甲', currentStep: currentStep, createdAt: 0);

      expect(filterFor(project(-1), 3), 0);
      expect(filterFor(project(2), 3), 2);
      expect(filterFor(project(5), 3), 2);
      expect(filterFor(project(-1), 0), isNull);
      expect(filterFor(project(0), 0), isNull);
    });

    test('展开用 currentStep 当默认筛选；新建项目自带步骤 1，落在那一步', () async {
      final id = await seedWithSteps('甲', ['一', '二', '三']);
      await container.read(projectRepositoryProvider).setCurrentStep(id, 1);
      final fresh = await container
          .read(projectRepositoryProvider)
          .create(name: '刚建的', nowMs: nowMs);
      await notifier().reload();

      await notifier().open(id);
      expect(current().filterStep, 1);
      expect(current().detailSteps.map((step) => step.name), ['一', '二', '三']);

      // 使用者 2026-10-26：项目建好就带「步骤 1」，所以默认筛选落在 0 而不是 null。
      await notifier().open(fresh);
      expect(current().filterStep, 0);
      expect(current().detailSteps.map((step) => step.name), ['步骤 1']);
    });
  });

  group('状态机 · 点段与清筛', () {
    test('点一段筛那一段，再点同一段取消；点 × 也清掉', () async {
      final id = await seedWithSteps('甲', ['一', '二', '三']);
      await notifier().reload();
      await notifier().open(id);

      await notifier().tapSegment(2);
      expect(current().filterStep, 2);
      await notifier().tapSegment(2);
      expect(current().filterStep, isNull);

      await notifier().tapSegment(0);
      expect(current().filterStep, 0);
      await notifier().clearFilter();
      expect(current().filterStep, isNull);

      // 收起编辑器不动筛选。
      notifier().toggleFlowEdit();
      await notifier().tapSegment(1);
      notifier().toggleFlowEdit();
      expect(current().flowEditing, isFalse);
      expect(current().filterStep, 1);
    });
  });

  group('状态机 · 编辑器动作', () {
    test('改名去掉首尾空格；改成空白就当没改', () async {
      final id = await seedWithSteps('甲', ['一', '二']);
      await notifier().reload();
      await notifier().open(id);
      final first = current().detailSteps.first;

      await notifier().renameStep(first.id, '  开题  ');
      expect(current().detailSteps.first.name, '开题');
      expect((await stepsOf(id)).first.name, '开题');

      await notifier().renameStep(first.id, '   ');
      expect(current().detailSteps.first.name, '开题');
    });

    test('加一步排在末尾，默认名带追加后的步数，筛选不动', () async {
      final id = await seedWithSteps('甲', ['一', '二']);
      await notifier().reload();
      await notifier().open(id);
      await notifier().tapSegment(1);

      await notifier().addStep();

      final state = current();
      expect(state.detailSteps.map((step) => step.name), ['一', '二', '新步骤 3']);
      expect(state.detailTotalSteps, 3);
      expect(state.detailPercent, 0);
      expect(state.filterStep, 1);
    });

    test('换位成功清掉筛选；已经到头则原样不动', () async {
      final id = await seedWithSteps('甲', ['一', '二', '三']);
      await notifier().reload();
      await notifier().open(id);
      final steps = current().detailSteps;
      // 进详情默认筛第 1 段，这里改筛第 2 段，免得在默认段上再点一下变成取消。
      await notifier().tapSegment(1);

      await notifier().moveStep(steps.first.id, -1);
      expect(current().filterStep, 1);
      expect(current().detailSteps.map((step) => step.name), ['一', '二', '三']);

      await notifier().moveStep(steps.first.id, 1);
      expect(current().detailSteps.map((step) => step.name), ['二', '一', '三']);
      expect(current().filterStep, isNull);
    });

    test('删一步后步数减少、筛选落回 currentStep，卡片摘要也跟着重读', () async {
      final id = await seedWithSteps('甲', ['一', '二', '三']);
      await container.read(projectRepositoryProvider).setCurrentStep(id, 1);
      await notifier().reload();
      await notifier().open(id);
      expect(current().filterStep, 1);
      await notifier().tapSegment(2);
      notifier().toggleFlowEdit();

      await notifier().deleteStep(current().detailSteps.first.id);

      final state = current();
      expect(state.detailSteps.map((step) => step.name), ['二', '三']);
      expect(state.detailTotalSteps, 2);
      // FR-09：删完编辑器保持展开。
      expect(state.flowEditing, isTrue);
      // 删的是第 1 步之前的步，currentStep 由 1 收到 0，筛选跟着落过去。
      expect(state.filterStep, 0);
      expect(state.rows.single.name, '甲');
    });
  });

  group('状态机 · Esc 三层', () {
    test('先关删除弹窗，再收编辑器，再退列表，最后交回壳', () async {
      final id = await seedWithSteps('甲', ['一']);
      await notifier().reload();
      await notifier().open(id);
      notifier().toggleFlowEdit();
      notifier().askDelete();

      expect(notifier().collapse(), isTrue);
      expect(current().confirming, isFalse);
      expect(current().flowEditing, isTrue);

      expect(notifier().collapse(), isTrue);
      expect(current().flowEditing, isFalse);
      expect(current().openId, id);

      expect(notifier().collapse(), isTrue);
      expect(current().openId, isNull);

      expect(notifier().collapse(), isFalse);
    });
  });
}
