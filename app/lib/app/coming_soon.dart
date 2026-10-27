import 'package:flutter/material.dart';

import 'theme.dart';

/// 骨架期的页面占位：只写清这页是什么、哪个任务块来填。
///
/// B12 起逐页换成真内容，最后这个文件会随之删掉，不承担任何业务。
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.pageKey, required this.title, required this.note});

  /// 给页面一个稳定的 Key，导航测试靠它判断「现在停在哪一页」。
  final String pageKey;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ValueKey<String>(pageKey),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: AppTheme.fontPageTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(color: AppTheme.ink3, fontSize: AppTheme.fontMeta),
          ),
        ],
      ),
    );
  }
}
