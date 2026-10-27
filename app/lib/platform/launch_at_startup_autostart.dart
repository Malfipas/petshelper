import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import 'autostart.dart';

/// 真自启：写用户级启动项。
///
/// Windows 上落在 `HKCU\...\Run`，不需要管理员权限，也不用装服务。
/// 名字与路径必须与实际程序一致，否则开机时找不到文件，所以 [appPath]
/// 默认取 `Platform.resolvedExecutable`。
class LaunchAtStartupAutoStart implements AutoStart {
  LaunchAtStartupAutoStart({this.appName = 'AI桌宠日常助手', String? appPath})
    : appPath = appPath ?? Platform.resolvedExecutable;

  final String appName;
  final String appPath;

  bool _setUp = false;

  /// setup 只能给一次路径，多调一次会换掉实现；首次用之前补上。
  void _ensureSetUp() {
    if (_setUp) return;
    launchAtStartup.setup(appName: appName, appPath: appPath);
    _setUp = true;
  }

  @override
  Future<bool> isEnabled() async {
    _ensureSetUp();
    return launchAtStartup.isEnabled();
  }

  @override
  Future<bool> enable() async {
    _ensureSetUp();
    return launchAtStartup.enable();
  }

  @override
  Future<bool> disable() async {
    _ensureSetUp();
    return launchAtStartup.disable();
  }
}
