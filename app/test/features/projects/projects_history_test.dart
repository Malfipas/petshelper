import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart'
    hide Note, ProgressEntry, Project, Revision, Step, TaskItem;
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/domain/model/progress_entry.dart';
import 'package:ai_pet_assistant/features/projects/projects_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// B16 的进度史与时间轴。
///
/// 上半截压纯函数：串行顺序、时间戳五档、天标题；下半截压状态机：进详情读回、
/// 改正文留痕、随手记、视图切换、Esc 层级与退回列表的复位。
/// 尺寸与两种排法的渲染在 `projects_page_test.dart` 里量，这里不重复。
void main() {
  late AppDb db;
  late ProviderContainer container;
  final base = DateTime(2026, 10, 24, 9);
  late int nowMs;

  setUp(() {
    db = AppDb.memory();
    nowMs = base.millisecondsSinceEpoch;
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        projectListProvider.overrideWith(
          () => ProjectListNotifier(now: () => DateTime.fromMillisecondsSinceEpoch(nowMs)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProjectListNotifier notifier() => container.read(projectListProvider.notifier);
  ProjectListState current() => container.read(projectListProvider);

  /// 建一个可能带步骤的项目，返回 id。
  Future<String> seed(String name, [List<String> steps = const []]) async {
    final repo = container.read(projectRepositoryProvider);
    final id = await repo.create(name: name, nowMs: nowMs);
    if (steps.isNotEmpty) await repo.replaceSteps(id, steps);
    return id;
  }

  /// 直接落一条进度史，绕过「完成待办」那一路。
  Future<String> addProgress(String projectId, int stepIndex, String content, int at) => container
      .read(projectRepositoryProvider)
      .addProgress(projectId: projectId, stepIndex: stepIndex, content: content, nowMs: at);

  /// 造一条只有排序用得上的进度史。
  ProgressEntry row(String id, int stepIndex, int at, {String content = '进展'}) =>
      ProgressEntry(id: id, projectId: 'p1', stepIndex: stepIndex, content: content, at: at);

  group('排序 · 先步骤再时间', () {
    test('乱序三条按步骤号收拢，步骤被删残留的旧下标照数值排', () {
      final at = nowMs;
      final sorted = sortProgress([
        row('h3', 3, at - 3000),
        row('h2', 1, at - 1000),
        row('h1', 0, at - 2000),
      ]);

      expect(sorted.map((it) => it.id), ['h1', 'h2', 'h3']);
    });

    test('同一步里按时间升序，时间相同再按 id 兜底', () {
      final sorted = sortProgress([
        row('h-b', 0, nowMs),
        row('h-a', 0, nowMs),
        row('h-late', 0, nowMs + 5000),
      ]);

      expect(sorted.map((it) => it.id), ['h-a', 'h-b', 'h-late']);
    });

    test('不按时间倒序：第 1 步的旧进展不会被压到第 4 步之后', () {
      final sorted = sortProgress([row('h-new', 3, nowMs), row('h-old', 0, nowMs - 86400000 * 3)]);

      expect(sorted.first.id, 'h-old');
    });
  });

  group('时间戳 · 五档文案', () {
    test('一分钟内写「刚刚」', () {
      expect(historyWhen(nowMs - 30000, nowMs), '刚刚');
    });

    test('当天超过一分钟写「今天 HH:mm」，时分补零', () {
      final at = DateTime(2026, 10, 24, 8, 5).millisecondsSinceEpoch;
      expect(historyWhen(at, nowMs), '今天 08:05');
    });

    test('跨午夜只差两分钟也算「昨天」，不被毫秒整除吞掉', () {
      final at = DateTime(2026, 10, 23, 23, 59).millisecondsSinceEpoch;
      final justAfter = DateTime(2026, 10, 24, 0, 1).millisecondsSinceEpoch;
      expect(historyWhen(at, justAfter), '昨天 23:59');
    });

    test('两到六天写「N 天前 HH:mm」', () {
      final at = DateTime(2026, 10, 21, 21, 40).millisecondsSinceEpoch;
      expect(historyWhen(at, nowMs), '3 天前 21:40');
    });

    test('满七天改用「M 月 D 日 HH:mm」', () {
      final at = DateTime(2026, 10, 17, 9, 5).millisecondsSinceEpoch;
      expect(historyWhen(at, nowMs), '10 月 17 日 09:05');
    });

    test('天标题就是同一档文案去掉时刻', () {
      final at = DateTime(2026, 10, 17, 9, 5).millisecondsSinceEpoch;
      final today = DateTime(2026, 10, 24, 8, 5).millisecondsSinceEpoch;

      expect(historyDay(at, nowMs), '10 月 17 日');
      expect(historyDay(today, nowMs), '今天');
      expect(historyDay(nowMs - 20000, nowMs), '刚刚');
    });
  });

  group('读回 · 进详情', () {
    test('按流程顺序读回进度史，顺手带的随手记一起回来', () async {
      final id = await seed('论文');
      final second = await addProgress(id, 1, '第二步的进展', nowMs - 1000);
      await addProgress(id, 0, '第一步的进展', nowMs - 2000);
      await container
          .read(noteRepositoryProvider)
          .save(NoteOwner.history, second, '  这一步卡在数据  ', nowMs);

      await notifier().open(id);

      expect(current().detailProgress.map((it) => it.content), ['第一步的进展', '第二步的进展']);
      expect(current().historyNotes[second], '这一步卡在数据');
    });

    test('textsOf 一次读回本类全部，空正文与别类的不进来', () async {
      final id = await seed('论文');
      final first = await addProgress(id, 0, '一', nowMs);
      final second = await addProgress(id, 1, '二', nowMs);
      final notes = container.read(noteRepositoryProvider);
      await notes.save(NoteOwner.history, first, '有字', nowMs);
      await notes.save(NoteOwner.history, second, '   ', nowMs);
      await notes.save(NoteOwner.task, 't1', '事项上的', nowMs);

      final map = await notes.textsOf(NoteOwner.history);

      expect(map, {first: '有字'});
    });

    test('完成一件事后，那一行进得了进度史', () async {
      final id = await seed('论文', ['选题']);
      final steps = (await container.read(projectRepositoryProvider).load(id)).steps;
      final taskId = await container
          .read(taskRepositoryProvider)
          .addToStep(projectId: id, stepId: steps.first.id, name: '定题目', nowMs: nowMs);

      await container.read(finishTaskProvider).call(taskId: taskId, nowMs: nowMs);
      await notifier().open(id);

      expect(current().detailProgress.single.content, '完成「定题目」');
      expect(current().detailProgress.single.stepIndex, 0);
    });
  });

  group('改正文 · 留痕与计数', () {
    test('改成新文本：正文更新、计数加一、修订链留一条', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);

      notifier().beginEditEntry(entryId);
      expect(current().editingEntryId, entryId);

      final ok = await notifier().saveEntry(entryId, '  选题定了·改  ');

      expect(ok, isTrue);
      expect(current().editingEntryId, isNull);
      final after = current().detailProgress.single;
      expect(after.content, '选题定了·改');
      expect(after.revisionCount, 1);

      final revs = await container
          .read(projectRepositoryProvider)
          .revisionsOf('progressEntry', entryId);
      expect(revs.single.before, '选题定了');
      expect(revs.single.after, '选题定了·改');
    });

    test('空白提交只退编辑态，不写留痕也不改正文', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);
      notifier().beginEditEntry(entryId);

      final ok = await notifier().saveEntry(entryId, '   ');

      expect(ok, isFalse);
      expect(current().editingEntryId, isNull);
      expect(current().detailProgress.single.content, '选题定了');
      expect(current().detailProgress.single.revisionCount, 0);
    });

    test('没改就退编辑态，不产生一条「原文→原文」的空留痕', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);
      notifier().beginEditEntry(entryId);

      final ok = await notifier().saveEntry(entryId, '选题定了');

      expect(ok, isFalse);
      expect(current().detailProgress.single.revisionCount, 0);
      expect(
        await container.read(projectRepositoryProvider).revisionsOf('progressEntry', entryId),
        isEmpty,
      );
    });

    test('修订链展开着保存，链还开着且多出这一条', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);
      await notifier().toggleRevisions(entryId);
      expect(current().revisions[entryId], isEmpty);

      await notifier().saveEntry(entryId, '选题定了·改');

      expect(current().openRevisions, contains(entryId));
      expect(current().revisions[entryId]!.single.after, '选题定了·改');
    });

    test('收起再展开走缓存，内容不丢也不空', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);
      await container
          .read(projectRepositoryProvider)
          .reviseProgress(entryId, '选题定了', '改过一版', nowMs);

      await notifier().toggleRevisions(entryId);
      expect(current().revisions[entryId], hasLength(1));
      await notifier().toggleRevisions(entryId);
      expect(current().openRevisions, isNot(contains(entryId)));
      expect(current().revisions[entryId], hasLength(1));
    });
  });

  group('随手记 · 进度史这一列', () {
    test('写入进 historyNotes；空白等于清掉', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);

      notifier().beginHistoryNote(entryId);
      await notifier().saveHistoryNote(entryId, '  导师说要收窄  ');

      expect(current().historyNoteEditingId, isNull);
      expect(current().historyNotes[entryId], '导师说要收窄');

      notifier().beginHistoryNote(entryId);
      await notifier().saveHistoryNote(entryId, '   ');

      expect(current().historyNotes.containsKey(entryId), isFalse);
      expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.history, entryId), '');
    });

    test('正文编辑与随手记编辑互斥，一次只开一处', () async {
      final id = await seed('论文');
      await notifier().open(id);

      notifier().beginEditEntry('h1');
      notifier().beginHistoryNote('h2');

      expect(current().editingEntryId, isNull);
      expect(current().historyNoteEditingId, 'h2');

      notifier().beginEditEntry('h3');
      expect(current().editingEntryId, 'h3');
      expect(current().historyNoteEditingId, isNull);
    });
  });

  group('视图与 Esc', () {
    test('切时间轴只改排法，编辑态与数据都不动', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);
      notifier().beginEditEntry(entryId);

      notifier().toggleHistoryAxis();

      expect(current().historyTimeline, isTrue);
      expect(current().editingEntryId, entryId);
      expect(current().detailProgress, hasLength(1));

      notifier().toggleHistoryAxis();
      expect(current().historyTimeline, isFalse);
    });

    test('Esc 逐层收：正文编辑 → 随手记 → 行内新增 → 详情', () async {
      final id = await seed('论文', ['选题']);
      final stepId = (await container.read(projectRepositoryProvider).load(id)).steps.first.id;
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await notifier().open(id);

      notifier().beginEditEntry(entryId);
      expect(notifier().collapse(), isTrue);
      expect(current().editingEntryId, isNull);

      notifier().beginHistoryNote(entryId);
      expect(notifier().collapse(), isTrue);
      expect(current().historyNoteEditingId, isNull);

      notifier().openAddTask(stepId);
      expect(notifier().collapse(), isTrue);
      expect(current().addTaskFor, isNull);

      expect(notifier().collapse(), isTrue);
      expect(current().openId, isNull);
      expect(notifier().collapse(), isFalse);
    });

    test('退回列表时进度史那七个字段一起复位', () async {
      final id = await seed('论文');
      final entryId = await addProgress(id, 0, '选题定了', nowMs);
      await container.read(noteRepositoryProvider).save(NoteOwner.history, entryId, '有字', nowMs);
      await notifier().open(id);
      notifier().toggleHistoryAxis();
      notifier().beginEditEntry(entryId);
      await notifier().toggleRevisions(entryId);

      notifier().back();

      expect(current().openId, isNull);
      expect(current().detailProgress, isEmpty);
      expect(current().historyTimeline, isFalse);
      expect(current().editingEntryId, isNull);
      expect(current().historyNoteEditingId, isNull);
      expect(current().openRevisions, isEmpty);
      expect(current().revisions, isEmpty);
      expect(current().historyNotes, isEmpty);
    });
  });
}
