import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/confirm_overlay.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../domain/model/project.dart';
import '../../domain/model/task_item.dart';
import '../panel/panel_notifier.dart';
import '../pet/pet_notifier.dart';
import '../tasks/solo_detail.dart';
import 'project_ai_help.dart';
import 'project_card.dart';
import 'project_confirm.dart';
import 'project_detail.dart';
import 'project_flow.dart';
import 'project_form.dart';
import 'project_history.dart';
import 'project_todo.dart';
import 'project_widgets.dart';
import 'projects_notifier.dart';

/// 第 6 页 · 我的项目。B13 做列表态、新建、详情头部与删除，
/// 流程条、待办卡片与进度史分别由 B14、B15、B16 往下接。
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key, this.projectId});

  /// 地址上带 `?id=` 时直接展开这个项目（悬停面板「查看」与截止气泡的落点）。
  final String? projectId;

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  @override
  void initState() {
    super.initState();
    _openFromRoute(widget.projectId);
  }

  @override
  void didUpdateWidget(covariant ProjectsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 从面板「查看」再点另一个项目时，路由只换 query，页面 State 被复用，
    // 光靠 initState 不会重跑，所以 id 一变就再展开一次。
    if (widget.projectId != oldWidget.projectId) {
      _openFromRoute(widget.projectId);
    }
  }

  /// 地址上带 `?id=` 就把那个项目展开；id 失效时由 Notifier 退回列表并给提示。
  /// 第一帧还没建好列表，展开要等列表就位，否则详情里的「最近推进」拿不到行数据。
  void _openFromRoute(String? id) {
    if (id == null || id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(projectListProvider.notifier).open(id);
    });
  }

  void _toggleForm(bool open) => ref.read(projectListProvider.notifier).toggleForm(open);

  Future<void> _create() async {
    await ref.read(projectListProvider.notifier).create();
  }

  Future<void> _pickDue() async {
    final dueAt = ref.read(projectListProvider).dueAt;
    final now = ref.read(projectListProvider.notifier).now;
    final picked = await showDatePicker(
      context: context,
      initialDate: dueAt == null ? now : DateTime.fromMillisecondsSinceEpoch(dueAt),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    ref
        .read(projectListProvider.notifier)
        .setDue(DateTime(picked.year, picked.month, picked.day).millisecondsSinceEpoch);
  }

  /// 详情里改截止日期：挑完立刻写回，任何时候都能改。
  Future<void> _pickDetailDue(Project project) async {
    final now = ref.read(projectListProvider.notifier).now;
    final picked = await showDatePicker(
      context: context,
      initialDate: project.dueAt == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(project.dueAt!),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(projectListProvider.notifier)
        .setProjectDue(
          project.id,
          DateTime(picked.year, picked.month, picked.day).millisecondsSinceEpoch,
        );
  }

  /// 点项目名右侧的标记键：首个未完成事项摆进面板，不开始计时。
  Future<void> _markProject(String projectId) async {
    final ok = await ref.read(panelNotifierProvider.notifier).markProject(projectId);
    if (!ok || !mounted) return;
    ref.read(petNotifierProvider.notifier).openPanel();
    context.go(AppRoutes.pet);
  }

  /// 点待办的「开始」：这一件交给面板计时，成功后收主界面、把面板摆出来。
  /// 开表失败（另一件正在跑、这条刚被勾掉）就原地不动，不跳走。
  Future<void> _startTask(String taskId) async {
    final ok = await ref.read(projectListProvider.notifier).startTask(taskId);
    if (!ok || !mounted) return;
    ref.read(petNotifierProvider.notifier).openPanel();
    context.go(AppRoutes.pet);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);
    // 相对日期走 Notifier 的时钟，测试里固定得住，不会因为跨天翻成「昨天」。
    final now = ref.read(projectListProvider.notifier).now;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProjectHeader(
          count: state.rows.length,
          flash: state.flash,
          formOpen: state.formOpen,
          onNew: () => _toggleForm(!state.formOpen),
        ),
        if (state.formOpen)
          ProjectForm(
            state: state,
            onName: ref.read(projectListProvider.notifier).setName,
            onDescription: ref.read(projectListProvider.notifier).setDescription,
            onPickDue: _pickDue,
            onCancel: () => _toggleForm(false),
            onSubmit: _create,
          ),
        Expanded(
          child: state.openId != null && state.detail != null
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProjectDetailHeader(
                        project: state.detail!,
                        percent: state.detailPercent,
                        doneSteps: state.detailDoneSteps,
                        totalSteps: state.detailTotalSteps,
                        lastAdvancedAt: state.detailLastAdvancedAt,
                        now: now,
                        onBack: ref.read(projectListProvider.notifier).back,
                        onDelete: ref.read(projectListProvider.notifier).askDelete,
                        onPickDue: () => unawaited(_pickDetailDue(state.detail!)),
                      ),
                      ProjectFlowBar(
                        steps: state.detailSteps,
                        filterStep: state.filterStep,
                        flowEditing: state.flowEditing,
                        onTapSegment: ref.read(projectListProvider.notifier).tapSegment,
                        onToggleEdit: ref.read(projectListProvider.notifier).toggleFlowEdit,
                      ),
                      if (_filterLabel(state) != null)
                        ProjectFilterTip(
                          label: _filterLabel(state)!,
                          onClear: ref.read(projectListProvider.notifier).clearFilter,
                        ),
                      if (state.flowEditing)
                        ProjectFlowEditor(
                          steps: state.detailSteps,
                          onRename: ref.read(projectListProvider.notifier).renameStep,
                          onMove: ref.read(projectListProvider.notifier).moveStep,
                          onDelete: ref.read(projectListProvider.notifier).deleteStep,
                          onAdd: ref.read(projectListProvider.notifier).addStep,
                          onDone: ref.read(projectListProvider.notifier).toggleFlowEdit,
                          addingFor: state.addTaskFor,
                          onOpenAddTask: ref.read(projectListProvider.notifier).openAddTask,
                          onCancelAddTask: ref.read(projectListProvider.notifier).closeAddTask,
                          onAddTask: (_, name) =>
                              ref.read(projectListProvider.notifier).addTask(name),
                        ),
                      ProjectAiHelp(
                        help: state.aiHelp,
                        onToggle: ref.read(projectListProvider.notifier).toggleAiHelp,
                        onGoalChanged: ref.read(projectListProvider.notifier).setAiGoal,
                        onAsk: ref.read(projectListProvider.notifier).askAi,
                        onApply: ref.read(projectListProvider.notifier).applyAi,
                        onPickAttachments:
                            ref.read(projectListProvider.notifier).pickAiAttachments,
                        onRemoveAttachment:
                            ref.read(projectListProvider.notifier).removeAiAttachment,
                      ),
                      ProjectTodoSection(
                        tasks: state.detailTasks,
                        steps: state.detailSteps,
                        currentStep: state.detail?.currentStep ?? -1,
                        pendingDone: state.pendingDone,
                        flashTaskId: state.flashTaskId,
                        expandedTaskId: state.expandedTaskId,
                        onToggle: ref.read(projectListProvider.notifier).toggleTaskDone,
                        onMove: ref.read(projectListProvider.notifier).moveTask,
                        onStart: _startTask,
                        onToggleDetail:
                            ref.read(projectListProvider.notifier).toggleTaskDetail,
                        detailOf: (task) => _taskDetail(task, state),
                      ),
                      ProjectMovedSection(
                        tasks: state.movedTasks,
                        steps: state.detailSteps,
                        assigningId: state.assigningTaskId,
                        onAskAssign: ref.read(projectListProvider.notifier).askAssign,
                        onCancelAssign: ref.read(projectListProvider.notifier).cancelAssign,
                        onAssign: ref.read(projectListProvider.notifier).assignStep,
                      ),
                      ProjectHistorySection(
                        entries: state.detailProgress,
                        notes: state.historyNotes,
                        nowMs: now.millisecondsSinceEpoch,
                        timeline: state.historyTimeline,
                        editingEntryId: state.editingEntryId,
                        noteEditingId: state.historyNoteEditingId,
                        openRevisions: state.openRevisions,
                        revisions: state.revisions,
                        onToggleAxis: ref.read(projectListProvider.notifier).toggleHistoryAxis,
                        onBeginEdit: ref.read(projectListProvider.notifier).beginEditEntry,
                        onCancelEdit: ref.read(projectListProvider.notifier).cancelEditEntry,
                        onSaveEntry: ref.read(projectListProvider.notifier).saveEntry,
                        onToggleRevisions: ref.read(projectListProvider.notifier).toggleRevisions,
                        onBeginNote: ref.read(projectListProvider.notifier).beginHistoryNote,
                        onCancelNote: ref.read(projectListProvider.notifier).cancelHistoryNote,
                        onSaveNote: ref.read(projectListProvider.notifier).saveHistoryNote,
                      ),
                    ],
                  ),
                )
              : _buildList(state, now),
        ),
      ],
    );

    final deleting = _taskOf(state, state.confirmingTaskDelete);
    return KeyedSubtree(
      key: const ValueKey<String>('page-projects'),
      child: Stack(
        children: [
          Positioned.fill(child: body),
          if (state.confirming)
            ProjectConfirmDialog(
              projectName: state.detail?.name ?? '',
              onCancel: ref.read(projectListProvider.notifier).cancelDelete,
              onConfirm: ref.read(projectListProvider.notifier).confirmDelete,
            ),
          if (deleting != null)
            Positioned.fill(
              child: ConfirmOverlay(
                title: '删除「${deleting.name}」？',
                message: '相关数据将不会被保留',
                onCancel: ref.read(projectListProvider.notifier).cancelTaskDelete,
                onConfirm: ref.read(projectListProvider.notifier).confirmTaskDelete,
              ),
            ),
        ],
      ),
    );
  }

  /// 项目事项的编辑页：与独立事项同一块 [SoloDetail]，只是不画「明天移出」那句。
  ///
  /// 随手记、计时、面板里的 AI 帮助都是同一套逻辑（使用者 2026-10-26 的第 11 条），
  /// 差别只有一条：项目事项做完就摆下一步，没有「移出列表」这回事。
  Widget _taskDetail(TaskItem task, ProjectListState state) {
    final panel = ref.watch(panelNotifierProvider);
    final mine = panel.taskId == task.id;
    final running = mine && panel.running && !panel.paused;
    final paused = mine && panel.running && panel.paused;
    final notifier = ref.read(projectListProvider.notifier);
    return SoloDetail(
      key: ValueKey<String>('todo-detail-${task.id}'),
      task: task,
      running: running,
      paused: paused,
      clockLabel: panel.clockLabel,
      showDoneHint: false,
      loadNote: notifier.readNote,
      onAutoSave: (name, description) =>
          notifier.autoSaveTask(task.id, name: name, description: description),
      onSave: (name, description, note) => notifier.saveTask(
        task.id,
        name: name,
        description: description,
        note: note,
      ),
      onDelete: () => notifier.askTaskDelete(task.id),
    );
  }

  TaskItem? _taskOf(ProjectListState state, String? id) {
    if (id == null) return null;
    for (final task in state.detailTasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// 筛选提示行的文案；没筛或筛到已删掉的段时返回 null。
  String? _filterLabel(ProjectListState state) {
    final index = state.filterStep;
    if (index == null || index < 0 || index >= state.detailSteps.length) return null;
    return segmentLabel(index, state.detailSteps[index].name);
  }

  /// 列表态：空列表只说一句话，入口留在顶上那枚「新建项目」。
  ///
  /// 使用者 2026-10-26：空态正中那枚按钮撤掉，免得一屏两个同样的入口。
  Widget _buildList(ProjectListState state, DateTime now) {
    if (state.rows.isEmpty && !state.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text(
            '还没有项目',
            key: ValueKey<String>('proj-empty'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink2,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final row in state.rows)
          ProjectCard(
            row: row,
            now: now,
            onTap: () => ref.read(projectListProvider.notifier).open(row.id),
            onMark: () => unawaited(_markProject(row.id)),
          ),
      ],
    );
  }
}
