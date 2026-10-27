import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/model/ai_attachment.dart';
import '../../domain/model/note.dart';
import '../../domain/model/project_digest.dart';
import '../../domain/model/revision.dart';
import '../../domain/model/step.dart';
import '../../domain/model/task_item.dart';
import '../../domain/port/attachment_picker.dart';
import '../../domain/port/project_planner.dart';
import '../panel/panel_notifier.dart';

import 'project_ai_state.dart';
import 'project_list_state.dart';

export 'project_list_state.dart';

part 'projects_notifier_history.dart';

///
/// 这一页只读不写计时：不碰 `TimerService`，也不改面板的当前事务。
class ProjectListNotifier extends Notifier<ProjectListState> with ProjectHistoryActions {
  ProjectListNotifier({
    DateTime Function()? now,
    this.doneDelay = const Duration(milliseconds: 600),
    this.flashDelay = const Duration(milliseconds: 1200),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// 勾完之后行留在原位多久。原型是 600 毫秒，测试里传零。
  final Duration doneDelay;

  /// 新增之后闪一下多久。
  final Duration flashDelay;

  /// 页面算「最近推进」用的当前时间。走同一条时钟，测试里能固定住。
  @override
  DateTime get now => _now();

  /// 正在等的那一下闪烁；离开页面时得收掉，不然测试会挂着一个没人管的定时器。
  Timer? _flashTimer;

  @override
  ProjectListState build() {
    ref.onDispose(() => _flashTimer?.cancel());
    // 面板那边勾完成、停止都会改待办与进度史，这一页可能正开着同一个项目，
    // 换过当前事务就重读一遍详情，免得进度史停在旧数据上（B16 实机反馈）。
    ref.listen(panelNotifierProvider, (before, after) {
      if (before?.taskId == after.taskId) return;
      unawaited(_refreshDetailQuietly());
    });
    unawaited(reload());
    return const ProjectListState();
  }

  /// 重新读一遍项目与它们的未完成待办，按创建时间倒序排好。
  @override
  Future<void> reload() async {
    final repo = ref.read(projectRepositoryProvider);
    final tasks = ref.read(taskRepositoryProvider);
    final projects = await repo.all();
    final digests = await repo.digests();
    final byId = <String, ProjectDigest>{for (final digest in digests) digest.projectId: digest};

    final rows = <ProjectRow>[];
    for (final project in projects) {
      final digest = byId[project.id];
      final items = await tasks.byProject(project.id);
      rows.add(
        ProjectRow(
          id: project.id,
          name: project.name,
          percent: percentOf(digest?.doneSteps ?? 0, digest?.totalSteps ?? 0),
          nextStep: nextStepOf(items),
          createdAt: project.createdAt,
          lastAdvancedAt: digest?.lastAdvancedAt,
        ),
      );
    }
    // 新建的排最前；同一毫秒建的两个按 id 兜底，顺序至少稳定。
    rows.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });

    if (!ref.mounted) return;
    state = state.copyWith(rows: rows, loading: false);
  }

  /// 展开一个项目；项目已经不在了就静静退回列表。
  ///
  /// 使用者 2026-10-26：项目页任何时候都不许出现「这个项目已经删掉了」那种字，
  /// 所以这里既不给提示，也不留一屏空详情。
  Future<void> open(String id) async {
    final bundle = await ref.read(projectRepositoryProvider).load(id);
    if (!ref.mounted) return;
    if (!bundle.exists) {
      state = state.copyWith(clearOpen: true, clearDetail: true, clearFlash: true);
      await reload();
      return;
    }
    int? lastAdvancedAt;
    for (final row in state.rows) {
      if (row.id == id) {
        lastAdvancedAt = row.lastAdvancedAt;
        break;
      }
    }
    state = state.copyWith(detailLastAdvancedAt: lastAdvancedAt);
    await _applyBundle(id, resetFilter: true);
    if (!ref.mounted) return;
    state = state.copyWith(clearFlash: true);
  }

  /// 回到列表态。
  void back() {
    state = state.copyWith(clearOpen: true, clearDetail: true);
  }

