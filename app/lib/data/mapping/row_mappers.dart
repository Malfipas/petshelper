import '../../domain/model/category.dart';
import '../../domain/model/chat_message.dart';
import '../../domain/model/daily_record.dart';
import '../../domain/model/idea.dart';
import '../../domain/model/note.dart';
import '../../domain/model/progress_entry.dart';
import '../../domain/model/project.dart';
import '../../domain/model/revision.dart';
import '../../domain/model/settings.dart';
import '../../domain/model/step.dart';
import '../../domain/model/task_item.dart';
import '../../domain/model/time_log.dart';
import '../db/app_db.dart' as db;

/// drift 的行 → 领域实体。drift 的类型只在本文件里以 `db.` 前缀出现，
/// 出了 data 层就只剩领域模型。
extension ProjectRowX on db.Project {
  Project toDomain() => Project(
    id: id,
    name: name,
    description: description,
    dueAt: dueAt,
    currentStep: currentStep,
    createdAt: createdAt,
  );
}

extension StepRowX on db.Step {
  Step toDomain() =>
      Step(id: id, projectId: projectId, index: index, name: name, state: StepState.fromDb(state));
}

extension TaskRowX on db.TaskItem {
  TaskItem toDomain() => TaskItem(
    id: id,
    scope: TaskScope.fromDb(scope),
    projectId: projectId,
    stepId: stepId,
    name: name,
    description: description,
    spentSec: spentSec,
    done: done,
    doneAt: doneAt,
    source: TaskSource.fromDb(source),
    createdAt: createdAt,
    orderIndex: orderIndex,
  );
}

extension NoteRowX on db.Note {
  Note toDomain() => Note(
    id: id,
    ownerType: NoteOwner.fromDb(ownerType),
    ownerId: ownerId,
    body: body,
    updatedAt: updatedAt,
  );
}

extension TimeLogRowX on db.TimeLog {
  TimeLog toDomain() =>
      TimeLog(id: id, taskId: taskId, startedAt: startedAt, endedAt: endedAt, seconds: seconds);
}

extension DailyRecordRowX on db.DailyRecord {
  DailyRecord toDomain() => DailyRecord(
    id: id,
    date: date,
    summaryText: summaryText,
    summaryEditedAt: summaryEditedAt,
    createdAt: createdAt,
  );
}

extension IdeaRowX on db.Idea {
  Idea toDomain() => Idea(
    id: id,
    title: title,
    body: body,
    categoryId: categoryId,
    classifiedAt: classifiedAt,
    createdAt: createdAt,
  );
}

extension CategoryRowX on db.Category {
  Category toDomain() => Category(id: id, name: name, color: color, createdAt: createdAt);
}

extension ChatMessageRowX on db.ChatMessage {
  ChatMessage toDomain() => ChatMessage(
    id: id,
    ownerType: ownerType,
    ownerId: ownerId,
    role: ChatRole.fromDb(role),
    content: content,
    at: at,
  );
}

extension ProgressEntryRowX on db.ProgressEntry {
  ProgressEntry toDomain() => ProgressEntry(
    id: id,
    projectId: projectId,
    stepIndex: stepIndex,
    content: content,
    at: at,
    revisionCount: revisionCount,
  );
}

extension RevisionRowX on db.Revision {
  Revision toDomain() => Revision(
    id: id,
    targetType: RevisionTarget.fromDb(targetType),
    targetId: targetId,
    before: before,
    after: after,
    at: at,
  );
}

extension SettingRowX on db.Setting {
  Settings toDomain() => Settings(
    keyConfigured: keyConfigured,
    demoUrl: demoUrl,
    repoUrl: repoUrl,
    bubbleEnabled: bubbleEnabled,
    side: PetSide.fromDb(side),
    anchorY: anchorY,
  );
}

/// 领域枚举 → 库里存的字符串。
extension TaskScopeX on TaskScope {
  String get dbValue => name;
}

extension TaskSourceX on TaskSource {
  String get dbValue => name;
}

extension NoteOwnerX on NoteOwner {
  String get dbValue => name;
}

extension ChatOwnerX on ChatOwner {
  String get dbValue => name;
}

extension RevisionTargetX on RevisionTarget {
  String get dbValue => name;
}

extension ChatRoleX on ChatRole {
  String get dbValue => name;
}

extension PetSideX on PetSide {
  String get dbValue => name;
}
