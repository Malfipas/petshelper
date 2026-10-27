/// 桌宠贴在屏幕哪一侧。
enum PetSide {
  left,
  right;

  static PetSide fromDb(String value) =>
      PetSide.values.firstWhere((side) => side.name == value, orElse: () => PetSide.left);
}

/// 设置项。整表只有一行。
///
/// API key 本身不在这里：只记「配没配」，key 的值在系统安全存储里。
class Settings {
  const Settings({
    this.keyConfigured = false,
    this.demoUrl = '',
    this.repoUrl = '',
    this.bubbleEnabled = true,
    this.side = PetSide.left,
    this.anchorY = 0.5,
  });

  /// 配过 key 没有。各页 AI 入口按它决定能不能点。
  final bool keyConfigured;

  /// 演示地址与仓库地址，只读占位，设置页可复制。
  final String demoUrl;
  final String repoUrl;

  /// 气泡开关。
  final bool bubbleEnabled;

  final PetSide side;

  /// 吸附的纵向位置，0 到 1 之间的比例。
  final double anchorY;
}
