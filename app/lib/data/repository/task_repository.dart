import 'package:drift/drift.dart';

import '../../domain/model/note.dart';
import '../../domain/model/task_day_entry.dart';
import '../../domain/model/task_item.dart';
import '../../domain/port/task_gateway.dart';
import '../dao/notes_dao.dart';
import '../dao/task_items_dao.dart';
import '../dao/time_logs_dao.dart';
import '../db/app_db.dart' as db;
import '../id.dart';
import '../mapping/row_mappers.dart';

/// 事项的取数入口。独立事项与项目待办同一张表，用 scope 区分。
///
/// 管两张表：task_items、time_logs。开始、停止、标记完成这些动作在用例里。
/// 对外只给领域模型，drift 的行类型不出这一层。
class TaskRepository implements TaskGateway {
  TaskRepository(db.AppDb database)
    : _items = TaskItemsDao(database),
      _logs = TimeLogsDao(database),
      _notes = NotesDao(database);

  final TaskItemsDao _items;
  final TimeLogsDao _logs;
  final NotesDao _notes;

  Stream<List<TaskItem>> watchSolo() => _items.watchSolo().map(_toList);

  Future<List<TaskItem>> solo() async => _toList(await _items.solo());

  Stream<List<TaskItem>> watchProject(String projectId) =>
      _items.watchAll().map((rows) => _toList(rows.where((r) => r.projectId == projectId)));

  Future<List<TaskItem>> byProject(String projectId) async =>
      _toList(await _items.byProject(projectId));

  @override
  Future<TaskItem?> byId(String id) async {
    final row = await _items.byId(id);
    return row?.toDomain();
  }

  /// 新建独立事项。
  Future<String> createSolo({
    required String name,
    String description = '',
    required int nowMs,
    TaskSource source = TaskSource.created,
  }) async {
    final id = newId('t');
    await _items.insertOne(
      db.TaskItemsCompanion.insert(
        id: id,
        scope: TaskScope.solo.dbValue,
        name: name,
        description: Value(description),
        source: Value(source.dbValue),
        createdAt: nowMs,
      ),
    );
    return id;
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
    final id = newId('t');
    await _items.insertOne(
      db.TaskItemsCompanion.insert(
        id: id,
        scope: TaskScope.project.dbValue,
        projectId: Value(projectId),
        stepId: Value(stepId),
        name: name,
        description: Value(description),
        spentSec: Value(spentSec),
        source: Value(source.dbValue),
        createdAt: nowMs,
      ),
    );
    return id;
  }

  Future<void> rename(String id, String name) => _edit(id, (row) => row.copyWith(name: name));

  Future<void> setDescription(String id, String description) =>
      _edit(id, (row) => row.copyWith(description: description));

  /// 挂到某一步，或从步骤上摘下来（stepId 传 null）。
  Future<void> setStep(String id, String? stepId) =>
      _edit(id, (row) => row.copyWith(stepId: Value(stepId)));

  @override
  Future<void> setDone(String id, bool done, int nowMs) =>
      _edit(id, (row) => row.copyWith(done: done, doneAt: Value(done ? nowMs : null)));

  @override
  Future<void> accumulateSpent(String id, int seconds) =>
      _edit(id, (row) => row.copyWith(spentSec: row.spentSec + seconds));

  /// 把这一件的累计计时清零，连同它的计时流水一起删掉。
  ///
  /// 只清 `spentSec` 会留下流水，记录页照旧算得出那段时间，两处对不上；既然
  /// 使用者点了「重置」，就当这段时间没发生过。
  Future<void> resetSpent(String id) async {
    await _logs.deleteByTask(id);
    await _edit(id, (row) => row.copyWith(spentSec: 0));
  }

  @override
  Future<String> logSession({
    required String taskId,
    required int startedAt,
    required int endedAt,
    required int seconds,
  }) async {
    final id = newId('l');
    await _logs.insertOne(
      db.TimeLogsCompanion.insert(
        id: id,
        taskId: taskId,
        startedAt: startedAt,
        endedAt: endedAt,
        seconds: seconds,
      ),
    );
    return id;
  }

  /// 某个事项一共投入了多少秒。
  Future<int> totalSeconds(String taskId) => _logs.totalSecondsByTask(taskId);

  @override
  Future<List<TaskItem>> doneBetween(int fromMs, int toMs) async =>
      _toList(await _items.doneBetween(fromMs, toMs));

