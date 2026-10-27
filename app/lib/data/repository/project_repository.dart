import 'package:drift/drift.dart';

import '../../domain/model/note.dart';
import '../../domain/model/planned_step.dart';
import '../../domain/model/project.dart';
import '../../domain/model/project_bundle.dart';
import '../../domain/model/project_digest.dart';
import '../../domain/model/revision.dart';
import '../../domain/model/step.dart';
import '../../domain/model/task_item.dart';
import '../../domain/port/project_gateway.dart';
import '../../domain/port/project_plan_writer.dart';
import '../dao/notes_dao.dart';
import '../dao/progress_entries_dao.dart';
import '../dao/projects_dao.dart';
import '../dao/revisions_dao.dart';
import '../dao/steps_dao.dart';
import '../dao/task_items_dao.dart';
import '../dao/time_logs_dao.dart';
import '../db/app_db.dart' as db;
import '../id.dart';
import '../mapping/row_mappers.dart';

/// 项目的取数入口。界面只调这里，不碰 drift。
///
/// 管四张表：projects、steps、progress_entries、revisions。
/// 删项目会连它的步骤、进度史、待办、流水、随手记一起清掉，不留孤儿。
class ProjectRepository implements ProjectGateway, ProjectPlanWriter {
  ProjectRepository(db.AppDb database)
    : _db = database,
      _projects = ProjectsDao(database),
      _steps = StepsDao(database),
      _progress = ProgressEntriesDao(database),
      _revisions = RevisionsDao(database),
      _tasks = TaskItemsDao(database),
      _logs = TimeLogsDao(database),
      _notes = NotesDao(database);

  /// 换步骤顺序与删步骤要跨三张表写，得把整个事务握在手里。
  final db.AppDb _db;
  final ProjectsDao _projects;
  final StepsDao _steps;
  final ProgressEntriesDao _progress;
  final RevisionsDao _revisions;
  final TaskItemsDao _tasks;
  final TimeLogsDao _logs;
  final NotesDao _notes;

  Future<List<Project>> all() async =>
      (await _projects.all()).map((row) => row.toDomain()).toList();

  Stream<List<Project>> watchAll() =>
      _projects.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  /// 全部项目的一行摘要：完成了几步、总共几步、上次推进什么时候。
  ///
  /// 三张表各读一次再在内存分组，项目多时比逐个查省得多；开机播报与截止提醒共用它。
  Future<List<ProjectDigest>> digests() async {
    final projects = await _projects.all();
    final steps = await _steps.all();
    final progress = await _progress.all();

    final stepsByProject = <String, List<db.Step>>{};
    for (final step in steps) {
      (stepsByProject[step.projectId] ??= <db.Step>[]).add(step);
    }
    final lastAdvanced = <String, int>{};
    for (final entry in progress) {
      final known = lastAdvanced[entry.projectId];
      if (known == null || entry.at > known) {
        lastAdvanced[entry.projectId] = entry.at;
      }
    }

    final digests = <ProjectDigest>[];
    for (final row in projects) {
      final own = stepsByProject[row.id] ?? const <db.Step>[];
      final done = own.where((step) => step.state == StepState.done.name).length;
      final current = own.where((step) => step.index == row.currentStep);
      digests.add(
        ProjectDigest(
          projectId: row.id,
          name: row.name,
          dueAt: row.dueAt,
          doneSteps: done,
          totalSteps: own.length,
          lastAdvancedAt: lastAdvanced[row.id],
          currentStepName: current.isEmpty ? null : current.first.name,
        ),
      );
    }
    return digests;
  }

  @override
  Future<ProjectBundle> load(String projectId) async {
    final project = await _projects.byId(projectId);
    if (project == null) return const ProjectBundle();
    final steps = await _steps.byProject(projectId);
    final progress = await _progress.byProject(projectId);
    return ProjectBundle(
      project: project.toDomain(),
      steps: steps.map((row) => row.toDomain()).toList(),
      progress: progress.map((row) => row.toDomain()).toList(),
    );
  }

  Stream<ProjectBundle> watch(String projectId) =>
      _projects.watchAll().asyncMap((_) => load(projectId));

