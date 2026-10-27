/// 开机自启能力的最小接口。
///
/// 真实现是 `LaunchAtStartupAutoStart`；测试注入假实现，开关逻辑不碰注册表。
abstract class AutoStart {
  /// 现在是不是开机自启。
  Future<bool> isEnabled();

  /// 打开开机自启，返回系统是否接受。
  Future<bool> enable();

  /// 撤掉开机自启，返回系统是否接受。
  Future<bool> disable();
}

/// 开机自启开关。
///
/// 只做一件额外的事：改完回读。系统可能没接受（注册表写不进去、被策略挡住），
/// 界面该按真实状态回显，而不是按用户点下去的那个值。
class AutoStartController {
  AutoStartController(this._autoStart);

  final AutoStart _autoStart;

  /// 现在勾没勾。
  Future<bool> isOn() => _autoStart.isEnabled();

  /// 勾上或撤掉，返回改完之后真正的状态。
  Future<bool> setOn(bool value) async {
    final accepted = value ? await _autoStart.enable() : await _autoStart.disable();
    return accepted && await _autoStart.isEnabled();
  }
}
