import 'package:flutter/material.dart' hide Step;

import '../../app/theme.dart';
import '../../domain/model/step.dart';
import '../../domain/model/task_item.dart';

part 'project_todo_moved.dart';

/// 一条待办卡片。与第 4 页的事项卡同款，区别是元信息里带了步骤、右侧多了 ↑↓。
///
/// 勾选之后这一行还留着 600 毫秒（`done` 为真时画完成态），落库与移出都由
/// `ProjectListNotifier` 管；这里只负责把「刚点的那一下」立刻画出来。
class ProjectTodoRow extends StatefulWidget {
  const ProjectTodoRow({
    super.key,
    required this.task,
    required this.stepNumber,
    required this.stepName,
    required this.isNext,
    required this.done,
    required this.flash,
    required this.open,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onStart,
    required this.onTapHead,
    required this.detail,
  });

  final TaskItem task;

  /// 步骤序号，从 1 数。
  final int stepNumber;
  final String stepName;

  /// 是不是「下一步」那一格的事项。
  final bool isNext;

  /// 已经在 600 毫秒等待里：立刻画成完成态。
  final bool done;

  /// 刚新增：闪一下。
  final bool flash;

  /// 编辑页是否展开。
  final bool open;

  final VoidCallback onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onStart;

  /// 点行头（名称那一块）展开或收起编辑页。
  final VoidCallback onTapHead;

  /// 展开时才有的编辑页；收起时是 null。
  final Widget? detail;

  @override
  State<ProjectTodoRow> createState() => _ProjectTodoRowState();
}

class _ProjectTodoRowState extends State<ProjectTodoRow> {
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    if (widget.flash) _scrollIntoView();
  }

  @override
  void didUpdateWidget(covariant ProjectTodoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 刚新增的那条可能落在滚动区外面，闪起来的同时把它带进视野。
    if (widget.flash && !oldWidget.flash) _scrollIntoView();
  }

  void _scrollIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final done = widget.done || task.done;
    final border = widget.flash
        ? const Color(0xFFCFDCFB)
        : (_hover ? AppTheme.line : AppTheme.line2);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: ValueKey<String>('todo-${task.id}'),
        constraints: const BoxConstraints(minHeight: 72),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: widget.flash ? AppTheme.accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CheckBox(done: done, onTap: widget.onToggle, id: task.id),
                  const SizedBox(width: 14),
                  Flexible(
                    flex: 42,
                    child: GestureDetector(
                      key: ValueKey<String>('todo-head-${task.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTapHead,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (widget.isNext) ...[
                                  _Badge(
                                    key: ValueKey<String>('todo-next-${task.id}'),
                                    text: '下一步',
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    task.name,
                                    key: ValueKey<String>('todo-name-${task.id}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: done ? AppTheme.ink3 : AppTheme.ink,
                                      decoration: done ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _metaText(),
                              key: ValueKey<String>('todo-meta-${task.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.ink3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 58,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.description,
                            key: ValueKey<String>('todo-desc-${task.id}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppTheme.ink2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GoButton(id: task.id, onTap: widget.onStart),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MiniMove(id: task.id, up: true, onTap: widget.onMoveUp),
                            const SizedBox(height: 4),
                            _MiniMove(id: task.id, up: false, onTap: widget.onMoveDown),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.detail != null) widget.detail!,
          ],
        ),
      ),
    );
  }

  String _metaText() {
    final head = '第 ${widget.stepNumber} 步 · ${widget.stepName}';
    final spent = widget.task.spentSec;
    if (spent <= 0) return head;
    final minutes = (spent / 60).ceil();
    return '$head · 已做 $minutes 分钟';
  }
}

/// 待办区的整摞卡片：筛过、只留未完成的事项，一条一卡。
///
/// 步骤对不上号的那种一瞬脏数据直接跳过，不让一行把整块打挂。
class ProjectTodoSection extends StatelessWidget {
  const ProjectTodoSection({
    super.key,
    required this.tasks,
    required this.steps,
    required this.currentStep,
    required this.pendingDone,
    required this.flashTaskId,
    required this.expandedTaskId,
    required this.onToggle,
    required this.onMove,
    required this.onStart,
    required this.onToggleDetail,
    required this.detailOf,
  });

  final List<TaskItem> tasks;
  final List<Step> steps;

  /// 项目正在推进的那一步（`Project.currentStep`）；-1 表示还没起步。
  final int currentStep;

  /// 勾完还在 600 毫秒等待里的那些，先画成完成态。
  final Set<String> pendingDone;

  /// 新增之后要闪一下的那一条。
  final String? flashTaskId;

  /// 正展开编辑页的那一条；null 表示都收着。
  final String? expandedTaskId;

  final ValueChanged<String> onToggle;
  final void Function(String taskId, int delta) onMove;
  final ValueChanged<String> onStart;
  final ValueChanged<String> onToggleDetail;

  /// 展开某一条时给它的编辑页；收起状态下不会调用。
  final Widget Function(TaskItem task)? detailOf;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (final task in tasks) {
      final step = _stepOf(task.stepId);
      if (step == null) continue;
      final open = expandedTaskId == task.id;
      rows.add(
        ProjectTodoRow(
          key: ValueKey<String>('todo-row-${task.id}'),
          task: task,
          stepNumber: step.index + 1,
          stepName: step.name,
          isNext: step.index == currentStep,
          done: pendingDone.contains(task.id),
          flash: flashTaskId == task.id,
          open: open,
          onToggle: () => onToggle(task.id),
          onMoveUp: () => onMove(task.id, -1),
          onMoveDown: () => onMove(task.id, 1),
          onStart: () => onStart(task.id),
          onTapHead: () => onToggleDetail(task.id),
          detail: open ? detailOf?.call(task) : null,
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Step? _stepOf(String? stepId) {
    if (stepId == null) return null;
    for (final step in steps) {
      if (step.id == stepId) return step;
    }
    return null;
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.done, required this.onTap, required this.id});

  final bool done;
  final VoidCallback onTap;
  final String id;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('todo-check-$id'),
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: done ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: done ? AppTheme.primary : AppTheme.line, width: 2),
        ),
        child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
      ),
    );
  }
}

/// 11 号的小角标：「下一步」与来源。
class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: AppTheme.accentSoft, borderRadius: BorderRadius.circular(6)),
      child: Text(text, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
    );
  }
}

/// 卡片右侧的「开始」。
class _GoButton extends StatelessWidget {
  const _GoButton({required this.id, required this.onTap});

  final String id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 32,
      child: OutlinedButton(
        key: ValueKey<String>('todo-start-$id'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: AppTheme.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppTheme.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('开始', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// 24 像素的 ↑ / ↓。
class _MiniMove extends StatelessWidget {
  const _MiniMove({required this.id, required this.up, required this.onTap});

  final String id;
  final bool up;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: TextButton(
        key: ValueKey<String>('todo-${up ? 'up' : 'down'}-$id'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(24, 24),
          foregroundColor: AppTheme.ink3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(up ? '↑' : '↓', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
