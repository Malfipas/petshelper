import '../data/repository/settings_repository.dart';
import '../platform/window/pet_layout.dart';
import '../platform/window/pet_window.dart';
import '../platform/window/window_driver.dart';

/// 起桌宠窗口，并把「贴多高」接到设置上。
///
/// 横向不再跟设置走：使用者 2026-10-26 定下桌宠只出现在桌面右缘，左缘那一套
/// 暂时不做，`PetSide` 因此只剩「记住过左侧」这一个历史字段的含义。
Future<PetWindow> openPetWindow({
  required WindowDriver driver,
  required SettingsRepository settings,
  void Function(PetLayout layout)? onLayout,
}) async {
  final current = await settings.current();
  final window = PetWindow(
    driver,
    initialAnchorY: current.anchorY,
    onLayout: onLayout,
    onPlacementChanged: (placement) async {
      await settings.setAnchorY(placement.anchorY);
    },
  );
  await window.open();
  return window;
}
