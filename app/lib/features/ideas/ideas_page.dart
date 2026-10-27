import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'category_column.dart';
import 'ideas_list.dart';
import 'ideas_notifier.dart';

/// 第 7 页「想法盒」：左栏分类、右栏一串想法，就地编辑，不弹窗。
class IdeasPage extends ConsumerStatefulWidget {
  const IdeasPage({super.key});

  @override
  ConsumerState<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends ConsumerState<IdeasPage> {
  @override
  void initState() {
    super.initState();
    // 进页重读一遍：想法也可能在别处（比如事项页）被写进来。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(ideaBoxProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) => const KeyedSubtree(
    key: ValueKey<String>('page-ideas'),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.line)),
            ),
            child: CategoryColumn(),
          ),
        ),
        Expanded(flex: 76, child: IdeaList()),
      ],
    ),
  );
}
