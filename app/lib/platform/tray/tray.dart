import 'dart:async';

/// 托盘菜单里能被点的两件事。
///
/// 菜单上就这两项：唤出主界面、退出。别的事（切形态、开关面板）在界面上点，
/// 托盘是「找不到窗口时」的落脚处，不该塞满功能。
enum TrayAction { showMain, quit }

/// 托盘能力的最小接口。
///
/// 真实现是 `TrayManagerDriver`；测试注入假实现，点菜单这件事不用真图标也能测。
abstract class TrayDriver {
  /// 装上图标与菜单，之后 [actions] 会收到点击。
  Future<void> install();

  /// 收掉图标与菜单，退出前调用。
  Future<void> remove();

  /// 用户点了菜单里的哪一项。
  Stream<TrayAction> get actions;
}

/// 托盘：把菜单点击翻成上层要做的两件事，不管图标长什么样。
///
/// 图标、菜单项与平台差异都在 driver 里；这里只管点击之后叫谁。
class TrayController {
  TrayController(this._driver, {required this.onShowMain, required this.onQuit});

  final TrayDriver _driver;

  /// 点了「唤出主界面」。
  final void Function() onShowMain;

  /// 点了「退出」。
  final void Function() onQuit;

  StreamSubscription<TrayAction>? _subscription;

  /// 装上托盘并开始收点击。
  ///
  /// 装不上（系统没有通知区、图标读不到）时返回 false 而不是抛——没托盘的机器
  /// 也该能把应用跑起来，缺的只是那个入口。
  Future<bool> start() async {
    try {
      await _driver.install();
    } on Object {
      return false;
    }
    _subscription = _driver.actions.listen(_handle);
    return true;
  }

  /// 收摊：先停分发再卸图标，免得卸的过程中还有点击进来。
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _driver.remove();
  }

  void _handle(TrayAction action) {
    switch (action) {
      case TrayAction.showMain:
        onShowMain();
      case TrayAction.quit:
        onQuit();
    }
  }
}
