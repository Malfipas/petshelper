import 'package:ai_pet_assistant/domain/model/chat_message.dart';
import 'package:ai_pet_assistant/domain/model/daily_record.dart';
import 'package:ai_pet_assistant/domain/model/day_digest.dart';
import 'package:ai_pet_assistant/domain/model/idea.dart';
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/domain/model/project.dart';
import 'package:ai_pet_assistant/domain/model/project_bundle.dart';
import 'package:ai_pet_assistant/domain/model/step.dart';
import 'package:ai_pet_assistant/domain/model/task_day_entry.dart';
import 'package:ai_pet_assistant/domain/model/task_item.dart';
import 'package:ai_pet_assistant/domain/port/chat_gateway.dart';
import 'package:ai_pet_assistant/domain/port/day_summarizer.dart';
import 'package:ai_pet_assistant/domain/port/idea_classifier.dart';
import 'package:ai_pet_assistant/domain/port/idea_gateway.dart';
import 'package:ai_pet_assistant/domain/port/note_gateway.dart';
import 'package:ai_pet_assistant/domain/port/project_gateway.dart';
import 'package:ai_pet_assistant/domain/port/record_gateway.dart';
import 'package:ai_pet_assistant/domain/port/task_gateway.dart';
import 'package:ai_pet_assistant/domain/usecase/classify_idea.dart';
import 'package:ai_pet_assistant/domain/usecase/finish_task.dart';
import 'package:ai_pet_assistant/domain/usecase/start_task.dart';
import 'package:ai_pet_assistant/domain/usecase/stop_task.dart';
import 'package:ai_pet_assistant/domain/usecase/summarize_day.dart';
import 'package:flutter_test/flutter_test.dart';

