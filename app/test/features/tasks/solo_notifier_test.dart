import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Note, TaskItem;
import 'package:ai_pet_assistant/domain/model/note.dart';
import 'package:ai_pet_assistant/domain/model/task_item.dart';
import 'package:ai_pet_assistant/features/tasks/solo_notifier.dart';
import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 独立事项页的状态：谁在前面、哪些看不见、改完落没落库。
void main() {
  late AppDb db;
  late ProviderContainer container;
  late SoloListNotifier notifier;
  late int nowMs;
  late TimerService timer;

  /// 固定「现在」：2026-10-24 09:00，相对日期与「当天完成」才有确定答案。
  final today = DateTime(2026, 10, 24, 9);
  final yesterday = DateTime(2026, 10, 23, 20);

  setUp(() {
    db = AppDb.memory();
    nowMs = today.millisecondsSinceEpoch;
    timer = TimerService(now: () => nowMs);
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        timerServiceProvider.overrideWithValue(timer),
        soloListProvider.overrideWith(() => SoloListNotifier(now: () => DateTime(2026, 10, 24, 9))),
      ],
    );
    notifier = container.read(soloListProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    timer.dispose();
    await db.close();
  });

  Future<String> seed(String name, {int? atMs}) =>
      container.read(taskRepositoryProvider).createSolo(name: name, nowMs: atMs ?? nowMs);

  test('新建的进列表，说明跟着落库', () async {
    await notifier.create(name: '  买菜  ', description: '顺路带牛奶');
    await notifier.reload();

    final items = container.read(soloListProvider).items;
    expect(items, hasLength(1));
    expect(items.single.name, '买菜');
    expect(items.single.description, '顺路带牛奶');
    expect(container.read(soloListProvider).loading, isFalse);
  });

  test('名称空白时不建，列表不动', () async {
    await notifier.create(name: '   ');
    await notifier.reload();
    expect(container.read(soloListProvider).items, isEmpty);
  });

  test('勾完成沉到最底并带完成时间，再点退回原位', () async {
    final first = await seed('交电费', atMs: nowMs - 5000);
    await seed('买菜', atMs: nowMs - 1000);
    await notifier.reload();

    await notifier.toggleDone(first);
    await notifier.reload();
    var items = container.read(soloListProvider).items;
    expect(items.last.id, first);
    expect(items.last.done, isTrue);
    expect(items.last.doneAt, isNotNull);

    await notifier.toggleDone(first);
    await notifier.reload();
    items = container.read(soloListProvider).items;
    expect(items.where((task) => task.id == first).single.done, isFalse);
  });

  test('昨天完成的今天看不到，今天完成的还留着', () async {
    final tasks = container.read(taskRepositoryProvider);
    final old = await seed('昨天的', atMs: yesterday.millisecondsSinceEpoch);
    await tasks.setDone(old, true, yesterday.millisecondsSinceEpoch);
    final fresh = await seed('今天的');
    await tasks.setDone(fresh, true, nowMs);

    await notifier.reload();
    final names = container.read(soloListProvider).items.map((t) => t.name);
    expect(names, ['今天的']);
  });

  test('自动保存只写名称与说明，随手记留到点保存', () async {
    final id = await seed('原名');
    await notifier.reload();

    await notifier.autoSave(id: id, name: '新名', description: '新说明');

    final task = await container.read(taskRepositoryProvider).byId(id);
    expect(task!.name, '新名');
    expect(task.description, '新说明');
    // 使用者 2026-10-25 改的口径：编辑页随手记不再自动存。
    final note = await container.read(noteRepositoryProvider).textOf(NoteOwner.task, id);
    expect(note, isEmpty);
    // 自动保存不收起详情，也不弹提示。
    expect(container.read(soloListProvider).flash, isNull);
  });

  test('点保存：名称留空回退原名、详情收起、提示带名字', () async {
    final id = await seed('原名');
    await notifier.toggleDetail(id);
    expect(container.read(soloListProvider).openId, id);

    await notifier.saveNow(id: id, name: '   ', description: '说明', note: '');

    final task = await container.read(taskRepositoryProvider).byId(id);
    expect(task!.name, '原名');
    expect(container.read(soloListProvider).openId, isNull);
    expect(container.read(soloListProvider).flash, '已保存 · 原名');
  });

  test('删除连随手记一起走', () async {
    final id = await seed('要删的');
    await container.read(noteRepositoryProvider).save(NoteOwner.task, id, '这句也删', nowMs);
    await notifier.reload();

    await notifier.remove(id);
    await notifier.reload();

    expect(container.read(soloListProvider).items, isEmpty);
    expect(await container.read(noteRepositoryProvider).textOf(NoteOwner.task, id), '');
  });

  test('同时只能展开一条，Esc 收掉后才轮到收壳', () async {
    final first = await seed('一');
    final second = await seed('二');
    await notifier.reload();

    await notifier.toggleDetail(first);
    expect(container.read(soloListProvider).openId, first);
    await notifier.toggleDetail(second);
    expect(container.read(soloListProvider).openId, second);

    expect(notifier.collapseDetail(), isTrue);
    expect(container.read(soloListProvider).openId, isNull);
    expect(notifier.collapseDetail(), isFalse);
  });

  group('排序与文案', () {
    TaskItem item(String id, {bool done = false, int createdAt = 0}) => TaskItem(
      id: id,
      scope: TaskScope.solo,
      name: id,
      done: done,
      doneAt: done ? createdAt : null,
      createdAt: createdAt,
    );

    test('未完成在前、当前事务最前，已完成按完成时间倒序在后', () {
      final sorted = SoloListNotifier.sortItems([
        item('old', createdAt: 100),
        item('fresh', createdAt: 300),
        item('doneOld', done: true, createdAt: 50),
        item('doneFresh', done: true, createdAt: 400),
        item('mid', createdAt: 200),
      ], currentId: 'mid');

      expect(sorted.map((task) => task.id), ['mid', 'fresh', 'old', 'doneFresh', 'doneOld']);
    });

    test('相对时间：刚刚 / 分钟前 / 小时前 / 昨天 / 前天 / N天前', () {
      expect(relativeDay(today.millisecondsSinceEpoch, today), '刚刚');
      expect(
        relativeDay(today.subtract(const Duration(seconds: 59)).millisecondsSinceEpoch, today),
        '刚刚',
      );
      expect(
        relativeDay(today.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch, today),
        '1分钟前',
      );
      expect(
        relativeDay(today.subtract(const Duration(minutes: 59)).millisecondsSinceEpoch, today),
        '59分钟前',
      );
      expect(
        relativeDay(today.subtract(const Duration(hours: 3)).millisecondsSinceEpoch, today),
        '3小时前',
      );
      expect(relativeDay(yesterday.millisecondsSinceEpoch, today), '昨天');
      expect(
        relativeDay(today.subtract(const Duration(days: 2)).millisecondsSinceEpoch, today),
        '前天',
      );
      expect(
        relativeDay(today.subtract(const Duration(days: 3)).millisecondsSinceEpoch, today),
        '3天前',
      );
      expect(
        relativeDay(today.subtract(const Duration(days: 9)).millisecondsSinceEpoch, today),
        '一周前',
      );
      expect(
        relativeDay(today.subtract(const Duration(days: 40)).millisecondsSinceEpoch, today),
        '一个月前',
      );
    });

    test('一分钟都没计过就是 0 分钟，其余四舍五入', () {
      expect(minutesOf(0), 0);
      expect(minutesOf(20), 1);
      expect(minutesOf(89), 1);
      expect(minutesOf(90), 2);
      expect(minutesOf(600), 10);
    });
  });
}
