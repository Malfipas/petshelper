import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/key_configured.dart';
import '../../app/providers.dart';
import '../../data/repository/settings_repository.dart';
import 'settings_state.dart';

/// 第 8 页的动作：读两条地址、存与清 key、复制地址、切明文。
///
/// key 的两件事分开记：值写系统凭据（`SecureKeyGateway`），配没配写 settings 表
/// （`keyConfigured`）。第 2、5、6、7 页只读后者决定 AI 入口开不开，所以这里存完
/// 必须两处一起改，漏一处界面就会自相矛盾。
class SettingsNotifier extends Notifier<SettingsState> {
  /// 按钮闪光的轮次。短时间内连点两次，前一次的计时回来不该把后一次的字擦掉。
  int _flashTick = 0;

  /// 提醒行的轮次，同理。
  int _alertTick = 0;

  @override
  SettingsState build() {
    unawaited(refresh());
    return const SettingsState();
  }

  /// 读库里的两条地址与 key 状态，地址空着就填占位值。
  Future<void> refresh() async {
    final settings = await ref.read(settingsRepositoryProvider).current();
    if (!ref.mounted) return;
    // 顺手把全站的开关校准一次：这一页是唯一能改 key 的地方，进页读到的
    // 才是真的，别处只 watch 它。
    ref.read(keyConfiguredProvider.notifier).set(settings.keyConfigured);
    state = state.copyWith(
      configured: settings.keyConfigured,
      demoUrl: settings.demoUrl.isEmpty ? SettingsRepository.demoUrlPlaceholder : settings.demoUrl,
      repoUrl: settings.repoUrl.isEmpty ? SettingsRepository.repoUrlPlaceholder : settings.repoUrl,
    );
  }

  /// 在掩码与明文之间切。
  void toggleReveal() => state = state.copyWith(revealed: !state.revealed);

  /// 存下输入的 key。
  ///
  /// 输入为空时按清除处理——用户把内容删光再点保存，本意就是不要这个 key 了，
  /// 让它静默失败反而更费解（PRD 第 8 页 715 行）。
  Future<void> save(String raw) async {
    final key = raw.trim();
    if (key.isEmpty) {
      await _wipe(SettingsFlash.emptySaved);
      return;
    }

    try {
      await ref.read(secureKeyGatewayProvider).write(key);
      await ref.read(settingsRepositoryProvider).setKeyConfigured(true);
      ref.read(keyConfiguredProvider.notifier).set(true);
      if (!ref.mounted) return;
      state = state.copyWith(configured: true);
      _flash(SettingsFlash.saved);
    } catch (_) {
      // 凭据管理器拒了（组策略、权限）。别假装成功，也别把异常抛到界面外。
      _alert('保存失败，请重试');
    }
  }

  /// 抹掉 key，第 2、5、6、7 页随之回到只读。
  Future<void> clear() => _wipe(SettingsFlash.cleared);

  /// 复制演示视频地址。
  Future<void> copyDemo() => _copy(state.demoUrl, SettingsFlash.copiedDemo, selectTarget: 'demo');

  /// 复制项目仓库地址。
  Future<void> copyRepo() => _copy(state.repoUrl, SettingsFlash.copiedRepo, selectTarget: 'repo');

  Future<void> _wipe(SettingsFlash flash) async {
    try {
      await ref.read(secureKeyGatewayProvider).clear();
      await ref.read(settingsRepositoryProvider).setKeyConfigured(false);
      ref.read(keyConfiguredProvider.notifier).set(false);
      if (!ref.mounted) return;
      state = state.copyWith(configured: false);
      _flash(flash);
    } catch (_) {
      _alert('清除失败，请重试');
    }
  }

  Future<void> _copy(String text, SettingsFlash done, {required String selectTarget}) async {
    if (await _writeClipboard(text)) {
      if (!ref.mounted) return;
      _flash(done);
      return;
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      alert: '剪贴板不可用，地址已选中，请按 Ctrl+C 复制',
      selectTarget: selectTarget,
      selectTick: state.selectTick + 1,
    );
    _alertLater();
  }

  /// 写剪贴板；系统不给就返回假，由调用方改走「选中文本」这条退路。
  Future<bool> _writeClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _flash(SettingsFlash flash) {
    state = state.copyWith(flash: flash, alert: '');
    final tick = ++_flashTick;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) {
        if (!ref.mounted || _flashTick != tick) return;
        state = state.copyWith(clearFlash: true);
      }),
    );
  }

  void _alert(String message) {
    state = state.copyWith(alert: message);
    _alertLater();
  }

  void _alertLater() {
    final tick = ++_alertTick;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3)).then((_) {
        if (!ref.mounted || _alertTick != tick) return;
        state = state.copyWith(alert: '');
      }),
    );
  }
}

/// 第 8 页的状态。
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