/// 六个用例的单测。端口全部用假实现，不碰数据库、不碰 Flutter。
void main() {
  group('StartTask', () {
    test('能开始，回开始时的那一毫秒', () async {
      final outcome = await StartTask(_FakeTasks([_solo('t1', name: '写开题')]))(
        taskId: 't1',
        nowMs: 1000,
      );

      expect(outcome, isA<StartTaskStarted>());
      final started = outcome as StartTaskStarted;
      expect(started.task.name, '写开题');
      expect(started.startedAt, 1000);
    });

    test('事项不在库里给 NotFound', () async {
      final outcome = await StartTask(_FakeTasks())(taskId: 't9', nowMs: 1);
      expect(outcome, isA<StartTaskNotFound>());
    });

    test('已完成的事项不再开始', () async {
      final outcome = await StartTask(_FakeTasks([_solo('t1', done: true)]))(
        taskId: 't1',
        nowMs: 1,
      );
      expect(outcome, isA<StartTaskAlreadyDone>());
    });

    test('另一条正在跑时给 Busy，并说清是谁在跑', () async {
      final tasks = _FakeTasks([_solo('t1'), _solo('t2')]);

      final outcome = await StartTask(tasks)(taskId: 't2', runningTaskId: 't1', nowMs: 1);

      expect(outcome, isA<StartTaskBusy>());
      expect((outcome as StartTaskBusy).runningTaskId, 't1');
    });
  });

  group('StopTask', () {
    test('正常停止：写一条流水并把秒数累加到事项上', () async {
      final tasks = _FakeTasks([_solo('t1')]);

      final outcome = await StopTask(tasks)(taskId: 't1', startedAt: 1000, endedAt: 6000);

      expect(outcome, isA<StopTaskStopped>());
      final stopped = outcome as StopTaskStopped;
      expect(stopped.seconds, 5);
      expect(stopped.logId, isNotEmpty);
      expect(tasks.logs.single.seconds, 5);
      expect(tasks.items['t1']!.spentSec, 5);
    });

    test('不足一秒不写流水，也不加秒数', () async {
      final tasks = _FakeTasks([_solo('t1')]);

      final outcome = await StopTask(tasks)(taskId: 't1', startedAt: 1000, endedAt: 1800);

      expect(outcome, isA<StopTaskTooShort>());
      expect(tasks.logs, isEmpty);
      expect(tasks.items['t1']!.spentSec, 0);
    });

    test('秒数向下取整，零头不算进账', () async {
      final outcome = await StopTask(_FakeTasks([_solo('t1')]))(
        taskId: 't1',
        startedAt: 0,
        endedAt: 2500,
      );
      expect((outcome as StopTaskStopped).seconds, 2);
    });

    test('事项不在库里给 NotFound', () async {
      final outcome = await StopTask(_FakeTasks())(taskId: 't9', startedAt: 0, endedAt: 9000);
      expect(outcome, isA<StopTaskNotFound>());
    });
  });

  group('FinishTask', () {
    test('独立事项只勾完成，不写进度史', () async {
      final tasks = _FakeTasks([_solo('t1', name: '买猫粮')]);
      final projects = _FakeProjects();

      final outcome = await FinishTask(tasks: tasks, projects: projects, notes: _FakeNotes())(
        taskId: 't1',
        nowMs: 5000,
      );

      final finished = outcome as FinishTaskFinished;
      expect(finished.entryId, isNull);
      expect(finished.noteMoved, isFalse);
      expect(tasks.items['t1']!.done, isTrue);
      expect(tasks.items['t1']!.doneAt, 5000);
      expect(projects.added, isEmpty);
    });

    test('项目里的待办写一行进度史，挂到它所在的那一步', () async {
      final tasks = _FakeTasks([_project('t1', stepId: 's2', name: '写结论')]);
      final projects = _FakeProjects(
        bundle: const ProjectBundle(
          project: Project(id: 'p1', name: '毕业论文', createdAt: 1),
          steps: [
            Step(id: 's1', projectId: 'p1', index: 0, name: '读文献'),
            Step(id: 's2', projectId: 'p1', index: 1, name: '写结论'),
          ],
        ),
      );

      final outcome = await FinishTask(tasks: tasks, projects: projects, notes: _FakeNotes())(
        taskId: 't1',
        nowMs: 9000,
      );

      expect((outcome as FinishTaskFinished).entryId, 'h1');
      expect(projects.added.single.stepIndex, 1);
      expect(projects.added.single.content, '完成「写结论」');
      expect(projects.added.single.nowMs, 9000);
    });

    test('随手记跟着进度史走，事项上的那条清空', () async {
      final tasks = _FakeTasks([_project('t1', name: '写结论')]);
      final notes = _FakeNotes();
      await notes.save(NoteOwner.task, 't1', '口径按导师说的改', 1);

      final outcome = await FinishTask(tasks: tasks, projects: _FakeProjects(), notes: notes)(
        taskId: 't1',
        nowMs: 9000,
      );

      expect((outcome as FinishTaskFinished).noteMoved, isTrue);
      expect(await notes.textOf(NoteOwner.task, 't1'), isEmpty);
      expect(await notes.textOf(NoteOwner.history, 'h1'), '口径按导师说的改');
    });

    test('项目里的待办没写随手记时不搬内容', () async {
      final outcome = await FinishTask(
        tasks: _FakeTasks([_project('t1', name: '写结论')]),
        projects: _FakeProjects(),
        notes: _FakeNotes(),
      )(taskId: 't1', nowMs: 9000);

      expect((outcome as FinishTaskFinished).noteMoved, isFalse);
    });

    test('已完成的不再写第二行进度史', () async {
      final projects = _FakeProjects();

      final outcome = await FinishTask(
        tasks: _FakeTasks([_project('t1', done: true, name: '写结论')]),
        projects: projects,
        notes: _FakeNotes(),
      )(taskId: 't1', nowMs: 9000);

      expect(outcome, isA<FinishTaskAlreadyDone>());
      expect(projects.added, isEmpty);
    });

    test('退回未完成只翻状态，已经写下的进度史不动', () async {
      final tasks = _FakeTasks([_project('t1', done: true, name: '写结论')]);
      final projects = _FakeProjects();

      final outcome = await FinishTask(tasks: tasks, projects: projects, notes: _FakeNotes())(
        taskId: 't1',
        nowMs: 9000,
        done: false,
      );

      expect(outcome, isA<FinishTaskReopened>());
      expect(tasks.items['t1']!.done, isFalse);
      expect(tasks.items['t1']!.doneAt, isNull);
      expect(projects.added, isEmpty);
    });

    test('本来就没完成，退回给 AlreadyOpen', () async {
      final outcome = await FinishTask(
        tasks: _FakeTasks([_solo('t1', name: '买猫粮')]),
        projects: _FakeProjects(),
        notes: _FakeNotes(),
      )(taskId: 't1', nowMs: 1, done: false);

      expect(outcome, isA<FinishTaskAlreadyOpen>());
    });

    test('事项不在库里给 NotFound', () async {
      final outcome = await FinishTask(
        tasks: _FakeTasks(),
        projects: _FakeProjects(),
        notes: _FakeNotes(),
      )(taskId: 't9', nowMs: 1);
      expect(outcome, isA<FinishTaskNotFound>());
    });
  });

  group('ClassifyIdea', () {
    test('AI 给出分类就落库，并回分类名', () async {
      final ideas = _FakeIdeas(_idea('i1', title: '做个桌宠'));

      final outcome = await ClassifyIdea(ideas: ideas, classifier: _FakeClassifier('产品想法'))(
        ideaId: 'i1',
        nowMs: 7000,
      );

      final classified = outcome as ClassifyIdeaClassified;
      expect(classified.categoryName, '产品想法');
      expect(classified.categoryId, 'c1');
      expect(ideas.ensured, ['产品想法']);
      expect(ideas.markedAt, 7000);
      expect(ideas.markedCategoryId, 'c1');
    });

    test('AI 答不出时保持未分类，也不写归类时间', () async {
      final ideas = _FakeIdeas(_idea('i1'));

      final outcome = await ClassifyIdea(ideas: ideas, classifier: _FakeClassifier(null))(
        ideaId: 'i1',
        nowMs: 7000,
      );

      expect(outcome, isA<ClassifyIdeaUnavailable>());
      expect(ideas.ensured, isEmpty);
      expect(ideas.markedAt, isNull);
    });

    test('AI 只回了空白也不算分类', () async {
      final ideas = _FakeIdeas(_idea('i1'));

      final outcome = await ClassifyIdea(ideas: ideas, classifier: _FakeClassifier('   '))(
        ideaId: 'i1',
        nowMs: 7000,
      );

      expect(outcome, isA<ClassifyIdeaUnavailable>());
      expect(ideas.markedAt, isNull);
    });

    test('归过类的不再调 AI', () async {
      final ideas = _FakeIdeas(_idea('i1', classifiedAt: 100));
      final classifier = _FakeClassifier('产品想法');

      final outcome = await ClassifyIdea(ideas: ideas, classifier: classifier)(
        ideaId: 'i1',
        nowMs: 7000,
      );

      expect(outcome, isA<ClassifyIdeaAlreadyClassified>());
      expect(classifier.calls, 0);
    });

    test('想法不在库里给 NotFound', () async {
      final outcome = await ClassifyIdea(
        ideas: _FakeIdeas(null),
        classifier: _FakeClassifier('产品想法'),
      )(ideaId: 'i9', nowMs: 1);
      expect(outcome, isA<ClassifyIdeaNotFound>());
    });
  });

  group('SummarizeDay', () {
    test('AI 写好就用 AI 的，并落进当天记录', () async {
      final records = _FakeRecords();

      final outcome = await _summarizer(
        tasks: _FakeTasks.withDay(entries: [_entry('t1', name: '写摘要', seconds: 1800)]),
        records: records,
        summarizer: _FakeSummarizer('今天把摘要写完了。'),
      )(date: '2026-10-23', nowMs: 100);

      expect((outcome as SummarizeDaySummarized).text, '今天把摘要写完了。');
      expect(records.saved, ['今天把摘要写完了。']);
    });

    test('AI 不可用时降级成流水账，不落空记录', () async {
      final records = _FakeRecords();
      final notes = _FakeNotes();
      await notes.save(NoteOwner.task, 't1', '注意口径', 1);

      final outcome = await _summarizer(
        tasks: _FakeTasks.withDay(
          entries: [_entry('t1', name: '写摘要', seconds: 1800)],
          done: [_solo('t2', name: '交初稿', done: true)],
        ),
        records: records,
        notes: notes,
        summarizer: _FakeSummarizer(null),
      )(date: '2026-10-23', nowMs: 100);

      final text = (outcome as SummarizeDayDegraded).text;
      expect(text, contains('30 分钟'));
      expect(text, contains('交初稿'));
      expect(text, contains('注意口径'));
      expect(records.saved.single, text);
    });

    test('AI 只回空白也走降级', () async {
      final outcome = await _summarizer(
        tasks: _FakeTasks.withDay(entries: [_entry('t1', seconds: 60)]),
        records: _FakeRecords(),
        summarizer: _FakeSummarizer('  '),
      )(date: '2026-10-23', nowMs: 100);

      expect(outcome, isA<SummarizeDayDegraded>());
    });

    test('我自己改过的总结不再覆盖', () async {
      final records = _FakeRecords(
        record: const DailyRecord(
          id: 'd1',
          date: '2026-10-23',
          summaryText: '我自己的写法',
          summaryEditedAt: 500,
          createdAt: 100,
        ),
      );

      final outcome = await _summarizer(
        tasks: _FakeTasks.withDay(entries: [_entry('t1', seconds: 60)]),
        records: records,
        summarizer: _FakeSummarizer('AI 想改'),
      )(date: '2026-10-23', nowMs: 900);

      expect(outcome, isA<SummarizeDaySkipEdited>());
      expect(records.saved, isEmpty);
    });

    test('当天没有内容就不写记录', () async {
      final records = _FakeRecords();

      final outcome = await _summarizer(
        tasks: _FakeTasks.withDay(),
        records: records,
        summarizer: _FakeSummarizer('随便写点'),
      )(date: '2026-10-23', nowMs: 100);

      expect(outcome, isA<SummarizeDayNothing>());
      expect(records.saved, isEmpty);
    });

    test('把随手记与是否问过 AI 一起交给 AI', () async {
      final notes = _FakeNotes();
      await notes.save(NoteOwner.task, 't1', '口径问题', 1);
      final summarizer = _FakeSummarizer('好');

      await _summarizer(
        tasks: _FakeTasks.withDay(entries: [_entry('t1', name: '写摘要', seconds: 600)]),
        records: _FakeRecords(),
        notes: notes,
        chats: _FakeChats(asked: true),
        summarizer: summarizer,
      )(date: '2026-10-23', nowMs: 100);

      final item = summarizer.seen!.items.single;
      expect(item.note, '口径问题');
      expect(item.askedAi, isTrue);
      expect(summarizer.seen!.totalSeconds, 600);
    });
  });

  group('读模型', () {
    test('ProjectBundle 按 stepId 找下标，找不到给 -1', () {
      const bundle = ProjectBundle(
        steps: [
          Step(id: 's1', projectId: 'p1', index: 0, name: '读文献'),
          Step(id: 's2', projectId: 'p1', index: 1, name: '写结论'),
        ],
      );

      expect(bundle.indexOfStep('s2'), 1);
      expect(bundle.indexOfStep(null), -1);
      expect(bundle.indexOfStep('s9'), -1);
      expect(bundle.exists, isFalse);
    });

    test('DayDigest 空判断与总秒数', () {
      const empty = DayDigest(date: '2026-10-23');
      const filled = DayDigest(
        date: '2026-10-23',
        items: [
          DayDigestItem(name: '写摘要', seconds: 600),
          DayDigestItem(name: '读文献', seconds: 300),
        ],
      );

      expect(empty.isEmpty, isTrue);
      expect(filled.isEmpty, isFalse);
      expect(filled.totalSeconds, 900);
    });

    test('TaskItem 的 isSolo 与 spent', () {
      final solo = _solo('t1', spentSec: 90);
      final inProject = _project('t2', spentSec: 30);

      expect(solo.isSolo, isTrue);
      expect(solo.spent, const Duration(seconds: 90));
      expect(inProject.isSolo, isFalse);
      expect(inProject.spent, const Duration(seconds: 30));
    });
  });
}

