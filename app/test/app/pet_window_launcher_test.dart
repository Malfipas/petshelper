import 'package:ai_pet_assistant/app/pet_window_launcher.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart';
import 'package:ai_pet_assistant/data/repository/settings_repository.dart';
import 'package:ai_pet_assistant/domain/model/settings.dart';
import 'package:ai_pet_assistant/platform/window/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_window_driver.dart';

/// 起窗与记住位置：设置里存什么就摆在哪，拖完立刻写回去，重开还在原地。
void main() {
  const area = ScreenWorkArea(left: 0, top: 0, width: 1920, height: 1040);
  late AppDb db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDb.memory();
    settings = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('第一次起窗贴桌面右缘、纵向居中', () async {
    final driver = FakeWindowDriver(area: area);

    final window = await openPetWindow(driver: driver, settings: settings);
    addTearDown(window.dispose);

    // 使用者 2026-10-26：只允许桌宠出现在桌面右缘，设置里的侧别不再影响摆放。
    expect(window.edge, WindowEdge.right);
    expect(window.anchorY, 0.5);
    expect(driver.rect.right, closeTo(area.right, 0.001));
    expect(driver.rect.center.dy, closeTo(area.top + area.height / 2, 0.001));
  });

  test('拖完只写高度，侧别不写', () async {
    final driver = FakeWindowDriver(area: area);
    final window = await openPetWindow(driver: driver, settings: settings);
    addTearDown(window.dispose);
    final sideBefore = (await settings.current()).side;

    await window.beginDrag();
    driver.dragTo(const Offset(1500, 300));
    await window.endDrag();

    final saved = await settings.current();
    expect(saved.anchorY, closeTo(window.anchorY, 0.0001));
    expect(saved.side, sideBefore);
    expect(driver.rect.right, closeTo(area.right, 0.001));
  });

  test('设置里存着左侧也照样贴右缘', () async {
    await settings.setSide(PetSide.left);
    final driver = FakeWindowDriver(area: area);

    final window = await openPetWindow(driver: driver, settings: settings);
    addTearDown(window.dispose);

    expect(driver.rect.right, closeTo(area.right, 0.001));
  });

  test('重开窗口回到上次的位置，不用再拖一遍', () async {
    final first = FakeWindowDriver(area: area);
    final before = await openPetWindow(driver: first, settings: settings);
    addTearDown(before.dispose);
    await before.beginDrag();
    first.dragTo(const Offset(1500, 640));
    await before.endDrag();
    final settled = first.rect;

    final second = FakeWindowDriver(area: area);
    final after = await openPetWindow(driver: second, settings: settings);
    addTearDown(after.dispose);

    expect(second.rect, settled);
    expect(after.edge, WindowEdge.right);
  });

  test('拖动期间拖动的状态能读到，松手后归位', () async {
    final driver = FakeWindowDriver(area: area);
    final window = await openPetWindow(driver: driver, settings: settings);
    addTearDown(window.dispose);

    await window.beginDrag();
    expect(window.dragging.value, isTrue);
    await window.endDrag();
    expect(window.dragging.value, isFalse);
  });
}
