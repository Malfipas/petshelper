import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'day_texts.dart';

/// 原型 `.note-empty` 的底：比白再淡一点，和卡片背景分得开。
const Color _noteBg = Color(0xFFFAFBFE);

/// 一条事项展开后那段 AI 总结：四态正文 + 一个「编辑」/「写总结」。
///
/// 判定已由 [EntrySummary] 做好，这里只负责画与收字；存到哪由上层决定。
class SummaryBlock extends StatefulWidget {
  const SummaryBlock({super.key, required this.summary, required this.onSave});

  final EntrySummary summary;

  /// 我改完后要存的那一版（已 trim，可能是空串表示清掉）。
  final ValueChanged<String> onSave;

  @override
  State<SummaryBlock> createState() => _SummaryBlockState();
}

class _SummaryBlockState extends State<SummaryBlock> {
  bool _editing = false;

  void _startEdit() => setState(() => _editing = true);

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _InlineEditor(
          initial: widget.summary.text,
          onSave: (text) {
            setState(() => _editing = false);
            widget.onSave(text);
          },
          onCancel: () => setState(() => _editing = false),
        ),
      );
    }

    final summary = widget.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!summary.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              summary.text,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontBody,
                height: 1.7,
                color: AppTheme.ink2,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SmallButton(
              label: summary.actionLabel,
              onTap: _startEdit,
            ),
          ),
        ),
      ],
    );
  }
}

/// 展开区下方那块「我的感想」。
///
/// 没写过就是虚线框，点开写；写过是一行主色竖线加正文，可改可删。
class ThoughtBlock extends StatefulWidget {
  const ThoughtBlock({super.key, required this.text, required this.onSave});

  final String text;

  /// 存这一版（空串表示删掉）。
  final ValueChanged<String> onSave;

  @override
  State<ThoughtBlock> createState() => _ThoughtBlockState();
}

class _ThoughtBlockState extends State<ThoughtBlock> {
  bool _editing = false;

  void _edit() => setState(() => _editing = true);

  void _delete() => widget.onSave('');

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _InlineEditor(
          initial: widget.text,
          onSave: (text) {
            setState(() => _editing = false);
            widget.onSave(text);
          },
          onCancel: () => setState(() => _editing = false),
        ),
      );
    }

    final text = widget.text.trim();
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _DashedBox(
          onTap: _edit,
          child: const Text(
            '今天收获了什么？',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontMeta,
              color: AppTheme.ink3,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.primary, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontBody,
                height: 1.7,
                color: AppTheme.ink,
              ),
            ),
            Row(
              children: [
                _TinyButton(label: '编辑', onTap: _edit),
                const SizedBox(width: 8),
                _TinyButton(label: '删除', onTap: _delete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 编辑态那一套：输入框、保存取消、Ctrl+Enter 与 Esc。
///
/// 感想与总结共用，行为只此一份——两处都要求「失焦或 Ctrl+Enter 保存」。
class _InlineEditor extends StatefulWidget {
  const _InlineEditor({
    required this.initial,
    required this.onSave,
    required this.onCancel,
  });

  final String initial;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<_InlineEditor> createState() => _InlineEditorState();
}

class _InlineEditorState extends State<_InlineEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  late final FocusNode _focus = FocusNode();

  /// 点「取消」会先失焦，用它挡住那一次自动保存。
  bool _closing = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus || _done || _closing) return;
    // 原型第五页也是这样等一拍：取消按钮的 onPressed 排在失焦之后。
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted || _done || _closing || _focus.hasFocus) return;
      _commit();
    });
  }

  void _commit() {
    _done = true;
    widget.onSave(_controller.text.trim());
  }

  void _cancel() {
    _closing = true;
    _done = true;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter, control: true): _commit,
            const SingleActivator(LogicalKeyboardKey.escape): _cancel,
          },
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            maxLines: null,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontBody,
              height: 1.6,
              color: AppTheme.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _SmallButton(label: '保存', filled: true, onTap: _commit),
              const SizedBox(width: 8),
              _SmallButton(label: '取消', onTap: _cancel),
              const SizedBox(width: 8),
              const Text(
                'Ctrl+Enter 保存',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontBadge,
                  color: AppTheme.ink3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 高 24 的小按钮：总结那个「编辑」/「写总结」、编辑态的「保存」「取消」。
class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: filled ? AppTheme.primary : Colors.white,
        foregroundColor: filled ? Colors.white : AppTheme.primary,
        minimumSize: const Size(0, 24),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: filled ? AppTheme.primary : AppTheme.line2),
        ),
        textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: AppTheme.fontBadge),
      ),
      child: Text(label),
    );
  }
}

/// 感想下面那两个「编辑」「删除」：11 号灰字，没有边框。
class _TinyButton extends StatelessWidget {
  const _TinyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.ink3,
        minimumSize: const Size(0, 22),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: AppTheme.fontBadge),
      ),
      child: Text(label),
    );
  }
}

/// 虚线框：原型 `1px dashed var(--line2)`，Flutter 没有现成虚线边，按 4/3 的节奏画。
class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _noteBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

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
