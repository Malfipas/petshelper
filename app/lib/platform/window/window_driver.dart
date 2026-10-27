import 'dart:ui';

import 'window_geometry.dart';

/// 窗口能力的最小接口。
///
/// 真实现是 `WindowManagerDriver`，测试注入假实现——窗口这块不靠平台通道也能测，
/// 这也是唯一能把「吸附、换侧、记住位置」写成自动测试的办法。
abstract class WindowDriver {
  /// 把窗口准备成桌宠该有的样子：无边框、置顶、不进任务栏、背景透明。
  Future<void> prepare();

  /// 置顶开关。
  ///
  /// 桌宠与悬停面板要压在所有窗口上面；主界面档必须关掉，否则别的窗口点不到
  /// 最前面，主界面会一直盖着别人的程序（使用者 2026-10-26 反馈）。
  Future<void> setAlwaysOnTop(bool value);

  /// 主显示器的工作区，任务栏已经扣掉。
  Future<ScreenWorkArea> workArea();

  /// 窗口现在在哪、多大。
  Future<Rect> bounds();

  /// 把窗口摆到指定矩形。
  Future<void> placeAt(Rect bounds);

  /// 把这一下拖动交给系统，窗口跟着指针走。
  Future<void> startDrag();

  /// 系统拖动结束。
  ///
  /// `startDrag` 交出去之后，Flutter 收不到那一下的松手事件，只能靠窗口停止移动
  /// 反推；用可靠的事件流而不是回调，是因为订阅方要在关闭时退订。
  Stream<void> get dragEnded;
}
