part of 'project_flow.dart';

/// 流程编辑器：一行一步，末尾加一步与完成。
class ProjectFlowEditor extends StatelessWidget {
  const ProjectFlowEditor({
    super.key,
    required this.steps,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    required this.onAdd,
    required this.onDone,
    required this.addingFor,
    required this.onOpenAddTask,
    required this.onCancelAddTask,
    required this.onAddTask,
  });

  final List<Step> steps;
  final void Function(String stepId, String name) onRename;
  final void Function(String stepId, int delta) onMove;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;
  final VoidCallback onDone;

  /// 正在行内新增事项的步骤 id；空表示没有哪一行开着输入。
  final String? addingFor;
  final ValueChanged<String> onOpenAddTask;
  final VoidCallback onCancelAddTask;
  final void Function(String stepId, String name) onAddTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('flow-editor'),
      margin: const EdgeInsets.fromLTRB(2, 10, 2, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              key: ValueKey<String>('flow-row-${steps[i].id}'),
              no: i + 1,
              step: steps[i],
              onRename: onRename,
              onMove: onMove,
              onDelete: onDelete,
              adding: addingFor == steps[i].id,
              onOpenAddTask: () => onOpenAddTask(steps[i].id),
              onCancelAddTask: onCancelAddTask,
              onAddTask: (name) => onAddTask(steps[i].id, name),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DashedButton(onTap: onAdd),
              const Spacer(),
              _DoneButton(onTap: onDone),
            ],
          ),
        ],
      ),
    );
  }
}

/// 编辑器里的一行：序号、名称输入、三枚小键。
class _StepRow extends StatefulWidget {
  const _StepRow({
    super.key,
    required this.no,
    required this.step,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    required this.adding,
    required this.onOpenAddTask,
    required this.onCancelAddTask,
    required this.onAddTask,
  });

  final int no;
  final Step step;
  final void Function(String stepId, String name) onRename;
  final void Function(String stepId, int delta) onMove;
  final ValueChanged<String> onDelete;

  /// 这一行的行内新增是否开着。
  final bool adding;
  final VoidCallback onOpenAddTask;
  final VoidCallback onCancelAddTask;
  final ValueChanged<String> onAddTask;

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.step.name);
    _focus = FocusNode()..addListener(_submitOnBlur);
  }

  @override
  void didUpdateWidget(covariant _StepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 重排或外部改名后名字会变；正在输入的那一行不覆盖，免得打断光标。
    if (!_focus.hasFocus && _controller.text != widget.step.name) {
      _controller.text = widget.step.name;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_submitOnBlur);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitOnBlur() {
    if (!_focus.hasFocus) _submit();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || text == widget.step.name) return;
    widget.onRename(widget.step.id, text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${widget.no}',
                  key: ValueKey<String>('flow-no-${widget.step.id}'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.ink3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    key: ValueKey<String>('flow-name-${widget.step.id}'),
                    controller: _controller,
                    focusNode: _focus,
                    onSubmitted: (_) => _submit(),
                    maxLength: 12,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.ink,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: '步骤名',
                      hintStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.ink3,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.line2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MiniButton(
                buttonKey: ValueKey<String>('flow-up-${widget.step.id}'),
                label: '↑',
                onTap: () => widget.onMove(widget.step.id, -1),
              ),
              const SizedBox(width: 4),
              _MiniButton(
                buttonKey: ValueKey<String>('flow-down-${widget.step.id}'),
                label: '↓',
                onTap: () => widget.onMove(widget.step.id, 1),
              ),
              const SizedBox(width: 4),
              _MiniButton(
                buttonKey: ValueKey<String>('flow-del-${widget.step.id}'),
                label: '删除',
                onTap: () => widget.onDelete(widget.step.id),
              ),
              const SizedBox(width: 4),
              _MiniButton(
                buttonKey: ValueKey<String>('flow-todo-${widget.step.id}'),
                label: '＋',
                onTap: widget.onOpenAddTask,
              ),
            ],
          ),
        ),
        if (widget.adding)
          _AddTaskRow(
            key: ValueKey<String>('flow-addrow-${widget.step.id}'),
            stepId: widget.step.id,
            onSubmit: widget.onAddTask,
            onCancel: widget.onCancelAddTask,
          ),
      ],
    );
  }
}

/// 行尾的 ↑ / ↓ / 删除：高 28、最小宽 28、左右 8、12 号，悬停变主色。
class _MiniButton extends StatefulWidget {
  const _MiniButton({required this.buttonKey, required this.label, required this.onTap});

  final Key buttonKey;
  final String label;
  final VoidCallback onTap;

  @override
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? AppTheme.primary : AppTheme.ink2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: widget.buttonKey,
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? AppTheme.primary : AppTheme.line2),
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: color),
          ),
        ),
      ),
    );
  }
}

/// 这一行下面的行内新增：输入高 30、添加 28 主色实底、取消 28 白底边。
class _AddTaskRow extends StatefulWidget {
  const _AddTaskRow({
    super.key,
    required this.stepId,
    required this.onSubmit,
    required this.onCancel,
  });

  final String stepId;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_AddTaskRow> createState() => _AddTaskRowState();
}

class _AddTaskRowState extends State<_AddTaskRow> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 2, 0, 8),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel},
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextField(
                  key: ValueKey<String>('flow-todo-name-${widget.stepId}'),
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLength: 40,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: '这一步要做的事',
                    hintStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.ink3,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.line2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final enabled = value.text.trim().isNotEmpty;
                return Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: GestureDetector(
                    key: ValueKey<String>('flow-todo-ok-${widget.stepId}'),
                    onTap: enabled ? _submit : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '添加',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: ValueKey<String>('flow-todo-cancel-${widget.stepId}'),
              onTap: widget.onCancel,
              child: Container(
                constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.line2),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.ink2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「＋ 加一步」：高 30、左右 12、主色字、一像素虚线边。
class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('flow-add'),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: const Text(
            '＋ 加一步',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 虚线描边：原型是 `1px dashed`，Flutter 没有现成虚线边，这里按 4/3 的节奏画。
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.line2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 4;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + 3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

/// 「完成」：高 30、左右 14、12 号白字、主色实底、圆角 8。
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('flow-done'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
        child: const Text(
          '完成',
          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: Colors.white),
        ),
      ),
    );
  }
}

/// 一段与提示行共用的文案：「第 N 步 · 名」，名空时写「未命名步骤」。
String segmentLabel(int index, String name) {
  final trimmed = name.trim();
  return '第 ${index + 1} 步 · ${trimmed.isEmpty ? '未命名步骤' : trimmed}';
}
