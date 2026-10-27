import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// task_items 表的存取。独立事项与项目待办在同一张表，用 scope 区分。
class TaskItemsDao extends DatabaseAccessor<AppDb> {
  TaskItemsDao(super.db);

  Future<List<TaskItem>> all() => select(db.taskItems).get();

  Stream<List<TaskItem>> watchAll() => select(db.taskItems).watch();

  Future<List<TaskItem>> solo() =>
      (select(db.taskItems)..where((t) => t.scope.equals('solo'))).get();

  Stream<List<TaskItem>> watchSolo() =>
      (select(db.taskItems)..where((t) => t.scope.equals('solo'))).watch();

  Future<List<TaskItem>> byProject(String projectId) =>
      (select(db.taskItems)..where((t) => t.projectId.equals(projectId))).get();

  Future<List<TaskItem>> byStep(String stepId) =>
      (select(db.taskItems)..where((t) => t.stepId.equals(stepId))).get();

  Future<List<TaskItem>> unassigned(String projectId) =>
      (select(db.taskItems)..where((t) => t.projectId.equals(projectId) & t.stepId.isNull())).get();

  Future<TaskItem?> byId(String id) =>
      (select(db.taskItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertOne(TaskItemsCompanion companion) => into(db.taskItems).insert(companion);

  Future<bool> updateRow(TaskItem row) => update(db.taskItems).replace(row);

  Future<int> deleteById(String id) => (delete(db.taskItems)..where((t) => t.id.equals(id))).go();

  /// 某一段时间里做完的事项，按完成时间倒序。记录页用。
  Future<List<TaskItem>> doneBetween(int fromMs, int toMs) =>
      (select(db.taskItems)
            ..where(
              (t) =>
                  t.done.equals(true) &
                  t.doneAt.isBiggerOrEqualValue(fromMs) &
                  t.doneAt.isSmallerThanValue(toMs),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.doneAt)]))
          .get();

  /// 某一步被删掉时，把挂在这一步的待办改为未分配。
  ///
  /// 事项本身不删：写了一半的活不该因为调整流程而消失，它只是退回到无归属那一堆。
  Future<int> clearStep(String stepId) =>
      (update(db.taskItems)..where((t) => t.stepId.equals(stepId))).write(
        const TaskItemsCompanion(stepId: Value<String?>(null)),
      );

  /// 删项目时把它的待办一起清掉。
  Future<int> deleteByProject(String projectId) =>
      (delete(db.taskItems)..where((t) => t.projectId.equals(projectId))).go();
}
