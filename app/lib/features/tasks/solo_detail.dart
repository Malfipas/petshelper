import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/model/task_item.dart';
import 'solo_notifier.dart';

/// 展开在一行下面的详情。
///
/// 名称与说明输入停 600 毫秒自动落一份；随手记只在点「保存」时写回
/// （使用者 2026-10-25 定的口径），所以它另经 `NoteRepository` 异步取初值，
/// 取回来之前是空的，不会把空串当作用户输入。
///
/// 「移到项目」整块去掉了（使用者 2026-10-26 的第 12 条）：独立事项与项目事项
/// 各归各的，搬来搬去的入口一撤，详情里只剩保存与删除。
class SoloDetail extends ConsumerStatefulWidget {
  const SoloDetail({
    super.key,
    required this.task,
    required this.running,
    required this.paused,
    required this.clockLabel,
    required this.onAutoSave,
    required this.onSave,
    required this.onDelete,
    this.loadNote,
    this.showDoneHint = true,
  });

  final TaskItem task;
  final bool running;
  final bool paused;
  final String clockLabel;
  final void Function(String name, String description) onAutoSave;
  final void Function(String name, String description, String note) onSave;
  final VoidCallback onDelete;

  /// 现读随手记初值。项目事项传自己那份，独立事项不传就走列表 Notifier。
  final Future<String> Function(String taskId)? loadNote;

  /// 是否画「已完成，明天自动从列表移出」那句。
  ///
  /// 项目事项走的是「做完就摆下一步」，没有移出这回事，所以传 false。
  final bool showDoneHint;

  @override
  ConsumerState<SoloDetail> createState() => _SoloDetailState();
}

class _SoloDetailState extends ConsumerState<SoloDetail> {
  late final TextEditingController _name = TextEditingController(text: widget.task.name);
  late final TextEditingController _desc = TextEditingController(text: widget.task.description);
  late final TextEditingController _note = TextEditingController();

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNote());
  }

  Future<void> _loadNote() async {
    final loader = widget.loadNote;
    final text = loader != null
        ? await loader(widget.task.id)
        : await ref.read(soloListProvider.notifier).noteOf(widget.task.id);
    if (!mounted) return;
    setState(() => _note.text = text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _desc.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 名称或说明改了：停 600 毫秒落一份，随手记不跟这一趟。
  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      widget.onAutoSave(_name.text, _desc.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DashedLine(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _timelineText(),
                key: const ValueKey<String>('solo-timeline'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.ink3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                height: 38,
                decoration: _fieldBox,
                child: TextField(
                  key: const ValueKey<String>('solo-detail-name'),
                  controller: _name,
                  maxLength: 40,
                  onChanged: _onChanged,
                  style: const TextStyle(fontSize: 14, color: AppTheme.ink),
                  decoration: _fieldDecoration,
                ),
              ),
              Container(
                height: 60,
                margin: const EdgeInsets.only(top: 8),
                decoration: _fieldBox,
                child: TextField(
                  key: const ValueKey<String>('solo-detail-desc'),
                  controller: _desc,
                  maxLines: 2,
                  onChanged: _onChanged,
                  style: const TextStyle(fontSize: 13, height: 1.6, color: AppTheme.ink),
                  decoration: _fieldDecoration.copyWith(hintText: '事项说明'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 4),
                child: Text('随手记', style: TextStyle(fontSize: 11, color: AppTheme.ink3)),
              ),
              Container(
                height: 56,
                decoration: _fieldBox,
                child: TextField(
                  key: const ValueKey<String>('solo-detail-note'),
                  controller: _note,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, height: 1.6, color: AppTheme.ink),
                  decoration: _fieldDecoration.copyWith(hintText: '在此处记录你的成果'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _DetailButton(
                    key: const ValueKey<String>('solo-save'),
                    label: '保存',
                    primary: true,
                    onTap: () => widget.onSave(_name.text, _desc.text, _note.text),
                  ),
                  const SizedBox(width: 10),
                  _DetailButton(
                    key: const ValueKey<String>('solo-delete'),
                    label: '删除',
                    danger: true,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
              if (task.done && widget.showDoneHint)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    '已完成，明天自动从列表移出',
                    style: TextStyle(fontSize: 12, color: AppTheme.ink3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 累计时长精确到秒：使用者 2026-10-26 要求「累计时间显示精确到秒」，
  /// 只写分钟的话刚计时几十秒的条目会一直显示 0 分钟，看不出动过。
  String _timelineText() {
    final total = '累计 ${durationText(widget.task.spentSec)}';
    if (widget.running) return '$total · 正在计时 ${widget.clockLabel}';
    if (widget.paused) return '$total · 已暂停 ${widget.clockLabel}';
    return total;
  }

  /// 输入框内饰。占位文字统一浅灰（[AppTheme.ink3]），与空态、元信息同一档，
  /// 免得提示词看着像已经填进去的内容。
  InputDecoration get _fieldDecoration => const InputDecoration(
    isDense: true,
    counterText: '',
    border: InputBorder.none,
    hintStyle: TextStyle(fontSize: 13, color: AppTheme.ink3),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  BoxDecoration get _fieldBox => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: AppTheme.line2),
    borderRadius: BorderRadius.circular(10),
  );
}

/// 保存 / 删除两枚小键，尺寸对齐原型的 32 高、圆角 10。
class _DetailButton extends StatefulWidget {
  const _DetailButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  State<_DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<_DetailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color borderColor;
    final Color textColor;
    if (widget.primary) {
      background = AppTheme.primary;
      borderColor = AppTheme.primary;
      textColor = Colors.white;
    } else if (widget.danger) {
      background = _hover ? const Color(0xFFFDF2F1) : Colors.white;
      borderColor = const Color(0xFFF0C9C4);
      textColor = AppTheme.danger;
    } else {
      background = Colors.white;
      borderColor = AppTheme.line;
      textColor = AppTheme.ink2;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: widget.primary ? 14 : 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(widget.label, style: TextStyle(fontSize: 13, color: textColor)),
        ),
      ),
    );
  }
}

/// 详情与行头之间那条一像素虚线。
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 1, child: CustomPaint(painter: _DashPainter()));
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.line
      ..strokeWidth = 1;
    const dash = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
