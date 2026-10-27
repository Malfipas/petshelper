import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/pet_window_launcher.dart';
import 'app/providers.dart';
import 'app/routes.dart';
import 'app/window_pet_stage_port.dart';
import 'data/db/app_db.dart';
import 'features/pet/pet_frame.dart';
import 'features/pet/pet_notifier.dart';
import 'features/pet/pet_stage_port.dart';
import 'platform/tray/tray.dart';
import 'platform/window/pet_window.dart';

/// 起窗参数。
///
/// 无边框、置顶、透明底与不进任务栏由两处配合：这里交代一次初始样式，
/// `WindowManagerDriver.prepare()` 在摆位前再按一遍——只写一处的话，
/// 窗口先以白底方框闪一下才变透明。
const WindowOptions _windowOptions = WindowOptions(
  size: Size(240, 240),
  center: false,
  backgroundColor: Colors.transparent,
  skipTaskbar: true,
  titleBarStyle: TitleBarStyle.hidden,
  title: 'AI桌宠日常助手',
);

/// 入口：起窗、开库、装托盘，再把库与窗口端口注入 `ProviderScope`。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(_windowOptions, () async {
    await windowManager.show();
  });

  final db = await AppDb.open();

  // 端口要等窗口起来才有，所以先留一个洞口，容器建好后再填：
  // 覆盖写成惰性求值，读的时候 `port` 已经赋值。
  late final WindowPetStagePort port;
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(db),
      petStagePortProvider.overrideWith((ref) => port),
    ],
  );

  final window = await openPetWindow(
    driver: container.read(windowDriverProvider),
    settings: container.read(settingsRepositoryProvider),
    // 窗口每摆一次就告诉界面一次：档位与气泡一变，尺寸跟着变。
    onLayout: (layout) => container.read(petFrameProvider.notifier).apply(petFrameOf(layout)),
  );
  port = WindowPetStagePort(window);

  late final TrayController tray;
  tray = TrayController(
    container.read(trayDriverProvider),
    onShowMain: () {
      // 先报给常驻页，让界面自己切展开态并导航；再把窗口拿到前面。
      container.read(petNotifierProvider.notifier).requestMain();
      unawaited(_revealMain());
    },
    onQuit: () => unawaited(_quit(db, tray, window)),
  );
  await tray.start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AiPetApp(initialLocation: AppRoutes.pet),
    ),
  );
}

/// 把窗口拿到前面来：可能被最小化，也可能缩在别的窗口底下，所以要 show 再 focus。
///
/// 只负责「拿到前面」；切到主界面由 `requestMain()` 交给界面做——这一层没有路由。
Future<void> _revealMain() async {
  await windowManager.show();
  await windowManager.focus();
}

/// 退出：先卸托盘再关库，最后收窗口。
///
/// 顺序不能反——托盘还挂着的时候关库，用户再点一次「唤出主界面」就会碰到已关闭的库。
Future<void> _quit(AppDb db, TrayController tray, PetWindow window) async {
  await tray.stop();
  await db.close();
  window.dispose();
  await windowManager.destroy();
}
