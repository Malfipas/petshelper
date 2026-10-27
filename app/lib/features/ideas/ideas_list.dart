import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'idea_card.dart';
import 'ideas_notifier.dart';

/// 第 7 页右栏：页头（看哪一类、几条、新建）加一串想法卡。
///
/// 新建卡固定摆在列表最上面；正在编辑的那条原位换成编辑卡，不跳位置。
class IdeaList extends ConsumerWidget {
  const IdeaList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ideaBoxProvider);
    final notifier = ref.read(ideaBoxProvider.notifier);
    final visible = state.visible;
    final empty = !state.creating && visible.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                state.title,
                key: const ValueKey<String>('ideas-view-title'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontPageTitle,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                state.countLabel,
                key: const ValueKey<String>('ideas-view-count'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontMeta,
                  color: AppTheme.ink3,
                ),
              ),
              const Spacer(),
              IdeaPillButton(
                key: const ValueKey<String>('ideas-new'),
                label: '新建想法',
                accent: true,
                onTap: notifier.startCreate,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: empty
                ? const _EmptyIdeas()
                : ListView(
                    key: const ValueKey<String>('ideas-list'),
                    padding: const EdgeInsets.only(right: 4),
                    children: [
                      if (state.creating)
                        IdeaEditorCard(
                          key: const ValueKey<String>('ideas-editor-new'),
                          categories: state.categories,
                          hasKey: state.hasKey,
                          deleteArmed: false,
                          onSave: (title, body, categoryId) =>
                              notifier.saveNew(title: title, body: body, categoryId: categoryId),
                          onDelete: notifier.cancelEdit,
                          onCancel: notifier.cancelEdit,
                        ),
                      for (final idea in visible)
                        if (state.editingId == idea.id)
                          IdeaEditorCard(
                            key: ValueKey<String>('ideas-editor-${idea.id}'),
                            idea: idea,
                            categories: state.categories,
                            hasKey: state.hasKey,
                            deleteArmed: state.deleteArmedId == idea.id,
                            onSave: (title, body, categoryId) => notifier.saveEdit(
                              ideaId: idea.id,
                              title: title,
                              body: body,
                              categoryId: categoryId,
                            ),
                            onDelete: () => state.deleteArmedId == idea.id
                                ? notifier.delete(idea.id)
                                : notifier.armDelete(idea.id),
                            onCancel: notifier.cancelEdit,
                          )
                        else
                          IdeaReadCard(
                            key: ValueKey<String>('ideas-card-${idea.id}'),
                            idea: idea,
                            when: ideaWhen(idea.createdAt, state.nowMs),
                            tag: state.tagOf(idea),
                            tagged: state.isTagged(idea),
                            onTap: () => notifier.startEdit(idea.id),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 一条都没有时的空态。某一类下是空的也走它——原型就这一句。
class _EmptyIdeas extends StatelessWidget {
  const _EmptyIdeas();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      key: ValueKey<String>('ideas-empty'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '这里还没有想法',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontCardTitle,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '点右上角「新建想法」记一条',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontBody,
            color: AppTheme.ink3,
          ),
        ),
      ],
    ),
  );
}