  /// 新建项目，返回新 id。
  ///
  /// 使用者 2026-10-26：项目建好就先带「步骤 1」，省得进去看到一条空流程条；
  /// 于是 `currentStep` 一建出来就是 0，不再是「没有步骤」的 -1。
  Future<String> create({
    required String name,
    String description = '',
    int? dueAt,
    required int nowMs,
  }) async {
    final id = newId('p');
    await _db.transaction(() async {
      await _projects.insertOne(
        db.ProjectsCompanion.insert(
          id: id,
          name: name,
          description: Value(description),
          dueAt: Value(dueAt),
          currentStep: const Value(0),
          createdAt: nowMs,
        ),
      );
      await _steps.insertOne(
        db.StepsCompanion.insert(id: newId('s'), projectId: id, index: 0, name: '步骤 1'),
      );
    });
    return id;
  }

  Future<void> rename(String projectId, String name) =>
      _edit(projectId, (row) => row.copyWith(name: name));

  Future<void> setDescription(String projectId, String description) =>
      _edit(projectId, (row) => row.copyWith(description: description));

  Future<void> setDueAt(String projectId, int? dueAt) =>
      _edit(projectId, (row) => row.copyWith(dueAt: Value(dueAt)));

  /// 当前走到第几步。项目刚建时给 -1。
  Future<void> setCurrentStep(String projectId, int stepIndex) =>
      _edit(projectId, (row) => row.copyWith(currentStep: stepIndex));

  /// 整套换步骤：按传入顺序重排 index，原来的步骤全删。
  ///
  /// 已经挂在这些步骤上的待办不动，它们的 stepId 仍指向旧 id，
  /// 由调用方（拆解用例）决定怎么搬。
  Future<void> replaceSteps(String projectId, List<String> names) async {
    final rows = <db.StepsCompanion>[
      for (var i = 0; i < names.length; i++)
        db.StepsCompanion.insert(id: newId('s'), projectId: projectId, index: i, name: names[i]),
    ];
    await _steps.replaceProjectSteps(projectId, rows);
  }

  /// 把拆出来的步骤与每步事项一起落库，返回写入的步骤数。
  ///
  /// 「空流程」的判定是「不超过一步、且这一步下没有任何事项」——新建项目天生
  /// 带一条「步骤 1」，只看步数会把空流程当成有内容。空流程整段换掉，不留那
  /// 条占位；已有内容追加在末尾，现有步骤、进展、当前步都不动。
  @override
  Future<int> applyPlan({
    required String projectId,
    required List<PlannedStep> steps,
    required int nowMs,
  }) async {
    if (steps.isEmpty) return 0;
    final existing = await _steps.byProject(projectId);
    final tasks = await _tasks.byProject(projectId);
    final blank = existing.length <= 1 && tasks.isEmpty;

    await _db.transaction(() async {
      if (blank) await _steps.deleteByProject(projectId);
      var index = blank ? 0 : existing.length;
      for (final planned in steps) {
        final stepId = newId('s');
        await _steps.insertOne(
          db.StepsCompanion.insert(
            id: stepId,
            projectId: projectId,
            index: index++,
            name: planned.name,
          ),
        );
        final task = planned.task.trim();
        if (task.isEmpty) continue;
        await _tasks.insertOne(
          db.TaskItemsCompanion.insert(
            id: newId('t'),
            scope: TaskScope.project.dbValue,
            projectId: Value(projectId),
            stepId: Value(stepId),
            name: task,
            createdAt: nowMs,
          ),
        );
      }
    });
    return steps.length;
  }

  /// 改一步的名字。步骤已经不在了就当作没发生。
  Future<void> renameStep(String stepId, String name) async {
    final row = await _steps.byId(stepId);
    if (row == null) return;
    await _steps.updateRow(row.copyWith(name: name));
  }

  /// 在项目末尾加一步，返回新步骤 id。
  ///
  /// 编号取现有最大值加一，而不是取行数：前面删过步骤时行数会小于最大编号。
  Future<String> addStep(String projectId, {required String name}) async {
    final rows = await _steps.byProject(projectId);
    var next = 0;
    for (final row in rows) {
      if (row.index >= next) next = row.index + 1;
    }
    final id = newId('s');
    await _steps.insertOne(
      db.StepsCompanion.insert(id: id, projectId: projectId, index: next, name: name),
    );
    return id;
  }