TaskItem _solo(String id, {String name = '一件事', int spentSec = 0, bool done = false}) => TaskItem(
  id: id,
  scope: TaskScope.solo,
  name: name,
  spentSec: spentSec,
  done: done,
  doneAt: done ? 1 : null,
  createdAt: 1,
);

TaskItem _project(
  String id, {
  String projectId = 'p1',
  String? stepId,
  String name = '项目待办',
  int spentSec = 0,
  bool done = false,
}) => TaskItem(
  id: id,
  scope: TaskScope.project,
  projectId: projectId,
  stepId: stepId,
  name: name,
  spentSec: spentSec,
  done: done,
  doneAt: done ? 1 : null,
  createdAt: 1,
);

Idea _idea(String id, {String title = '一个念头', int? classifiedAt}) =>
    Idea(id: id, title: title, classifiedAt: classifiedAt, createdAt: 1);

TaskDayEntry _entry(String id, {String name = '一件事', int seconds = 0}) => TaskDayEntry(
  task: _solo(id, name: name),
  seconds: seconds,
);

SummarizeDay _summarizer({
  required TaskGateway tasks,
  required RecordGateway records,
  NoteGateway? notes,
  ChatGateway? chats,
  required DaySummarizer summarizer,
}) => SummarizeDay(
  tasks: tasks,
  records: records,
  notes: notes ?? _FakeNotes(),
  chats: chats ?? _FakeChats(),
  summarizer: summarizer,
);

