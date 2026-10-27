import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

/// 应用壳。
///
/// `ProviderScope` 在 `main` 里包，这里只管把路由与主题挂上——
/// 这样 widget 测试可以直接 pump 这个组件，不需要先连数据库。
class AiPetApp extends StatefulWidget {
  const AiPetApp({super.key, this.initialLocation});

  /// 直接落到某一页；空着停在「独立事项」。
  final String? initialLocation;

  @override
  State<AiPetApp> createState() => _AiPetAppState();
}

class _AiPetAppState extends State<AiPetApp> {
  /// 路由只建一次：每帧重建会把导航历史冲掉。
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用者 2026-10-26：选截止日期的日历要中文。挂上中文本地化后，
    // showDatePicker 的年月、星期、按钮都跟着变，不必自己画一份日历。
    return MaterialApp.router(
      title: 'AI桌宠日常助手',
      theme: AppTheme.light,
      routerConfig: _router,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