  /// 与相邻步骤换位；`delta` 为 -1 上移、1 下移。已经在头尾时返回 false。
  ///
  /// 三张表一起换：步骤编号、各自待办的归属、进度史里记的编号。只换一半会让
  /// 事项挂在错的那一步上。
  Future<bool> moveStep(String stepId, int delta) async {
    final step = await _steps.byId(stepId);
    if (step == null) return false;
    final target = step.index + delta;
    final siblings = await _steps.byProject(step.projectId);
    db.Step? other;
    for (final row in siblings) {
      if (row.index == target) other = row;
    }
    if (other == null) return false;
    final moved = other;

    await _db.transaction(() async {
      final mine = await _tasks.byStep(step.id);
      final theirs = await _tasks.byStep(moved.id);
      await _steps.updateRow(step.copyWith(index: target));
      await _steps.updateRow(moved.copyWith(index: step.index));
      for (final task in mine) {
        await _tasks.updateRow(task.copyWith(stepId: Value(moved.id)));
      }
      for (final task in theirs) {
        await _tasks.updateRow(task.copyWith(stepId: Value(step.id)));
      }
      final entries = await _progress.byProject(step.projectId);
      for (final entry in entries) {
        if (entry.stepIndex == step.index) {
          await _progress.updateRow(entry.copyWith(stepIndex: target));
        } else if (entry.stepIndex == target) {
          await _progress.updateRow(entry.copyWith(stepIndex: step.index));
        }
      }
    });
    return true;
  }

  /// 删掉一步：它的待办转为未分配，后面各步与进度史编号各前移一位，
  /// 项目的 `currentStep` 收进新范围。整段在一个事务里做完，失败不留半截数据。
  Future<void> deleteStep(String stepId) async {
    final step = await _steps.byId(stepId);
    if (step == null) return;

    await _db.transaction(() async {
      await _tasks.clearStep(stepId);
      await _steps.deleteById(stepId);
      final siblings = await _steps.byProject(step.projectId);
      for (final row in siblings) {
        if (row.index > step.index) {
          await _steps.updateRow(row.copyWith(index: row.index - 1));
        }
      }
      await _progress.shiftAfter(step.projectId, step.index);
      final project = await _projects.byId(step.projectId);
      if (project == null) return;
      // `currentStep` 是「正在推进第几步」，删掉的步在它前面就要跟着前移；
      // 删的就是它自己则留在原位（等于落到原下一步），越界收到末位。
      final remaining = siblings.length;
      var next = project.currentStep;
      if (next > step.index) next -= 1;
      if (next >= remaining) next = remaining - 1;
      if (next != project.currentStep) {
        await _projects.updateRow(project.copyWith(currentStep: next));
      }
    });
  }

  @override
  Future<String> addProgress({
    required String projectId,
    required int stepIndex,
    required String content,
    required int nowMs,
  }) async {
    final id = newId('h');
    await _progress.insertOne(
      db.ProgressEntriesCompanion.insert(
        id: id,
        projectId: projectId,
        stepIndex: stepIndex,
        content: content,
        at: nowMs,
      ),
    );
    return id;
  }

  /// 改进度史：记一条修订再落新正文，原文不丢。
  Future<void> reviseProgress(String entryId, String before, String after, int nowMs) async {
    final entry = await _progress.byId(entryId);
    if (entry == null) return;
    await _revisions.insertOne(
      db.RevisionsCompanion.insert(
        id: newId('r'),
        targetType: RevisionTarget.progressEntry.dbValue,
        targetId: entryId,
        before: before,
        after: after,
        at: nowMs,
      ),
    );
    await _progress.updateRow(
      entry.copyWith(content: after, revisionCount: entry.revisionCount + 1),
    );
  }

  Future<List<Revision>> revisionsOf(String targetType, String targetId) async {
    final rows = await _revisions.byTarget(targetType, targetId);
    return rows.map((row) => row.toDomain()).toList();
  }

  /// 删项目：连步骤、进度史、待办、流水、随手记一起删。
  Future<void> delete(String projectId) async {
    final tasks = await _tasks.byProject(projectId);
    for (final task in tasks) {
      await _logs.deleteByTask(task.id);
      await _notes.deleteByOwner(NoteOwner.task.dbValue, task.id);
      await _tasks.deleteById(task.id);
    }
    final entries = await _progress.byProject(projectId);
    for (final entry in entries) {
      await _notes.deleteByOwner(NoteOwner.history.dbValue, entry.id);
      await _progress.deleteById(entry.id);
    }
    await _steps.deleteByProject(projectId);
    await _projects.deleteById(projectId);
  }

  Future<void> _edit(String projectId, db.Project Function(db.Project row) change) async {
    final row = await _projects.byId(projectId);
    if (row == null) return;
    await _projects.updateRow(change(row));
  }
}