class _FakeTasks implements TaskGateway {
  _FakeTasks([Iterable<TaskItem> seed = const []]) {
    for (final item in seed) {
      items[item.id] = item;
    }
  }

  /// 事项为空、只有一天投入的构造方式，省得每条测试都拼一次。
  factory _FakeTasks.withDay({
    List<TaskDayEntry> entries = const [],
    List<TaskItem> done = const [],
  }) => _FakeTasks()
    ..dayEntries = entries
    ..doneToday = done;

  final Map<String, TaskItem> items = {};
  final List<({String taskId, int startedAt, int endedAt, int seconds})> logs = [];
  final List<({String projectId, String name, int spentSec})> created = [];
  final List<(String, String)> reassigned = [];
  List<TaskDayEntry> dayEntries = [];
  List<TaskItem> doneToday = [];
  int _seq = 0;

  @override
  Future<TaskItem?> byId(String id) async => items[id];

  @override
  Future<List<TaskDayEntry>> entriesForDay(int fromMs, int toMs) async => dayEntries;

  @override
  Future<List<TaskItem>> doneBetween(int fromMs, int toMs) async => doneToday;

  @override
  Future<void> setDone(String id, bool done, int nowMs) async {
    items[id] = _copy(items[id]!, done: done, doneAt: done ? nowMs : null);
  }

