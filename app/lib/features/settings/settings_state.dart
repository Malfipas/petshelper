/// 设置页按钮上那 1.5 秒的临时文字。
///
/// 原型用 `stFlash(btn, text)` 直接把按钮字换掉再复原；这里把「哪个按钮换了什么」
/// 存成状态，页面只按它取字符串，不再各记一份计时。
enum SettingsFlash {
  /// 存下了 key，保存按钮显示「已保存」。
  saved,

  /// 输入为空却按了保存，按清除处理，保存按钮显示「已清除」。
  emptySaved,

  /// 点了清除，清除按钮显示「已清除」。
  cleared,

  /// 复制了演示视频地址，那一行的复制按钮显示「已复制」。
  copiedDemo,

  /// 复制了项目仓库地址。
  copiedRepo,
}

/// 第 8 页的全部状态。
///
/// 只有两件事真正落库：key 在系统凭据里，配没配记在 settings 表；两条地址是只读
/// 占位，库里空着就显示常量。其余都是这一页自己的瞬时状态（明文开关、按钮闪光、
/// 剪贴板不可用的提醒）。
class SettingsState {
  const SettingsState({
    this.demoUrl = '',
    this.repoUrl = '',
    this.configured = false,
    this.revealed = false,
    this.flash,
    this.alert = '',
    this.selectTick = 0,
    this.selectTarget,
  });

  /// 演示视频地址，库里空着时是占位常量。
  final String demoUrl;

  /// 项目仓库地址，同上。
  final String repoUrl;

  /// 存过 key 没有。
  ///
  /// 不进输入框——key 的值读不出来也不该读出来，这一格只用来在卡片标题旁
  /// 写一句「已配置」，让人知道上次那一下确实存住了。
  final bool configured;

  /// key 输入框是不是明文。默认掩码。
  final bool revealed;

  /// 哪个按钮在闪临时文字，没有就是 null。
  final SettingsFlash? flash;

  /// 剪贴板不可用时的一句话提醒，空着表示不显示。
  final String alert;

  /// 每请求一次「选中地址」加一，页面看到它变了才动输入框的选区。
  ///
  /// 直接拿 `alert` 当信号不行：连着两次失败提醒内容一样，第二次就没人响应了。
  final int selectTick;

  /// 要选中的是哪一行：`demo` 或 `repo`。
  final String? selectTarget;

  /// 保存按钮此刻该写什么。
  String get saveLabel => switch (flash) {
    SettingsFlash.saved => '已保存',
    SettingsFlash.emptySaved => '已清除',
    _ => '保存',
  };

  /// 清除按钮此刻该写什么。
  String get clearLabel => flash == SettingsFlash.cleared ? '已清除' : '清除';

  /// 某一行的复制按钮此刻该写什么。
  String copyLabel({required bool demo}) =>
      flash == (demo ? SettingsFlash.copiedDemo : SettingsFlash.copiedRepo) ? '已复制' : '复制';

  SettingsState copyWith({
    String? demoUrl,
    String? repoUrl,
    bool? configured,
    bool? revealed,
    SettingsFlash? flash,
    bool clearFlash = false,
    String? alert,
    int? selectTick,
    String? selectTarget,
  }) => SettingsState(
    demoUrl: demoUrl ?? this.demoUrl,
    repoUrl: repoUrl ?? this.repoUrl,
    configured: configured ?? this.configured,
    revealed: revealed ?? this.revealed,
    flash: clearFlash ? null : (flash ?? this.flash),
    alert: alert ?? this.alert,
    selectTick: selectTick ?? this.selectTick,
    selectTarget: selectTarget ?? this.selectTarget,
  );
}
