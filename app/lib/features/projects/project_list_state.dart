import '../../domain/model/progress_entry.dart';
import '../../domain/model/project.dart';
import '../../domain/model/revision.dart';
import '../../domain/model/step.dart';
import '../../domain/model/task_item.dart';
import 'project_ai_state.dart';

/// 一行项目卡片要显示的东西。
///
/// 卡片的四个数各有出处：百分比与步数来自 `ProjectDigest`，下一步要读待办，
/// 最近推进要落成相对日期，所以在 notifier 里一次算好，界面只管画。
class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.name,
    required this.percent,
    required this.nextStep,
    required this.createdAt,
    this.lastAdvancedAt,
  });

  final String id;
  final String name;

  /// 完成度百分比，按已完成步数占总步数四舍五入。
  final int percent;

  /// 下一步做的那件事；没有未完成待办时是空串。
  final String nextStep;

  final int createdAt;

  /// 最近一次推进的时间；从没推进过为 null，卡片上按创建时间兜底。
  final int? lastAdvancedAt;
}

/// 项目页的状态：列表、当前展开的项目、新建表单草稿、删除确认。
class ProjectListState {
  const ProjectListState({
    this.rows = const [],
    this.loading = true,
    this.openId,
    this.detail,
    this.detailPercent = 0,
    this.detailDoneSteps = 0,
    this.detailTotalSteps = 0,
    this.detailLastAdvancedAt,
    this.detailSteps = const [],
    this.filterStep,
    this.flowEditing = false,
    this.detailTasks = const [],
    this.movedTasks = const [],
    this.pendingDone = const {},
    this.flashTaskId,
    this.expandedTaskId,
    this.confirmingTaskDelete,
    this.addTaskFor,
    this.assigningTaskId,
    this.notes = const {},
    this.detailProgress = const [],
    this.historyTimeline = false,
    this.editingEntryId,
    this.historyNoteEditingId,
    this.openRevisions = const {},
    this.revisions = const {},
    this.historyNotes = const {},
    this.aiHelp = const AiHelp(),
    this.formOpen = false,
    this.name = '',
    this.description = '',
    this.dueAt,
    this.nameTaken = false,
    this.confirming = false,
    this.flash = '',
  });

  final List<ProjectRow> rows;
  final bool loading;

  /// 正在展开的项目 id；null 表示停在列表态。
  final String? openId;
  final Project? detail;
  final int detailPercent;
  final int detailDoneSteps;
  final int detailTotalSteps;
  final int? detailLastAdvancedAt;

  /// 展开项目的步骤，按 `index` 升序；分段条与流程编辑器都读它。
  final List<Step> detailSteps;

  /// 筛中的步骤下标；null 表示不筛。
  final int? filterStep;

  /// 流程编辑器是否展开。
  final bool flowEditing;

  /// 待办区要列的事项：已挂步骤、未完成，筛了就只留这一步，按 `orderIndex` 升序。
  final List<TaskItem> detailTasks;

  /// 没挂步骤的未完成事项；空的时候「从独立事项移入」整块不渲染。
  final List<TaskItem> movedTasks;

  /// 刚点完成、还在 600 毫秒等待里的事项 id。期间行还留着，只是刷成完成态。
  final Set<String> pendingDone;

  /// 新增之后要闪一下的事项 id。
  final String? flashTaskId;

  /// 正在展开编辑页的那条待办；同时只开一条，null 表示都收着。
  final String? expandedTaskId;

  /// 等着二次确认删除的待办 id；null 表示没开确认浮层。
  final String? confirmingTaskDelete;

  /// 正在行内新增事项的步骤 id。
  final String? addTaskFor;

  /// 正在选步骤的未分配事项 id。
  final String? assigningTaskId;

  /// 已展示事项的随手记正文，卡片的「已记 / 还没记」读它。
  final Map<String, String> notes;

  /// 当前项目的进度史，按流程顺序：先步骤、同一步内按时间。
  final List<ProgressEntry> detailProgress;

  /// 进度史区块是不是切在时间轴那一侧。
  final bool historyTimeline;

  /// 正在改正文的那条进度史 id。
  final String? editingEntryId;

  /// 正在写随手记的那条进度史 id。
  final String? historyNoteEditingId;

  /// 修订链已经展开的进度史 id。
  final Set<String> openRevisions;

  /// 读回来的修订链，按进度史 id 缓存，展开一次就不再读库。
  final Map<String, List<Revision>> revisions;

  /// 进度史的随手记正文，按进度史 id 存。
  final Map<String, String> historyNotes;

  /// 详情页「AI 帮助」那一块的展开态、草稿与结果。
  final AiHelp aiHelp;

  final bool formOpen;
  final String name;
  final String description;
  final int? dueAt;

  /// 输入的项目名与已有项目重名。
  final bool nameTaken;

  /// 删除确认弹窗是否开着。
  final bool confirming;

  /// 一行短暂提示，页面读一次就清。
  final String flash;

  /// 项目名去空格后能不能提交。
  bool get canSubmit => name.trim().isNotEmpty && !nameTaken;