  @override
  Future<void> accumulateSpent(String id, int seconds) async {
    final task = items[id]!;
    items[id] = _copy(task, spentSec: task.spentSec + seconds);
  }

  @override
  Future<String> logSession({
    required String taskId,
    required int startedAt,
    required int endedAt,
    required int seconds,
  }) async {
    logs.add((taskId: taskId, startedAt: startedAt, endedAt: endedAt, seconds: seconds));
    return 'l${++_seq}';
  }

  @override
  Future<String> createForProject({
    required String projectId,
    required String name,
    String? stepId,
    String description = '',
    required int nowMs,
    int spentSec = 0,
    TaskSource source = TaskSource.created,
  }) async {
    final id = 'tp${++_seq}';
    created.add((projectId: projectId, name: name, spentSec: spentSec));
    items[id] = TaskItem(
      id: id,
      scope: TaskScope.project,
      projectId: projectId,
      stepId: stepId,
      name: name,
      description: description,
      spentSec: spentSec,
      source: source,
      createdAt: nowMs,
    );
    return id;
  }

  @override
  Future<void> delete(String id) async {
    items.remove(id);
  }

  /// TaskItem 没有 copyWith，测里按需复一份。
  TaskItem _copy(TaskItem task, {bool? done, int? doneAt, int? spentSec}) => TaskItem(
    id: task.id,
    scope: task.scope,
    projectId: task.projectId,
    stepId: task.stepId,
    name: task.name,
    description: task.description,
    spentSec: spentSec ?? task.spentSec,
    done: done ?? task.done,
    doneAt: doneAt,
    source: task.source,
    createdAt: task.createdAt,
    orderIndex: task.orderIndex,
  );
}

