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

  /// 勾上或撤掉，返回「系统接不接受」与「改完之后真正的状态」。
  ///
  /// 两件事必须分开：系统不接受时，真正的状态是「没变」，而不是「变成用户点的
  /// 那个值再取反」。早先这里写成 `accepted && isEnabled()`，于是注册表被组策略
  /// 挡住时开关会自己跳到另一头。
  Future<({bool accepted, bool on})> setOn(bool value) async {
    final accepted = value ? await _autoStart.enable() : await _autoStart.disable();
    return (accepted: accepted, on: await _autoStart.isEnabled());
  }
}