  ProjectListState copyWith({
    List<ProjectRow>? rows,
    bool? loading,
    String? openId,
    Project? detail,
    int? detailPercent,
    int? detailDoneSteps,
    int? detailTotalSteps,
    int? detailLastAdvancedAt,
    List<Step>? detailSteps,
    int? filterStep,
    bool? flowEditing,
    List<TaskItem>? detailTasks,
    List<TaskItem>? movedTasks,
    Set<String>? pendingDone,
    String? flashTaskId,
    String? expandedTaskId,
    String? confirmingTaskDelete,
    String? addTaskFor,
    String? assigningTaskId,
    Map<String, String>? notes,
    List<ProgressEntry>? detailProgress,
    bool? historyTimeline,
    String? editingEntryId,
    String? historyNoteEditingId,
    Set<String>? openRevisions,
    Map<String, List<Revision>>? revisions,
    Map<String, String>? historyNotes,
    AiHelp? aiHelp,
    bool? formOpen,
    String? name,
    String? description,
    int? dueAt,
    bool? nameTaken,
    bool? confirming,
    String? flash,
    bool clearOpen = false,
    bool clearDetail = false,
    bool clearDue = false,
    bool clearFlash = false,
    bool clearFilter = false,
    bool clearFlashTask = false,
    bool clearAddTaskFor = false,
    bool clearAssigning = false,
    bool clearEditingEntry = false,
    bool clearHistoryNoteEditing = false,
    bool clearExpandedTask = false,
    bool clearTaskDelete = false,
  }) {
    return ProjectListState(
      rows: rows ?? this.rows,
      loading: loading ?? this.loading,
      openId: clearOpen ? null : (openId ?? this.openId),
      detail: clearDetail ? null : (detail ?? this.detail),
      detailPercent: clearDetail ? 0 : (detailPercent ?? this.detailPercent),
      detailDoneSteps: clearDetail ? 0 : (detailDoneSteps ?? this.detailDoneSteps),
      detailTotalSteps: clearDetail ? 0 : (detailTotalSteps ?? this.detailTotalSteps),
      detailLastAdvancedAt: clearDetail
          ? null
          : (detailLastAdvancedAt ?? this.detailLastAdvancedAt),
      detailSteps: clearDetail ? const [] : (detailSteps ?? this.detailSteps),
      filterStep: clearDetail || clearFilter ? null : (filterStep ?? this.filterStep),
      flowEditing: clearDetail ? false : (flowEditing ?? this.flowEditing),
      detailTasks: clearDetail ? const [] : (detailTasks ?? this.detailTasks),
      movedTasks: clearDetail ? const [] : (movedTasks ?? this.movedTasks),
      pendingDone: clearDetail ? const {} : (pendingDone ?? this.pendingDone),
      flashTaskId: clearDetail || clearFlashTask ? null : (flashTaskId ?? this.flashTaskId),
      expandedTaskId: clearDetail || clearExpandedTask
          ? null
          : (expandedTaskId ?? this.expandedTaskId),
      confirmingTaskDelete: clearDetail || clearTaskDelete
          ? null
          : (confirmingTaskDelete ?? this.confirmingTaskDelete),
      addTaskFor: clearDetail || clearAddTaskFor ? null : (addTaskFor ?? this.addTaskFor),
      assigningTaskId: clearDetail || clearAssigning
          ? null
          : (assigningTaskId ?? this.assigningTaskId),
      notes: clearDetail ? const {} : (notes ?? this.notes),
      detailProgress: clearDetail ? const [] : (detailProgress ?? this.detailProgress),
      historyTimeline: clearDetail ? false : (historyTimeline ?? this.historyTimeline),
      editingEntryId: clearDetail || clearEditingEntry
          ? null
          : (editingEntryId ?? this.editingEntryId),
      historyNoteEditingId: clearDetail || clearHistoryNoteEditing
          ? null
          : (historyNoteEditingId ?? this.historyNoteEditingId),
      openRevisions: clearDetail ? const {} : (openRevisions ?? this.openRevisions),
      revisions: clearDetail ? const {} : (revisions ?? this.revisions),
      historyNotes: clearDetail ? const {} : (historyNotes ?? this.historyNotes),
      aiHelp: clearDetail ? const AiHelp() : (aiHelp ?? this.aiHelp),
      formOpen: formOpen ?? this.formOpen,
      name: name ?? this.name,
      description: description ?? this.description,
      dueAt: clearDue ? null : (dueAt ?? this.dueAt),
      nameTaken: nameTaken ?? this.nameTaken,
      confirming: confirming ?? this.confirming,
      flash: clearFlash ? '' : (flash ?? this.flash),
    );
  }
}

/// 项目名重名判断、行数据组装、新建与删除都走这里。