  /// 某一天动过的事项，连投入秒数与时刻一起给。记录页右栏用。
  ///
  /// 「动过」按两种算：当天开过表（有流水），以及当天被标记完成（有 `doneAt`）。
  /// 后者往往没有流水——面板里点「标记完成」不跑秒——只按流水取会把整条漏掉。
  /// 排序交给上层：这一层只给事实，显示先后由记录页定。
  ///
  /// 事项被删掉后流水可能还在，这里跳过找不到事项的流水，不让一条孤儿把整页打挂。
  @override
  Future<List<TaskDayEntry>> entriesForDay(int fromMs, int toMs) async {
    final logsOfDay = await _logs.between(fromMs, toMs);
    final secondsByTask = <String, int>{};
    final lastEndByTask = <String, int>{};
    for (final log in logsOfDay) {
      secondsByTask[log.taskId] = (secondsByTask[log.taskId] ?? 0) + log.seconds;
      final last = lastEndByTask[log.taskId];
      if (last == null || log.endedAt > last) lastEndByTask[log.taskId] = log.endedAt;
    }

    final doneOfDay = await doneBetween(fromMs, toMs);
    final ids = <String>{...secondsByTask.keys, for (final task in doneOfDay) task.id};

    final entries = <TaskDayEntry>[];
    for (final id in ids) {
      final task = await byId(id);
      if (task == null) continue;
      entries.add(
        TaskDayEntry(
          task: task,
          seconds: secondsByTask[id] ?? 0,
          atMs: lastEndByTask[id] ?? task.doneAt,
        ),
      );
    }
    return entries;
  }

  /// 与同一步里相邻的一条交换顺序。
  ///
  /// 已经在头（`delta < 0`）或尾（`delta > 0`）返回 false，界面据此保持原样，
  /// 不弹提示。跨步骤不换：换位只在「这是同一步里的第几件」这一层发生。
  Future<bool> moveOrder(String id, int delta) async {
    final row = await _items.byId(id);
    final projectId = row?.projectId;
    if (row == null || projectId == null || delta == 0) return false;
    final siblings =
        (await _items.byProject(projectId))
            .where((candidate) => candidate.stepId == row.stepId && !candidate.done)
            .toList()
          ..sort((a, b) {
            final byOrder = a.orderIndex.compareTo(b.orderIndex);
            if (byOrder != 0) return byOrder;
            final byTime = a.createdAt.compareTo(b.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    final at = siblings.indexWhere((candidate) => candidate.id == id);
    if (at < 0) return false;
    final to = at + delta;
    if (to < 0 || to >= siblings.length) return false;
    final other = siblings[to];
    if (other.orderIndex == row.orderIndex) return false;
    await _items.updateRow(row.copyWith(orderIndex: other.orderIndex));
    await _items.updateRow(other.copyWith(orderIndex: row.orderIndex));
    return true;
  }

  /// 在某一步末尾新增一条待办，返回新 id。
  ///
  /// 末尾是「该步现有最大 orderIndex 加一」，不是行数：删过中间一条之后行数会比
  /// 最大编号小，按行数会撞号。
  Future<String> addToStep({
    required String projectId,
    required String stepId,
    required String name,
    required int nowMs,
  }) async {
    final id = newId('t');
    await _items.insertOne(
      db.TaskItemsCompanion.insert(
        id: id,
        scope: TaskScope.project.dbValue,
        projectId: Value(projectId),
        stepId: Value(stepId),
        name: name,
        orderIndex: Value(await _tailOrder(stepId)),
        createdAt: nowMs,
      ),
    );
    return id;
  }

  /// 把一条没挂步骤的事项挂到某一步，排在该步末尾。
  Future<void> assignToStep({required String taskId, required String stepId}) async {
    final tail = await _tailOrder(stepId);
    await _edit(taskId, (row) => row.copyWith(stepId: Value(stepId), orderIndex: tail));
  }

  /// 某一步末尾的下一个 orderIndex。
  Future<int> _tailOrder(String stepId) async {
    var tail = -1;
    for (final row in await _items.byStep(stepId)) {
      if (row.orderIndex > tail) tail = row.orderIndex;
    }
    return tail + 1;
  }

  /// 删事项：连它的流水与随手记一起清掉，不留孤儿。
  @override
  Future<void> delete(String id) async {
    await _logs.deleteByTask(id);
    await _notes.deleteByOwner(NoteOwner.task.dbValue, id);
    await _items.deleteById(id);
  }

  Future<void> _edit(String id, db.TaskItem Function(db.TaskItem row) change) async {
    final row = await _items.byId(id);
    if (row == null) return;
    await _items.updateRow(change(row));
  }

  List<TaskItem> _toList(Iterable<db.TaskItem> rows) =>
      rows.map((row) => row.toDomain()).toList(growable: false);
}
