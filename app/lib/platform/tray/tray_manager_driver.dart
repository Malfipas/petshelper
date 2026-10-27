import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

import 'tray.dart';

/// 真托盘：走 tray_manager 的 nativeapi 接口（0.8 起 `trayManager` 那套已标弃用）。
///
/// 图标打在包里（`assets/icons/tray_icon.png`），由 Flutter 资源表带出来，
/// 不依赖 exe 旁边的文件——安装到别的路径也不会丢图标。
class TrayManagerDriver implements TrayDriver {
  TrayManagerDriver({this.iconAsset = 'assets/icons/tray_icon.png', this.tooltip = 'AI 桌宠日常助手'});

  final String iconAsset;
  final String tooltip;

  final StreamController<TrayAction> _actions = StreamController<TrayAction>.broadcast();
  final List<MenuItem> _items = [];
  Menu? _menu;
  TrayIcon? _icon;

  @override
  Stream<TrayAction> get actions => _actions.stream;

  @override
  Future<void> install() async {
    final icon = TrayIcon.create();
    final menu = Menu.create();
    // 没有通知区（或 native 侧没起来）就当没有托盘，不拦着应用启动。
    if (icon == null || menu == null) return;
    _icon = icon;
    _menu = menu;

    // 读不到图也把菜单挂上：没有图标的托盘项不好点，但比整个入口消失强。
    final image = ImageAsset.fromAsset(iconAsset);
    if (image != null) icon.icon = image;
    icon.setTooltip(tooltip);

    menu.addItem(_item('唤出主界面', TrayAction.showMain));
    menu.addSeparator();
    menu.addItem(_item('退出', TrayAction.quit));

    icon.setContextMenu(menu);
    // 左键点图标也唤出主界面：菜单是右键的事，鼠标习惯不该只有一条路。
    icon.addListener((event) {
      if (event is TrayIconClickedEvent) _emit(TrayAction.showMain);
    });
    icon.setVisible(true);
  }

  @override
  Future<void> remove() async {
    _icon?.setVisible(false);
    _icon?.dispose();
    _menu?.dispose();
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    _icon = null;
    _menu = null;
    if (!_actions.isClosed) await _actions.close();
  }

  /// 菜单项自己带点击监听：native 侧把事件发到这一项上，不经过全局回调。
  MenuItem _item(String label, TrayAction action) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal)!;
    item.addListener((event) {
      if (event is MenuItemClickedEvent) _emit(action);
    });
    _items.add(item);
    return item;
  }

  void _emit(TrayAction action) {
    if (!_actions.isClosed) _actions.add(action);
  }
}
