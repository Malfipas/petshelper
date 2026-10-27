import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/model/category.dart';
import 'ideas_notifier.dart';

/// 第 7 页左栏：全部 + 各分类，右侧带条数，悬停或选中时露出「重命名」。
///
/// 条数一律按全部想法算，切到某一类不会把别的类的数字抹掉。
class CategoryColumn extends ConsumerWidget {
  const CategoryColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ideaBoxProvider);
    final notifier = ref.read(ideaBoxProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(right: 18, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '分类',
            key: ValueKey<String>('ideas-cats-title'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontMeta,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink3,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _CategoryRow(
                  key: const ValueKey<String>('ideas-cat-all'),
                  label: '全部',
                  count: state.total,
                  selected: state.viewCategoryId == IdeaBoxState.allCategory,
                  onTap: () => notifier.selectCategory(IdeaBoxState.allCategory),
                ),
                for (final category in state.categories)
                  if (state.renamingCategoryId == category.id)
                    _RenameRow(
                      key: ValueKey<String>('ideas-rename-${category.id}'),
                      category: category,
                    )
                  else
                    _CategoryRow(
                      key: ValueKey<String>('ideas-cat-${category.id}'),
                      label: category.name,
                      count: state.countIn(category.id),
                      selected: state.viewCategoryId == category.id,
                      onTap: () => notifier.selectCategory(category.id),
                      onRename: () => notifier.startRename(category.id),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行分类。选中时左边一条 2px 主色、底是淡蓝、字也变主色。
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onRename,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// 「全部」那一行没有分类可改名，传空。
  final VoidCallback? onRename;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final color = active ? AppTheme.primary : AppTheme.ink2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 34,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.only(left: 10, right: 8),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accentSoft
                : (_hovering ? AppTheme.hoverBg : Colors.transparent),
            border: Border(
              left: BorderSide(color: active ? AppTheme.primary : Colors.transparent, width: 2),
            ),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontBody,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${widget.count}',
                key: ValueKey<String>('ideas-cat-count-${widget.label}'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontMeta,
                  color: active ? AppTheme.primary : AppTheme.ink3,
                ),
              ),
              if (widget.onRename != null)
                Visibility(
                  visible: _hovering || active,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: widget.onRename,
                      child: Text(
                        '重命名',
                        key: ValueKey<String>('ideas-cat-rename-${widget.label}'),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.fontMeta,
                          color: AppTheme.ink3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分类改名：原地变输入框，回车存、Esc 撤。
class _RenameRow extends ConsumerStatefulWidget {
  const _RenameRow({super.key, required this.category});

  final Category category;

  @override
  ConsumerState<_RenameRow> createState() => _RenameRowState();
}

class _RenameRowState extends ConsumerState<_RenameRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.category.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() => ref.read(ideaBoxProvider.notifier).commitRename(_controller.text);

  void _cancel() => ref.read(ideaBoxProvider.notifier).cancelRename();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: SizedBox(
      height: 34,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): _commit,
          const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        },
        child: TextField(
          key: const ValueKey<String>('ideas-rename-input'),
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _commit(),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontBody,
            color: AppTheme.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
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
    ),
  );
}
