import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/model/category.dart';
import '../../domain/model/idea.dart';

/// 想法盒里那几种小按钮：新建想法 / 存下 / 删除 / 取消。
///
/// [filled] 是主色的「存下」，[warning] 是变红之后的「确认删除」，
/// 其余都是白底描边的次要按钮；[enabled] 为假时压到半透明且点不动。
class IdeaPillButton extends StatelessWidget {
  const IdeaPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.accent = false,
    this.warning = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  /// 白底主色描边主色字，页头的「新建想法」用它。
  final bool accent;
  final bool warning;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled;
    final strong = filled || warning;
    final background = strong ? (warning ? AppTheme.danger : AppTheme.primary) : Colors.white;
    final borderColor = warning
        ? AppTheme.danger
        : (strong || accent ? AppTheme.primary : AppTheme.line2);
    final textColor = strong ? Colors.white : (accent ? AppTheme.primary : AppTheme.ink2);

    return Opacity(
      opacity: active ? 1 : 0.45,
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: active ? onTap : null,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontMeta,
                fontWeight: strong || accent ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 收起状态的读卡：标题、两行正文、脚注（时间 + 分类标签）。
///
/// 整卡可点进编辑；悬停时描边变深、轻轻浮起来一层阴影。
class IdeaReadCard extends StatefulWidget {
  const IdeaReadCard({
    super.key,
    required this.idea,
    required this.when,
    required this.tag,
    required this.tagged,
    required this.onTap,
  });

  final Idea idea;
  final String when;
  final String tag;
  final bool tagged;
  final VoidCallback onTap;

  @override
  State<IdeaReadCard> createState() => _IdeaReadCardState();
}

class _IdeaReadCardState extends State<IdeaReadCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovering ? AppTheme.cardHoverLine : AppTheme.line),
            boxShadow: _hovering
                ? const [BoxShadow(color: Color(0x0F1E3250), blurRadius: 14, offset: Offset(0, 4))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                idea.title,
                key: ValueKey<String>('ideas-title-${idea.id}'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontCardTitle,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              if (idea.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    idea.body,
                    key: ValueKey<String>('ideas-body-${idea.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontBody,
                      height: 1.7,
                      color: AppTheme.ink2,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    widget.when,
                    key: ValueKey<String>('ideas-when-${idea.id}'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontMeta,
                      color: AppTheme.ink3,
                    ),
                  ),
                  const Spacer(),
                  _IdeaTag(id: idea.id, label: widget.tag, tagged: widget.tagged),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右下角那个小标签：归好类的用主色，没归的用灰的。
class _IdeaTag extends StatelessWidget {
  const _IdeaTag({required this.id, required this.label, required this.tagged});

  final String id;
  final String label;
  final bool tagged;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey<String>('ideas-tag-$id'),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: tagged ? AppTheme.accentSoft : AppTheme.hoverBg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: tagged ? AppTheme.ideaTagBorder : AppTheme.line2),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.fontBadge,
        fontWeight: tagged ? FontWeight.w500 : FontWeight.w400,
        color: tagged ? AppTheme.primary : AppTheme.ink3,
      ),
    ),
  );
}

/// 就地编辑卡：新建也走它（[idea] 为空就是新建）。
///
/// 标题空着时「存下」压灰；分类下拉一直可用，用户自己搬比 AI 那次说了算。
class IdeaEditorCard extends StatefulWidget {
  const IdeaEditorCard({
    super.key,
    this.idea,
    required this.categories,
    required this.hasKey,
    required this.deleteArmed,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  /// 正在改的那条；为空表示新建。
  final Idea? idea;
  final List<Category> categories;
  final bool hasKey;

  /// 「删除」已经点过一次，正等第二次确认。
  final bool deleteArmed;

  final void Function(String title, String body, String? categoryId) onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  State<IdeaEditorCard> createState() => _IdeaEditorCardState();
}

class _IdeaEditorCardState extends State<IdeaEditorCard> {
  late final TextEditingController _title = TextEditingController(text: widget.idea?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: widget.idea?.body ?? '');
  late String? _categoryId = widget.idea?.categoryId;

  bool get _isNew => widget.idea == null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _title.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary),
        boxShadow: const [BoxShadow(color: AppTheme.accentSoft, spreadRadius: 3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey<String>('ideas-editor-title'),
            controller: _title,
            autofocus: true,
            maxLength: 40,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontCardTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
            decoration: _fieldDecoration('想法标题', padded: true),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey<String>('ideas-editor-body'),
            controller: _body,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontBody,
              height: 1.7,
              color: AppTheme.ink,
            ),
            decoration: _fieldDecoration('想到什么写什么，一两句也行', padded: false),
          ),
          const SizedBox(height: 10),
          // 左边下拉与提示合成一组，窄窗口放不下时提示自己换行，别把按钮挤出去。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _categoryPicker(),
                    if (!widget.hasKey)
                      const Text(
                        '未配置 API key，AI 不再自动归类',
                        key: ValueKey<String>('ideas-editor-nokey'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.fontMeta,
                          color: AppTheme.ink3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IdeaPillButton(
                    key: const ValueKey<String>('ideas-save'),
                    label: '存下',
                    filled: true,
                    enabled: canSave,
                    onTap: () =>
                        widget.onSave(_title.text.trim(), _body.text.trim(), _categoryId),
                  ),
                  if (!_isNew) ...[
                    const SizedBox(width: 8),
                    IdeaPillButton(
                      key: const ValueKey<String>('ideas-delete'),
                      label: widget.deleteArmed ? '确认删除' : '删除',
                      warning: widget.deleteArmed,
                      onTap: widget.onDelete,
                    ),
                  ],
                  const SizedBox(width: 8),
                  IdeaPillButton(
                    key: const ValueKey<String>('ideas-cancel'),
                    label: '取消',
                    onTap: widget.onCancel,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 分类下拉：第一项「不分类」用空串占位，出参换回 null。
  Widget _categoryPicker() => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.line2),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const ValueKey<String>('ideas-editor-category'),
        value: _categoryId ?? '',
        isDense: true,
        borderRadius: BorderRadius.circular(8),
        iconSize: 16,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.fontMeta,
          color: AppTheme.ink2,
        ),
        items: [
          const DropdownMenuItem<String>(value: '', child: Text('不分类')),
          for (final category in widget.categories)
            DropdownMenuItem<String>(
              key: ValueKey<String>('ideas-cat-option-${category.id}'),
              value: category.id,
              child: Text(category.name),
            ),
        ],
        onChanged: (value) => setState(() => _categoryId = (value ?? '').isEmpty ? null : value),
      ),
    ),
  );

  InputDecoration _fieldDecoration(String hint, {required bool padded}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: AppTheme.fontBody,
      color: AppTheme.ink3,
    ),
    isDense: true,
    counterText: '',
    contentPadding: padded
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 9)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.line2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.line2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.primary),
    ),
  );
}
