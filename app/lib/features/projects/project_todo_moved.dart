part of 'project_todo.dart';

/// 从独立事项移进项目、但还没选步骤的那几条。
///
/// 整块只在有这种事项时出现；选了步骤就挂过去，块里的那一条随之消失。
class ProjectMovedSection extends StatelessWidget {
  const ProjectMovedSection({
    super.key,
    required this.tasks,
    required this.steps,
    required this.assigningId,
    required this.onAskAssign,
    required this.onCancelAssign,
    required this.onAssign,
  });

  final List<TaskItem> tasks;
  final List<Step> steps;
  final String? assigningId;
  final ValueChanged<String> onAskAssign;
  final VoidCallback onCancelAssign;
  final void Function(String taskId, String stepId) onAssign;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              key: const ValueKey<String>('moved-head'),
              children: [
                const Text(
                  '从独立事项移入',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                ),
                const Spacer(),
                Text(
                  '${tasks.length} 件',
                  key: const ValueKey<String>('moved-count'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink3),
                ),
              ],
            ),
          ),
          for (final task in tasks) _buildRow(task),
        ],
      ),
    );
  }

  Widget _buildRow(TaskItem task) {
    final assigning = assigningId == task.id;
    return Container(
      key: ValueKey<String>('moved-${task.id}'),
      constraints: const BoxConstraints(minHeight: 72),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 72,
            child: Row(
              children: [
                const SizedBox(width: 32),
                Flexible(
                  flex: 42,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                          if (task.source == TaskSource.moved) ...[
                            const SizedBox(width: 8),
                            _Badge(
                              key: ValueKey<String>('moved-src-${task.id}'),
                              text: '从独立事项移入 · ${_monthDay(task.createdAt)}',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text('未分配步骤', style: TextStyle(fontSize: 12, color: AppTheme.ink3)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppTheme.ink2),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  height: 32,
                  child: OutlinedButton(
                    key: ValueKey<String>('moved-assign-${task.id}'),
                    onPressed: assigning ? onCancelAssign : () => onAskAssign(task.id),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      '选择步骤',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (assigning) _buildPicker(task),
        ],
      ),
    );
  }

  Widget _buildPicker(TaskItem task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Container(
              key: ValueKey<String>('moved-select-${task.id}'),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.line2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: null,
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('选一步', style: TextStyle(fontSize: 12, color: AppTheme.ink3)),
                  icon: const Icon(Icons.expand_more, size: 16),
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink),
                  items: [
                    for (final step in steps)
                      DropdownMenuItem<String>(
                        value: step.id,
                        child: Text(
                          '${step.index + 1} · ${step.name}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onAssign(task.id, value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              key: ValueKey<String>('moved-cancel-${task.id}'),
              onPressed: onCancelAssign,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: AppTheme.ink2,
                side: const BorderSide(color: AppTheme.line2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('取消', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthDay(int at) {
    if (at <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(at);
    return '${date.month}/${date.day}';
  }
}

/// 18 像素的勾选框，完成时主色实底加白勾。
