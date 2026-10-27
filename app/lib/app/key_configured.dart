import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// 全站 AI 入口的总开关，也就是 `settings.keyConfigured` 在内存里的那一份。
///
/// 为什么单拎一个 provider：第 2、5、6、7 页原先各读各的库，谁先进页面谁先
/// 拿到那份值。设置页存完 key，别的页要等下一次重进才醒——B21 实机就撞上
/// 「我的记录、想法盒的提示撤了，悬停面板还写着未配置」。改成一处改、全站
/// watch，就不会有页落后。
///
/// 它只记真假，key 本身仍在 `SecureKeyGateway` 里，别把值搬进来。
class KeyConfiguredNotifier extends Notifier<bool> {
  /// 有没有被人明确改过。
  ///
  /// 启动时那次读库是异步的，回来可能比设置页那一下晚；没有这个标记，
  /// 「刚存完显示已配置」会被迟到的旧值盖回去。
  bool _settled = false;

  @override
  bool build() {
    unawaited(load());
    return false;
  }

  /// 从库里读一次，只在启动时用；之后一律听 [set] 的。
  ///
  /// 读不到就保持 false：这一格只决定入口能不能点，不值得为一次读库失败
  /// 把整页打挂。容器已经拆掉（测试 tearDown、热重启）也算读不到。
  Future<void> load() async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).current();
      if (!ref.mounted || _settled) return;
      state = settings.keyConfigured;
    } catch (_) {
      return;
    }
  }

  /// 存下或清除 key 之后就地改，不等库那一趟往返。
  void set(bool configured) {
    _settled = true;
    if (state == configured) return;
    state = configured;
  }
}

/// 配了 key 没有。各页 AI 入口读它决定能不能点。
final keyConfiguredProvider = NotifierProvider<KeyConfiguredNotifier, bool>(
  KeyConfiguredNotifier.new,
);