/// 同一步内的排序：先 `orderIndex`，再创建时间，最后 id，至少稳定。
int compareTaskOrder(TaskItem a, TaskItem b) {
  final byOrder = a.orderIndex.compareTo(b.orderIndex);
  if (byOrder != 0) return byOrder;
  final byTime = a.createdAt.compareTo(b.createdAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// 待办区要列的那些：挂过步骤、没完成，筛了就只留这一步。
///
/// 不筛的时候几步的事项一起列，先按第几步、再按步内顺序：`orderIndex` 只在
/// 同一步里有意义，跨步直接比它会把第 2 步的第一件插到第 1 步中间去。
List<TaskItem> visibleTasks(List<TaskItem> items, List<Step> steps, int? filterStep) {
  final indexOf = {for (final step in steps) step.id: step.index};
  final shown = items
      .where((item) => !item.done && item.stepId != null)
      .where((item) => filterStep == null || indexOf[item.stepId] == filterStep)
      .toList();
  shown.sort((a, b) {
    final byStep = (indexOf[a.stepId] ?? 0).compareTo(indexOf[b.stepId] ?? 0);
    return byStep != 0 ? byStep : compareTaskOrder(a, b);
  });
  return shown;
}

/// 按 id 找步骤；找不到返回 null（步骤刚被删掉的那种一瞬）。
Step? stepOf(List<Step> steps, String stepId) {
  for (final step in steps) {
    if (step.id == stepId) return step;
  }
  return null;
}

/// 进入详情时默认筛哪一段：正在推进的那一步。
///
/// 项目还没起步（`currentStep` 为 -1）时给第一步，越界收到末位，一步都没有就不筛。
int? filterFor(Project project, int stepCount) {
  if (stepCount <= 0) return null;
  if (project.currentStep < 0) return 0;
  return project.currentStep >= stepCount ? stepCount - 1 : project.currentStep;
}

/// 完成度百分比：四舍五入，没步骤的项目算 0。
///
/// 不用 `ProjectDigest.percent`，那个是向下取整——3 步做完 2 步，
/// 原型显示 67，向下取整会显示 66。
int percentOf(int doneSteps, int totalSteps) {
  if (totalSteps <= 0) return 0;
  final value = (doneSteps * 100 / totalSteps).round();
  if (value < 0) return 0;
  return value > 100 ? 100 : value;
}

/// 下一步做的那件事：未完成待办里排在最小 `orderIndex` 的那条。
///
/// 没有未完成待办时返回空串，卡片上整段留空而不是写「下一步：」。
String nextStepOf(List<TaskItem> items) {
  TaskItem? best;
  for (final item in items) {
    if (item.done) continue;
    if (best == null || item.orderIndex < best.orderIndex) best = item;
  }
  return best?.name ?? '';
}

/// 距今多久，七档；项目卡片的「最近推进」用它。
///
/// 与 B12 的 `relativeDay` 同族但不合并：那个服务创建时间（精确到「刚刚」「3小时前」，
/// 给独立事项行用），这个服务推进时间、只到「今天」这一档，卡片上的字越短越好。
String relativeSince(int? ms, DateTime now) {
  if (ms == null) return '今天';
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return '今天';
  if (days == 1) return '昨天';
  if (days < 7) return '$days 天前';
  if (days < 14) return '一周前';
  if (days < 30) return '${days ~/ 7} 周前';
  final months = days ~/ 30;
  return months <= 1 ? '一个月前' : '$months 个月前';
}

/// 截止日期文案「截止 10 月 30 日」；没填返回空串。
String dueLabel(int? dueAt) {
  if (dueAt == null) return '';
  final at = DateTime.fromMillisecondsSinceEpoch(dueAt);
  return '截止 ${at.month} 月 ${at.day} 日';
}

/// 进度史只按流程顺序：先步骤、同一步内按时间。
///
/// 不按时间倒序：详情读的是「这件事走到哪了」，倒序会把第 1 步的第一次
/// 推进压到第 4 步完成之后，链条就断了。步骤被删后残留的旧下标按数值照排。
List<ProgressEntry> sortProgress(List<ProgressEntry> entries) {
  return [...entries]..sort((a, b) {
    final byStep = a.stepIndex.compareTo(b.stepIndex);
    if (byStep != 0) return byStep;
    final byAt = a.at.compareTo(b.at);
    if (byAt != 0) return byAt;
    return a.id.compareTo(b.id);
  });
}

/// 进度史的时间戳：刚刚 / 今天 HH:mm / 昨天 HH:mm / N 天前 HH:mm / M 月 D 日 HH:mm。
///
/// 日差按本地日历日算：23:59 与次日 00:01 只差两分钟，但那是「昨天」，
/// 用毫秒整除会算成 0 天写成「今天」。
String historyWhen(int atMs, int nowMs) {
  final at = DateTime.fromMillisecondsSinceEpoch(atMs);
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final clock = '${_two(at.hour)}:${_two(at.minute)}';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) {
    if (nowMs - atMs < 60000) return '刚刚';
    return '今天 $clock';
  }
  if (days == 1) return '昨天 $clock';
  if (days < 7) return '$days 天前 $clock';
  return '${at.month} 月 ${at.day} 日 $clock';
}

/// 时间轴的天标题：把 [historyWhen] 里的时刻去掉。
String historyDay(int atMs, int nowMs) {
  final when = historyWhen(atMs, nowMs);
  if (!when.contains(':')) return when;
  return when.substring(0, when.lastIndexOf(' '));
}

String _two(int value) => value.toString().padLeft(2, '0');
