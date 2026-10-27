import 'package:ai_pet_assistant/data/db/app_db.dart';
import 'package:ai_pet_assistant/data/repository/chat_repository.dart';
import 'package:ai_pet_assistant/data/repository/idea_repository.dart';
import 'package:ai_pet_assistant/data/repository/note_repository.dart';
import 'package:ai_pet_assistant/data/repository/project_repository.dart';
import 'package:ai_pet_assistant/data/repository/record_repository.dart';
import 'package:ai_pet_assistant/data/repository/settings_repository.dart';
import 'package:ai_pet_assistant/data/repository/task_repository.dart';
import 'package:ai_pet_assistant/domain/model/chat_message.dart';
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/domain/model/planned_step.dart';
import 'package:ai_pet_assistant/domain/model/settings.dart';
import 'package:ai_pet_assistant/domain/model/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// 七个 Repository 的单测，共用一个内存库，每个用例重开。
///
/// 这个文件**不 import drift**：建、改、删、查全走 Repository 的方法，
/// 拿到的都是 `domain/model/` 的实体——这就是分层边界的证据。
void main() {
  late AppDb db;

  setUp(() {
    db = AppDb.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('ProjectRepository', () {
    test('建项目、放步骤与进度史，能整包取回', () async {
      final repo = ProjectRepository(db);
      final projectId = await repo.create(name: '毕业论文', dueAt: 2000, nowMs: 1000);
      await repo.replaceSteps(projectId, ['读文献', '写结论']);
      await repo.addProgress(projectId: projectId, stepIndex: 0, content: '读完两篇', nowMs: 1000);

      final bundle = await repo.load(projectId);
      expect(bundle.exists, isTrue);
      expect(bundle.project!.name, '毕业论文');
      expect(bundle.project!.dueAt, 2000);
      // 新建即带「步骤 1」，所以当前步从不缺省为 -1。
      expect(bundle.project!.currentStep, 0);
      expect(bundle.steps.map((s) => s.name), ['读文献', '写结论']);
      expect(bundle.steps.map((s) => s.index), [0, 1]);
      expect(bundle.progress.single.content, '读完两篇');
      expect(bundle.indexOfStep(bundle.steps.last.id), 1);
      expect(bundle.indexOfStep(null), -1);
    });

    test('拆解放进空流程：替掉占位的步骤 1，每步带一条事项', () async {
      final repo = ProjectRepository(db);
      final projectId = await repo.create(name: '开题', dueAt: 0, nowMs: 1000);

      final written = await repo.applyPlan(
        projectId: projectId,
        steps: const [
          PlannedStep(name: '摸现状', task: '列出已有材料'),
          PlannedStep(name: '搭骨架', task: '写三级目录'),
        ],
        nowMs: 2000,
      );

      final bundle = await repo.load(projectId);
      expect(written, 2);
      // 新建项目带的「步骤 1」被替掉，不是排在它后面。
      expect(bundle.steps.map((s) => s.name), ['摸现状', '搭骨架']);
      expect(bundle.steps.map((s) => s.index), [0, 1]);
      expect(bundle.project!.currentStep, 0);

      final tasks = await TaskRepository(db).byProject(projectId);
      expect(tasks.map((t) => t.name), ['列出已有材料', '写三级目录']);
      expect(tasks.every((t) => t.stepId != null), isTrue);
    });

    test('已有内容的项目把拆解追加在末尾，不动现有步骤', () async {
      final repo = ProjectRepository(db);
      final projectId = await repo.create(name: '毕业论文', dueAt: 0, nowMs: 1000);
      await repo.replaceSteps(projectId, ['读文献', '写结论']);

      await repo.applyPlan(
        projectId: projectId,
        steps: const [PlannedStep(name: '补充实验', task: '跑一遍对照')],
        nowMs: 2000,
      );

      final bundle = await repo.load(projectId);
      expect(bundle.steps.map((s) => s.name), ['读文献', '写结论', '补充实验']);
      expect(bundle.steps.map((s) => s.index), [0, 1, 2]);
    });

    test('只有一步但已经有事项时算有内容，追加而不替换', () async {
      final repo = ProjectRepository(db);
      final projectId = await repo.create(name: '小项目', dueAt: 0, nowMs: 1000);
      final first = (await repo.load(projectId)).steps.single;
      await TaskRepository(db).createForProject(
        projectId: projectId,
        name: '已经动手了',
        stepId: first.id,
        nowMs: 1000,
      );

      await repo.applyPlan(
        projectId: projectId,
        steps: const [PlannedStep(name: '第二步', task: '接着做')],
        nowMs: 2000,
      );

      final bundle = await repo.load(projectId);
      expect(bundle.steps.map((s) => s.name), ['步骤 1', '第二步']);
    });

    test('只出步骤不出事项的拆解也能落，空拆解不动库', () async {
      final repo = ProjectRepository(db);
      final projectId = await repo.create(name: '空项目', dueAt: 0, nowMs: 1000);

      expect(
        await repo.applyPlan(projectId: projectId, steps: const [], nowMs: 2000),
        0,
      );
      expect((await repo.load(projectId)).steps, hasLength(1));

      await repo.applyPlan(
        projectId: projectId,
        steps: const [PlannedStep(name: '只来一步', task: '  ')],
        nowMs: 2000,
      );
      expect(
        await TaskRepository(db).byProject(projectId),
        isEmpty,
      );
    });

    test('项目不存在时返回空包，不抛错', () async {
      final repo = ProjectRepository(db);
      final bundle = await repo.load('nope');
      expect(bundle.exists, isFalse);
      expect(bundle.steps, isEmpty);
      expect(bundle.progress, isEmpty);
    });

    test('删项目把它下面的待办、流水、随手记、进度史一起清掉', () async {
      final projects = ProjectRepository(db);
      final tasks = TaskRepository(db);
      final notes = NoteRepository(db);
      final records = RecordRepository(db);

      final projectId = await projects.create(name: '配音', nowMs: 1000);
      final taskId = await tasks.createForProject(projectId: projectId, name: '练气口', nowMs: 1000);
      await tasks.logSession(taskId: taskId, startedAt: 1000, endedAt: 1600, seconds: 600);
      await notes.save(NoteOwner.task, taskId, '舌头别僵', 1000);
      await projects.addProgress(projectId: projectId, stepIndex: 0, content: '第一段过了', nowMs: 1000);

      await projects.delete(projectId);

      expect((await projects.load(projectId)).exists, isFalse);
      expect(await tasks.byProject(projectId), isEmpty);
      expect(await notes.textOf(NoteOwner.task, taskId), '');
      expect(await tasks.entriesForDay(0, 86400000), isEmpty);
      expect(await records.monthSecondsByProject('1970-01'), isEmpty);
    });

    test('改进度史留一条修订，原文进 revisions', () async {
      final repo = ProjectRepository(db);
      final projectId = await repo.create(name: '毕业论文', nowMs: 1000);
      await repo.addProgress(projectId: projectId, stepIndex: 1, content: '原样', nowMs: 1000);
      final entry = (await repo.load(projectId)).progress.single;

      await repo.reviseProgress(entry.id, '原样', '改过的', 2000);

      final after = (await repo.load(projectId)).progress.single;
      expect(after.content, '改过的');
      expect(after.revisionCount, 1);
      final revisions = await repo.revisionsOf('progressEntry', entry.id);
      expect(revisions.single.before, '原样');
      expect(revisions.single.after, '改过的');
    });
  });

  group('TaskRepository', () {
    test('独立事项与项目待办按 scope 分开', () async {
      final repo = TaskRepository(db);
      await repo.createSolo(name: '交电费', nowMs: 1000);
      await repo.createForProject(projectId: 'p1', name: '写结论', stepId: 's2', nowMs: 1000);

      final solo = await repo.solo();
      expect(solo, hasLength(1));
      expect(solo.single.name, '交电费');
      expect(solo.single.scope, TaskScope.solo);
      expect(solo.single.isSolo, isTrue);

      final inProject = await repo.byProject('p1');
      expect(inProject, hasLength(1));
      expect(inProject.single.name, '写结论');
      expect(inProject.single.stepId, 's2');
      expect(inProject.single.scope, TaskScope.project);
    });

    test('勾完成记下完成时间，取消勾选清掉', () async {
      final repo = TaskRepository(db);
      final id = await repo.createSolo(name: '交电费', nowMs: 1000);

      await repo.setDone(id, true, 5000);
      var task = (await repo.byId(id))!;
      expect(task.done, isTrue);
      expect(task.doneAt, 5000);

      await repo.setDone(id, false, 6000);
      task = (await repo.byId(id))!;
      expect(task.done, isFalse);
      expect(task.doneAt, isNull);
    });

    test('投入秒数逐次累加，流水按事项汇总', () async {
      final repo = TaskRepository(db);
      final id = await repo.createSolo(name: '写结论', nowMs: 1000);
      await repo.logSession(taskId: id, startedAt: 1000, endedAt: 4600, seconds: 3600);
      await repo.logSession(taskId: id, startedAt: 5000, endedAt: 5300, seconds: 300);

      await repo.accumulateSpent(id, 3900);
      expect((await repo.byId(id))!.spentSec, 3900);
      expect((await repo.byId(id))!.spent, const Duration(seconds: 3900));
      expect(await repo.totalSeconds(id), 3900);
    });

    test('一天的投入按事项聚合并按秒数降序', () async {
      final repo = TaskRepository(db);
      final slow = await repo.createSolo(name: '写结论', nowMs: 1000);
      final quick = await repo.createSolo(name: '交电费', nowMs: 1000);
      await repo.logSession(taskId: slow, startedAt: 1000, endedAt: 4600, seconds: 3600);
      await repo.logSession(taskId: quick, startedAt: 5000, endedAt: 5600, seconds: 600);

      final entries = await repo.entriesForDay(0, 86400000);
      expect(entries, hasLength(2));
      expect(entries.first.task.name, '写结论');
      expect(entries.first.seconds, 3600);
      expect(entries.last.seconds, 600);
    });

    test('事项删掉后那天的投入不再算它，也不抛错', () async {
      final repo = TaskRepository(db);
      final id = await repo.createSolo(name: '临时事', nowMs: 1000);
      await repo.logSession(taskId: id, startedAt: 1000, endedAt: 2000, seconds: 1000);

      await repo.delete(id);

      expect(await repo.byId(id), isNull);
      expect(await repo.entriesForDay(0, 86400000), isEmpty);
      expect(await repo.totalSeconds(id), 0);
    });

    test('一天里做完的事项按完成时间倒序', () async {
      final repo = TaskRepository(db);
      final early = await repo.createSolo(name: '早的', nowMs: 1000);
      final late = await repo.createSolo(name: '晚的', nowMs: 1000);
      await repo.setDone(early, true, 2000);
      await repo.setDone(late, true, 3000);

      final done = await repo.doneBetween(0, 86400000);
      expect(done.map((t) => t.name), ['晚的', '早的']);
    });

  });

  group('RecordRepository', () {
    test('用户改总结留一条修订，打上已改标记', () async {
      final repo = RecordRepository(db);
      await repo.setSummary('2026-10-23', 'AI 写的初版', 1000);

      await repo.reviseSummary('2026-10-23', '我自己改过', 2000);

      final after = (await repo.byDate('2026-10-23'))!;
      expect(after.summaryText, '我自己改过');
      expect(after.summaryEditedAt, 2000);
      expect(after.editedByUser, isTrue);

      final revisions = await repo.revisionsOf('2026-10-23');
      expect(revisions.single.before, 'AI 写的初版');
      expect(revisions.single.after, '我自己改过');
    });

    test('按月取日总结，只取这个月的', () async {
      final repo = RecordRepository(db);
      await repo.setSummary('2026-10-23', 'a', 1000);
      await repo.setSummary('2026-10-01', 'b', 1000);
      await repo.setSummary('2026-09-30', 'c', 1000);

      final october = await repo.month('2026-10');
      expect(october.map((r) => r.date), ['2026-10-23', '2026-10-01']);
    });

    test('一个月的投入按项目拆，独立事项归到 solo', () async {
      final repo = RecordRepository(db);
      final tasks = TaskRepository(db);
      final inProject = await tasks.createForProject(projectId: 'p1', name: '写结论', nowMs: 1000);
      final solo = await tasks.createSolo(name: '交电费', nowMs: 1000);
      // 2026-10-23 当地时间的零点
      final dayStart = DateTime(2026, 10, 23).millisecondsSinceEpoch;
      await tasks.logSession(
        taskId: inProject,
        startedAt: dayStart,
        endedAt: dayStart + 3600000,
        seconds: 3600,
      );
      await tasks.logSession(
        taskId: solo,
        startedAt: dayStart,
        endedAt: dayStart + 600000,
        seconds: 600,
      );

      final byProject = await repo.monthSecondsByProject('2026-10');
      expect(byProject['p1'], 3600);
      expect(byProject[RecordRepository.soloKey], 600);
    });
  });

  group('IdeaRepository', () {
    test('每条想法只归类一次，归类后不再出现在待归类里', () async {
      final repo = IdeaRepository(db);
      final categoryId = await repo.ensureCategory('产品灵感', 1000);
      final ideaId = await repo.add('想法盒只放没成形的念头', body: '成形的都进项目了', nowMs: 1000);

      expect((await repo.nextUnclassified())!.id, ideaId);

      await repo.markClassified(ideaId, categoryId, 2000);
      expect(await repo.nextUnclassified(), isNull);
      final row = (await repo.all()).single;
      expect(row.classifiedAt, 2000);
      expect(row.categoryId, categoryId);
      expect(row.needsClassification, isFalse);
    });

    test('想法可以搬到别的分类，搬动不再触发重新归类', () async {
      final repo = IdeaRepository(db);
      final first = await repo.ensureCategory('产品灵感', 1000);
      final second = await repo.ensureCategory('待验证', 1000);
      final ideaId = await repo.add('要不要单独拆一类', nowMs: 1000);
      await repo.markClassified(ideaId, first, 1000);

      await repo.moveToCategory(ideaId, second);

      final row = (await repo.byId(ideaId))!;
      expect(row.categoryId, second);
      expect(row.classifiedAt, 1000);
    });

    test('同名分类不重复建，配色按已有的往下轮', () async {
      final repo = IdeaRepository(db);
      final first = await repo.ensureCategory('产品灵感', 1000);
      final again = await repo.ensureCategory('  产品灵感  ', 2000);
      expect(again, first);

      await repo.ensureCategory('待验证', 1000);
      final categories = await repo.categories();
      expect(categories, hasLength(2));
      expect(categories.map((c) => c.color).toSet(), hasLength(2));
    });
  });

  group('NoteRepository', () {
    test('同一个 owner 只留一条，空文本等于删掉', () async {
      final repo = NoteRepository(db);
      await repo.save(NoteOwner.task, 't1', '顺手把页码标了', 1000);
      expect(await repo.textOf(NoteOwner.task, 't1'), '顺手把页码标了');

      await repo.save(NoteOwner.task, 't1', '改过的内容', 2000);
      expect(await repo.textOf(NoteOwner.task, 't1'), '改过的内容');

      await repo.save(NoteOwner.task, 't1', '   ', 3000);
      expect(await repo.textOf(NoteOwner.task, 't1'), '');
      expect(await repo.byOwner(NoteOwner.task, 't1'), isNull);
    });

    test('不同 owner 各存各的', () async {
      final repo = NoteRepository(db);
      await repo.save(NoteOwner.task, 't1', '事项上的', 1000);
      await repo.save(NoteOwner.history, 'h1', '进度史上的', 1000);
      expect(await repo.textOf(NoteOwner.task, 't1'), '事项上的');
      expect(await repo.textOf(NoteOwner.history, 'h1'), '进度史上的');
    });

  });

  group('ChatRepository', () {
    test('问过没有问过能查出来，线程按 owner 隔离', () async {
      final repo = ChatRepository(db);
      expect(await repo.hasAsked(ChatOwner.panel, 't1'), isFalse);

      await repo.ask(ChatOwner.panel, 't1', '这一步要多久', 1000);
      await repo.answer(ChatOwner.panel, 't1', '大概二十分钟', 2000);
      expect(await repo.hasAsked(ChatOwner.panel, 't1'), isTrue);

      await repo.ask(ChatOwner.panel, 't2', '另一条', 3000);
      final thread = await repo.thread(ChatOwner.panel, 't1');
      expect(thread.map((m) => m.role), [ChatRole.user, ChatRole.ai]);
      expect(thread.first.content, '这一步要多久');

      await repo.clearThread(ChatOwner.panel, 't1');
      expect(await repo.hasAsked(ChatOwner.panel, 't1'), isFalse);
      expect(await repo.hasAsked(ChatOwner.panel, 't2'), isTrue);
    });

    test('同一毫秒里一问一答不会撞主键', () async {
      final repo = ChatRepository(db);
      await repo.ask(ChatOwner.panel, 't1', '问', 1000);
      await repo.answer(ChatOwner.panel, 't1', '答', 1000);

      expect(await repo.thread(ChatOwner.panel, 't1'), hasLength(2));
    });
  });

  group('SettingsRepository', () {
    test('没有设置行时给一行的默认值', () async {
      final repo = SettingsRepository(db);
      final row = await repo.current();
      expect(row.keyConfigured, isFalse);
      expect(row.bubbleEnabled, isTrue);
      expect(row.side, PetSide.left);
      expect(row.anchorY, 0.5);
      expect(row.demoUrl, '');
      expect(row.repoUrl, '');
    });

    test('各项设置存得进读得出', () async {
      final repo = SettingsRepository(db);
      await repo.setKeyConfigured(true);
      await repo.setDemoUrl('https://example.com/demo.mp4');
      await repo.setRepoUrl('https://example.com/repo');
      await repo.setBubbleEnabled(false);
      await repo.setSide(PetSide.right);
      await repo.setAnchorY(0.75);

      final row = await repo.current();
      expect(row.keyConfigured, isTrue);
      expect(row.demoUrl, 'https://example.com/demo.mp4');
      expect(row.repoUrl, 'https://example.com/repo');
      expect(row.bubbleEnabled, isFalse);
      expect(row.side, PetSide.right);
      expect(row.anchorY, 0.75);
    });
  });
}