  /// 点某一段：正筛着它就取消，否则筛这一步。
  ///
  /// 待办区跟着筛选走，所以改完筛还要重读一遍列表。
  Future<void> tapSegment(int index) async {
    if (state.filterStep == index) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterStep: index);
    }
    await _refreshTasks();
  }

  /// 清掉筛选，进度条恢复整条，待办区回到全部未完成。
  Future<void> clearFilter() async {
    state = state.copyWith(clearFilter: true);
    await _refreshTasks();
  }

  /// 展开或收起流程编辑器；收起时不动筛选，免得用户以为筛选也一起没了。
  void toggleFlowEdit() => state = state.copyWith(flowEditing: !state.flowEditing);

  /// 改一步的名字。去空格后为空就不动，避免把步骤改成看不见的名字。
  Future<void> renameStep(String stepId, String name) async {
    final id = state.openId;
    final trimmed = name.trim();
    if (id == null || trimmed.isEmpty) return;
    await ref.read(projectRepositoryProvider).renameStep(stepId, trimmed);
    await _applyBundle(id, resetFilter: false);
  }

  /// 与相邻步骤换位。已经在头尾时 Repository 返回 false，界面保持原样。
  Future<void> moveStep(String stepId, int delta) async {
    final id = state.openId;
    if (id == null) return;
    final moved = await ref.read(projectRepositoryProvider).moveStep(stepId, delta);
    if (!ref.mounted || !moved) return;
    // 编号换过之后，筛着的那一段已经是别的步骤了，清掉比留着更不容易误读。
    state = state.copyWith(clearFilter: true);
    await _applyBundle(id, resetFilter: false);
  }

  /// 末尾加一步，默认名「新步骤 N」。
  Future<void> addStep() async {
    final id = state.openId;
    if (id == null) return;
    final name = '新步骤 ${state.detailSteps.length + 1}';
    await ref.read(projectRepositoryProvider).addStep(id, name: name);
    await _applyBundle(id, resetFilter: false);
  }

  /// 删掉一步：编号与筛选都由 Repository 落库后的真实值重算，顺便刷新列表卡片。
  Future<void> deleteStep(String stepId) async {
    final id = state.openId;
    if (id == null) return;
    await ref.read(projectRepositoryProvider).deleteStep(stepId);
    if (!ref.mounted) return;
    await _applyBundle(id, resetFilter: true);
    if (!ref.mounted) return;
    await reload();
  }

  /// 读回展开项目的步骤与进度，`resetFilter` 为真时把筛选落回 `currentStep`。
  Future<void> _applyBundle(String id, {required bool resetFilter}) async {
    final bundle = await ref.read(projectRepositoryProvider).load(id);
    if (!ref.mounted || !bundle.exists) return;
    final project = bundle.project;
    if (project == null) return;
    final steps = [...bundle.steps]..sort((a, b) => a.index.compareTo(b.index));
    final done = steps.where((step) => step.state == StepState.done).length;
    final filter = resetFilter ? filterFor(project, steps.length) : state.filterStep;
    final tasks = await _readTasks(id, steps, filter);
    final progress = sortProgress(bundle.progress);
    final historyNotes = await ref.read(noteRepositoryProvider).textsOf(NoteOwner.history);
    if (!ref.mounted) return;
    state = state.copyWith(
      openId: id,
      detail: project,
      detailSteps: steps,
      detailPercent: percentOf(done, steps.length),
      detailDoneSteps: done,
      detailTotalSteps: steps.length,
      filterStep: filter,
      clearFilter: filter == null,
      detailTasks: tasks.shown,
      movedTasks: tasks.moved,
      notes: tasks.notes,
      detailProgress: progress,
      historyNotes: historyNotes,
    );
  }

  /// 展开或收起新建表单；收起时草稿一起清掉。
  void toggleForm(bool open) {
    if (open) {
      state = state.copyWith(
        formOpen: true,
        clearDue: true,
        name: '',
        description: '',
        nameTaken: false,
      );
    } else {
      state = state.copyWith(
        formOpen: false,
        name: '',
        description: '',
        nameTaken: false,
        clearDue: true,
      );
    }
  }

  void setName(String value) {
    final trimmed = value.trim();
    final taken = trimmed.isNotEmpty && state.rows.any((row) => row.name.trim() == trimmed);
    state = state.copyWith(name: value, nameTaken: taken);
  }

  void setDescription(String value) => state = state.copyWith(description: value);

  void setDue(int? value) => state = state.copyWith(dueAt: value, clearDue: value == null);

  /// 改已存在项目的截止日期。《页面操作流程》第 6 节：「截止日期可以修改（任何时候）」。
  Future<void> setProjectDue(String projectId, int? dueAt) async {
    await ref.read(projectRepositoryProvider).setDueAt(projectId, dueAt);
    await reload();
    await _refreshDetailQuietly();
  }

  /// 建一个新项目：名不能空、不能重名；建成后收起表单并直接进它的详情。
  Future<bool> create() async {
    if (!state.canSubmit) return false;
    final id = await ref
        .read(projectRepositoryProvider)
        .create(
          name: state.name.trim(),
          description: state.description.trim(),
          dueAt: state.dueAt,
          nowMs: _now().millisecondsSinceEpoch,
        );
    if (!ref.mounted) return false;
    state = state.copyWith(
      formOpen: false,
      name: '',
      description: '',
      nameTaken: false,
      clearDue: true,
    );
    await reload();
    await open(id);
    return true;
  }

  void askDelete() => state = state.copyWith(confirming: true);

  void cancelDelete() => state = state.copyWith(confirming: false);

  /// 删掉当前展开的项目，连带它的步骤、待办、流水、随手记与进度史。
  Future<void> confirmDelete() async {
    final id = state.openId;
    if (id == null) return;
    try {
      await ref.read(projectRepositoryProvider).delete(id);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(confirming: false, flash: '删除没成功');
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(confirming: false, clearOpen: true, clearDetail: true);
    await reload();
  }

  /// Esc 的消费顺序：删除弹窗 > 行内新增 > 选步骤 > 流程编辑器 > 详情。
  /// 返回 true 表示这一下被页面吃掉了。
  bool collapse() {
    if (state.confirming) {
      cancelDelete();
      return true;
    }
    if (state.confirmingTaskDelete != null) {
      cancelTaskDelete();
      return true;
    }
    if (state.expandedTaskId != null) {
      state = state.copyWith(clearExpandedTask: true);
      return true;
    }
    if (state.editingEntryId != null) {
      state = state.copyWith(clearEditingEntry: true);
      return true;
    }
    if (state.historyNoteEditingId != null) {
      state = state.copyWith(clearHistoryNoteEditing: true);
      return true;
    }
    if (state.addTaskFor != null) {
      closeAddTask();
      return true;
    }
    if (state.assigningTaskId != null) {
      cancelAssign();
      return true;
    }
    if (state.flowEditing) {
      state = state.copyWith(flowEditing: false);
      return true;
    }
    if (state.openId != null) {
      back();
      return true;
    }
    return false;
  }

  /// 读走一行提示，读完就清，避免下次进页又弹一遍。
  String takeFlash() {
    final text = state.flash;
    if (text.isNotEmpty) state = state.copyWith(clearFlash: true);
    return text;
  }

  /// 读待办与它们的随手记。写完库之后单独刷这一份，不必重读整个 bundle。
  Future<({List<TaskItem> shown, List<TaskItem> moved, Map<String, String> notes})> _readTasks(
    String id,
    List<Step> steps,
    int? filter,
  ) async {
    final items = await ref.read(taskRepositoryProvider).byProject(id);
    final shown = visibleTasks(items, steps, filter);
    final moved = items.where((item) => !item.done && item.stepId == null).toList()
      ..sort(compareTaskOrder);
    final notes = <String, String>{};
    final notesRepo = ref.read(noteRepositoryProvider);
    for (final item in [...shown, ...moved]) {
      final text = await notesRepo.textOf(NoteOwner.task, item.id);
      if (text.isNotEmpty) notes[item.id] = text;
    }
    return (shown: shown, moved: moved, notes: notes);
  }

  /// 只重读待办，筛选取当前状态里的那一段。
  Future<void> _refreshTasks() async {
    final id = state.openId;
    if (id == null) return;
    final data = await _readTasks(id, state.detailSteps, state.filterStep);
    if (!ref.mounted) return;
    state = state.copyWith(detailTasks: data.shown, movedTasks: data.moved, notes: data.notes);
  }

  /// 标记一件要闪一下，到点自动清掉；连续新增两件时只留最后一下。
  void _scheduleFlash(String taskId) {
    _flashTimer?.cancel();
    state = state.copyWith(flashTaskId: taskId);
    _flashTimer = Timer(flashDelay, () {
      if (!ref.mounted || state.flashTaskId != taskId) return;
      state = state.copyWith(clearFlashTask: true);
    });
  }

  /// 勾上一件待办：先在界面上变蓝，600 毫秒后落库（完成、进度史、随手记跟走）再移出。
  Future<void> toggleTaskDone(String taskId) async {
    if (state.pendingDone.contains(taskId)) return;
    state = state.copyWith(pendingDone: {...state.pendingDone, taskId});
    await Future<void>.delayed(doneDelay);
    if (!ref.mounted) return;
    final task = await ref.read(taskRepositoryProvider).byId(taskId);
    if (task != null && !task.done) {
      await ref
          .read(finishTaskProvider)
          .call(taskId: taskId, nowMs: _now().millisecondsSinceEpoch, done: true);
    }
    if (!ref.mounted) return;
    final pending = {...state.pendingDone}..remove(taskId);
    state = state.copyWith(pendingDone: pending);
    // 勾完这一下既要刷待办，也要刷进度史：B16 的时间轴以前得退出重进才看得见。
    await _refreshDetailQuietly();
    await reload();
  }

  /// 重读展开项目的整套详情（待办、进度史、随手记）；没展开就什么都不做。
  Future<void> _refreshDetailQuietly() async {
    final id = state.openId;
    if (id == null) return;
    await _applyBundle(id, resetFilter: false);
  }

  /// 展开或收起某条待办的编辑页；同时只开一条。
  void toggleTaskDetail(String taskId) {
    final same = state.expandedTaskId == taskId;
    state = state.copyWith(
      expandedTaskId: same ? null : taskId,
      clearExpandedTask: same,
    );
  }

  /// 某条待办的随手记；没写过就是空串。
  String noteOf(String taskId) => state.notes[taskId] ?? '';

  /// 从库里现读一次随手记，给编辑页灌初值（列表里缓的那份可能还没读到）。
  Future<String> readNote(String taskId) =>
      ref.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId);

  /// 编辑页里改名或改说明时的自动保存：空名不落库，免得把待办改到看不见。
  Future<void> autoSaveTask(String taskId, {String? name, String? description}) async {
    final repo = ref.read(taskRepositoryProvider);
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) await repo.rename(taskId, trimmed);
    if (description != null) await repo.setDescription(taskId, description.trim());
    if (!ref.mounted) return;
    await _refreshDetailQuietly();
  }

  /// 编辑页「保存」：名字、说明、随手记一起落库。
  Future<void> saveTask(
    String taskId, {
    required String name,
    required String description,
    required String note,
  }) async {
    await autoSaveTask(taskId, name: name, description: description);
    await saveNote(taskId, note);
  }

  /// 点删除：先摆出二次确认，真删由 [confirmTaskDelete] 做。
  void askTaskDelete(String taskId) => state = state.copyWith(confirmingTaskDelete: taskId);

  void cancelTaskDelete() => state = state.copyWith(clearTaskDelete: true);

  /// 删掉一条待办，连带它的流水与随手记；删完收回编辑页。
  ///
  /// 小任务窗口正挂着这一条时一并重读，删掉的事项不能还停在面板上。
  Future<void> confirmTaskDelete() async {
    final taskId = state.confirmingTaskDelete;
    if (taskId == null) return;
    await ref.read(taskRepositoryProvider).delete(taskId);
    await ref.read(noteRepositoryProvider).deleteFor(NoteOwner.task, taskId);
    if (!ref.mounted) return;
    state = state.copyWith(
      clearTaskDelete: true,
      clearExpandedTask: true,
      clearFlashTask: true,
    );
    await _refreshDetailQuietly();
    await reload();
    final panel = ref.read(panelNotifierProvider.notifier);
    if (ref.read(panelNotifierProvider).taskId == taskId) await panel.refresh();
  }

  /// 与同一步里相邻的一条换位。已经在头尾时 Repository 返回 false，界面保持原样。
  Future<void> moveTask(String taskId, int delta) async {
    final moved = await ref.read(taskRepositoryProvider).moveOrder(taskId, delta);
    if (!ref.mounted || !moved) return;
    await _refreshTasks();
    await reload();
  }

  /// 点「开始」：这一件成为面板的当前事务并立刻开表。返回 true 时页面去收主界面。
  ///
  /// 已经有另一件在跑时直接返回 false，连当前事务都不换——只有一只表，
  /// 换过去也开不了，还把面板原来的那件顶掉了。
  Future<bool> startTask(String taskId) async {
    final task = await ref.read(taskRepositoryProvider).byId(taskId);
    if (task == null || task.done) return false;
    final before = ref.read(panelNotifierProvider);
    if (before.running && before.taskId != taskId) return false;
    final panel = ref.read(panelNotifierProvider.notifier);
    await panel.setCurrentTask(taskId);
    await panel.start();
    if (!ref.mounted) return false;
    return ref.read(panelNotifierProvider).running &&
        ref.read(panelNotifierProvider).taskId == taskId;
  }

  /// 给没挂步骤的那条选一步：挂过去并排在末尾，筛选跟着切到该步。
  Future<void> assignStep(String taskId, String stepId) async {
    final id = state.openId;
    if (id == null) return;
    await ref.read(taskRepositoryProvider).assignToStep(taskId: taskId, stepId: stepId);
    if (!ref.mounted) return;
    state = state.copyWith(
      clearAssigning: true,
      filterStep: stepOf(state.detailSteps, stepId)?.index,
    );
    await _refreshTasks();
    await reload();
    if (!ref.mounted) return;
    _scheduleFlash(taskId);
  }

  /// 打开某一步的行内新增。
  void openAddTask(String stepId) => state = state.copyWith(addTaskFor: stepId);

  void closeAddTask() => state = state.copyWith(clearAddTaskFor: true);

  /// 在某一步新增一条待办；内容去空格后为空就不做。
  Future<bool> addTask(String name) async {
    final id = state.openId;
    final stepId = state.addTaskFor;
    final trimmed = name.trim();
    if (id == null || stepId == null || trimmed.isEmpty) return false;
    await ref
        .read(taskRepositoryProvider)
        .addToStep(
          projectId: id,
          stepId: stepId,
          name: trimmed,
          nowMs: _now().millisecondsSinceEpoch,
        );
    if (!ref.mounted) return false;
    state = state.copyWith(
      clearAddTaskFor: true,
      filterStep: stepOf(state.detailSteps, stepId)?.index,
    );
    await _refreshTasks();
    await reload();
    if (!ref.mounted) return false;
    final added = state.detailTasks.isEmpty ? null : state.detailTasks.last.id;
    if (added != null) _scheduleFlash(added);
    return true;
  }

  /// 写随手记，不弹提示；空白等于删掉。
  Future<void> saveNote(String taskId, String text) async {
    await ref
        .read(noteRepositoryProvider)
        .save(NoteOwner.task, taskId, text, _now().millisecondsSinceEpoch);
    if (!ref.mounted) return;
    final notes = {...state.notes};
    if (text.trim().isEmpty) {
      notes.remove(taskId);
    } else {
      notes[taskId] = text.trim();
    }
    state = state.copyWith(notes: notes);
  }

  void askAssign(String taskId) => state = state.copyWith(assigningTaskId: taskId);

  void cancelAssign() => state = state.copyWith(clearAssigning: true);

  // ---- 详情页的 AI 帮助（PRD 第 6 页 588–605 行）----

  /// 展开或收起 AI 帮助。收起不动内容，再展开还能接着改。
  void toggleAiHelp() =>
      state = state.copyWith(aiHelp: state.aiHelp.copyWith(open: !state.aiHelp.open));

  void setAiGoal(String value) =>
      state = state.copyWith(aiHelp: state.aiHelp.copyWith(goal: value));

  /// 挑几张图或几份文本文件，跟这一句目标一起送进模型。
  ///
  /// 被跳过的文件（太大、读不了、类型不认识）不当作失败：能用的先收下，
  /// 原因放进灰色提示里，免得一次拒了整批。
  Future<void> pickAiAttachments() async {
    final help = state.aiHelp;
    if (help.busy || help.remainingSlots <= 0) return;

    final outcome = await ref
        .read(attachmentPickerProvider)
        .pick(remaining: help.remainingSlots);
    if (!ref.mounted) return;

    final current = state.aiHelp;
    switch (outcome) {
      case AttachmentPicked(:final attachments, :final note):
        state = state.copyWith(
          aiHelp: current.copyWith(
            attachments: <AiAttachment>[...current.attachments, ...attachments],
            hint: note,
            error: '',
          ),
        );
      case AttachmentPickCancelled():
        return;
      case AttachmentPickFailed(:final reason):
        state = state.copyWith(aiHelp: current.copyWith(hint: reason));
    }
  }

  /// 移掉一个已选的附件，按文件名认（同名的重复选进来会被这一下一起清掉）。
  void removeAiAttachment(String name) {
    final help = state.aiHelp;
    state = state.copyWith(
      aiHelp: help.copyWith(
        attachments: <AiAttachment>[
          for (final item in help.attachments)
            if (item.name != name) item,
        ],
      ),
    );
  }

  /// 把目标发给模型，等它拆出「步骤 + 每步一件事」。
  ///
  /// 三种不成功都停在卡片里说一句：没 key 引导去设置页，超时/网络失败给一次
  /// 重试，返回不是 JSON 也算失败——绝不把半份结果写进项目。
  Future<void> askAi() async {
    final project = state.detail;
    if (project == null) return;
    final help = state.aiHelp;
    if (help.busy) return;

    final goal = help.goal.trim();
    // 一句话没写、也没带附件，那是还没想好；带了附件就允许空着发。
    if (goal.isEmpty && help.attachments.isEmpty) {
      state = state.copyWith(
        aiHelp: help.copyWith(phase: AiPlanPhase.failed, error: '先写一句要做什么'),
      );
      return;
    }

    state = state.copyWith(
      aiHelp: help.copyWith(
        phase: AiPlanPhase.thinking,
        error: '',
        hint: '',
        applied: false,
      ),
    );
    final outcome = await ref
        .read(projectPlannerProvider)
        .plan(
          projectName: project.name,
          goal: goal,
          attachments: help.attachments,
        );
    if (!ref.mounted) return;

    // 回来时可能已经换了项目或收了卡片，按当下的状态接着写，不覆盖别的改动。
    final current = state.aiHelp;
    switch (outcome) {
      case PlanReady(:final plan):
        state = state.copyWith(
          aiHelp: current.copyWith(
            phase: AiPlanPhase.ready,
            reply: plan.reply,
            steps: plan.steps,
            error: '',
          ),
        );
      case PlanNotConfigured():
        state = state.copyWith(
          aiHelp: current.copyWith(phase: AiPlanPhase.failed, error: '还没配 API key，去设置页填一个'),
        );
      case PlanFailed(:final reason):
        state = state.copyWith(aiHelp: current.copyWith(phase: AiPlanPhase.failed, error: reason));
    }
  }

  /// 把拆出来的步骤与每步事项写进项目，写完重读流程条与待办。
  ///
  /// `applied` 先落再写库：写库失败也不让按钮恢复成可点，避免连点两次写出
  /// 两份重复步骤。
  Future<void> applyAi() async {
    final project = state.detail;
    final help = state.aiHelp;
    if (project == null || !help.canApply) return;

    state = state.copyWith(aiHelp: help.copyWith(applied: true));
    final written = await ref
        .read(projectPlanWriterProvider)
        .applyPlan(
          projectId: project.id,
          steps: help.steps,
          nowMs: now.millisecondsSinceEpoch,
        );
    if (!ref.mounted) return;
    state = state.copyWith(flash: '已加入 $written 个步骤');
    await _applyBundle(project.id, resetFilter: false);
    await _refreshTasks();
  }
}

final projectListProvider = NotifierProvider<ProjectListNotifier, ProjectListState>(
  ProjectListNotifier.new,
);
