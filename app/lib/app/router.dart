import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/ideas/ideas_page.dart';
import '../features/panel/panel_page.dart';
import '../features/pet/pet_page.dart';
import '../features/projects/projects_page.dart';
import '../features/records/records_page.dart';
import '../features/settings/settings_page.dart';
import '../features/tasks/solo_page.dart';
import 'main_shell.dart';
import 'routes.dart';

/// 路由表：常驻态、悬停面板、主界面五页。
///
/// [initialLocation] 传空时停在「独立事项」；传某一页地址就直接落过去，
/// 这条是 B05 的完成判定之一，也是将来气泡「查看」跳转的实现方式。
GoRouter buildRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? MainTab.solo.path,
    routes: [
      GoRoute(
        path: AppRoutes.pet,
        // 跳转落点由路由表给：features 不 import main_shell，也不写死 '/main/xxx'。
        // 截止气泡的「查看」要落到那一个项目，项目详情页在 B13 落地；
        // 现在先把 id 带到项目页地址上，等详情页接上时不必再改这里。
        builder: (context, state) => PetPage(
          onOpenMain: () => context.go(MainTab.solo.path),
          onViewProject: (projectId) => context.go('${MainTab.projects.path}?id=$projectId'),
          onOpenProjects: () => context.go(MainTab.projects.path),
          onOpenSettings: () => context.go(MainTab.settings.path),
        ),
      ),
      GoRoute(
        path: AppRoutes.panel,
        // 面板本身住在常驻窗口的一档里，这里单独成页是为了让地址能直达；
        // key 挂在外面，免得面板内容里的结构变化影响「这一页在不在」的判断。
        builder: (context, state) =>
            const KeyedSubtree(key: ValueKey<String>('page-panel'), child: PanelPage()),
      ),
      for (final tab in MainTab.values)
        GoRoute(
          path: tab.path,
          // 项目页认 `?id=`：悬停面板「查看」与截止气泡都靠它落到那一个项目。
          builder: (context, state) =>
              MainShell(tab: tab, child: _pageOf(tab, state.uri.queryParameters['id'])),
        ),
    ],
    // 走到不认识的地址时不白屏，退回独立事项。
    errorBuilder: (context, state) => const MainShell(tab: MainTab.solo, child: SoloPage()),
  );
}

/// 标签对应的页面。B12 起逐页换成真内容，壳不用跟着改。
Widget _pageOf(MainTab tab, String? projectId) => switch (tab) {
  MainTab.solo => const SoloPage(),
  MainTab.projects => ProjectsPage(projectId: projectId),
  MainTab.records => const RecordsPage(),
  MainTab.ideas => const IdeasPage(),
  MainTab.settings => const SettingsPage(),
};