class _FakeNotes implements NoteGateway {
  final Map<String, String> store = {};

  String _key(NoteOwner owner, String id) => '${owner.name}:$id';

  @override
  Future<String> textOf(NoteOwner ownerType, String ownerId) async =>
      store[_key(ownerType, ownerId)] ?? '';

  @override
  Future<void> save(NoteOwner ownerType, String ownerId, String body, int nowMs) async {
    if (body.trim().isEmpty) {
      store.remove(_key(ownerType, ownerId));
    } else {
      store[_key(ownerType, ownerId)] = body;
    }
  }

}

class _FakeProjects implements ProjectGateway {
  _FakeProjects({this.bundle = const ProjectBundle()});

  final ProjectBundle bundle;
  final List<({int stepIndex, String content, int nowMs})> added = [];
  int _seq = 0;

  @override
  Future<ProjectBundle> load(String projectId) async => bundle;

  @override
  Future<String> addProgress({
    required String projectId,
    required int stepIndex,
    required String content,
    required int nowMs,
  }) async {
    added.add((stepIndex: stepIndex, content: content, nowMs: nowMs));
    return 'h${++_seq}';
  }
}

class _FakeRecords implements RecordGateway {
  _FakeRecords({this.record});

  final DailyRecord? record;
  final List<String> saved = [];

  @override
  Future<DailyRecord?> byDate(String date) async => record;

  @override
  Future<void> setSummary(String date, String text, int nowMs) async {
    saved.add(text);
  }
}

class _FakeChats implements ChatGateway {
  _FakeChats({this.asked = false});

  final bool asked;

  @override
  Future<List<ChatMessage>> thread(ChatOwner ownerType, String ownerId) async => const [];

  @override
  Future<bool> hasAsked(ChatOwner ownerType, String ownerId) async => asked;
}

class _FakeIdeas implements IdeaGateway {
  _FakeIdeas(this.idea);

  final Idea? idea;
  final List<String> ensured = [];
  int? markedAt;
  String? markedCategoryId;

  @override
  Future<Idea?> byId(String ideaId) async => idea;

  @override
  Future<String> ensureCategory(String name, int nowMs) async {
    ensured.add(name);
    return 'c1';
  }

  @override
  Future<void> markClassified(String ideaId, String? categoryId, int nowMs) async {
    markedCategoryId = categoryId;
    markedAt = nowMs;
  }
}

class _FakeClassifier implements IdeaClassifier {
  _FakeClassifier(this.answer);

  final String? answer;
  int calls = 0;

  @override
  Future<String?> classify(Idea idea) async {
    calls++;
    return answer;
  }
}

class _FakeSummarizer implements DaySummarizer {
  _FakeSummarizer(this.answer);

  final String? answer;
  DayDigest? seen;

  @override
  Future<String?> summarize(DayDigest digest) async {
    seen = digest;
    return answer;
  }
}
