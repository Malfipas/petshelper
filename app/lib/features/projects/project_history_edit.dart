part of 'project_history.dart';

/// 改正文：最小高 62 的多行框，下面是「保存」「取消」。
class _EntryEditor extends StatefulWidget {
  const _EntryEditor({
    required this.id,
    required this.text,
    required this.onSave,
    required this.onCancel,
  });

  final String id;
  final String text;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _flush();
    });
  }

  /// 失焦即保存：改了字直接点到别处时，不该悄悄丢掉。
  void _flush() {
    if (!mounted) return;
    widget.onSave(_controller.text);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: TextField(
              key: ValueKey<String>('hist-editin-${widget.id}'),
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 13, height: 1.6, color: AppTheme.ink),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                border: _border(AppTheme.primary),
                enabledBorder: _border(AppTheme.primary),
                focusedBorder: _border(AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SolidButton(
                key: ValueKey<String>('hist-save-${widget.id}'),
                label: '保存',
                onTap: () => widget.onSave(_controller.text),
              ),
              const SizedBox(width: 8),
              _GhostButton(
                key: ValueKey<String>('hist-cancel-${widget.id}'),
                label: '取消',
                onTap: widget.onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
}

/// 进度史的随手记：没记时一行提示 +「随手记」，记了点开就是「改随手记」。
class _NoteRow extends StatefulWidget {
  const _NoteRow({
    required this.id,
    required this.note,
    required this.editing,
    required this.onBegin,
    required this.onCancel,
    required this.onSave,
  });

  final String id;
  final String note;
  final bool editing;
  final VoidCallback onBegin;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  @override
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.note);
  late final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _NoteRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != oldWidget.note && widget.note != _controller.text) {
      _controller.text = widget.note;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editing) {
      final empty = widget.note.isEmpty;
      return Row(
        key: ValueKey<String>('hist-note-${widget.id}'),
        children: [
          Flexible(
            child: Text(
              empty ? '还没记' : widget.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: empty ? AppTheme.ink3 : AppTheme.ink2),
            ),
          ),
          const SizedBox(width: 10),
          _LinkText(
            key: ValueKey<String>('hist-notebtn-${widget.id}'),
            label: empty ? '随手记' : '改随手记',
            onTap: widget.onBegin,
          ),
        ],
      );
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextField(
              key: ValueKey<String>('hist-notein-${widget.id}'),
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 12, height: 1.5, color: AppTheme.ink),
              decoration: InputDecoration(
                isDense: true,
                hintText: '这一步留下了什么',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.ink3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: Colors.white,
                border: _border(AppTheme.primary),
                enabledBorder: _border(AppTheme.primary),
                focusedBorder: _border(AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SolidButton(
                key: ValueKey<String>('hist-notesave-${widget.id}'),
                label: '保存',
                height: 26,
                onTap: () => widget.onSave(_controller.text),
              ),
              const SizedBox(width: 8),
              _GhostButton(
                key: ValueKey<String>('hist-notecancel-${widget.id}'),
                label: '取消',
                height: 26,
                onTap: widget.onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
}

/// 主色实底的小键：正文保存 28 高，随手记保存 26 高。
class _SolidButton extends StatelessWidget {
  const _SolidButton({super.key, required this.label, required this.onTap, this.height = 28});

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 白底细边的小键。
class _GhostButton extends StatelessWidget {
  const _GhostButton({super.key, required this.label, required this.onTap, this.height = 28});

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line2),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.ink2)),
        ),
      ),
    );
  }
}
