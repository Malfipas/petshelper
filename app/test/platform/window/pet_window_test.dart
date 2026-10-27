import 'package:ai_pet_assistant/platform/window/pet_layout.dart';
import 'package:ai_pet_assistant/platform/window/pet_window.dart';
import 'package:ai_pet_assistant/platform/window/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_window_driver.dart';

/// 桌宠窗口的行为：起窗摆到位、拖完回右缘、三档尺寸、主界面能单独拖。
///
/// 用假 driver 替掉平台通道，所以这些能在 CI 里跑；真窗口的样子另列手动清单。
void main() {
  const area = ScreenWorkArea(left: 0, top: 0, width: 1920, height: 1040);

  group('起窗', () {
    test('按记住的高度摆到位，并把窗口准备成桌宠样式', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver, initialAnchorY: 0.5);
      addTearDown(window.dispose);

      await window.open();

      expect(driver.prepared, 1);
      expect(driver.rect.right, closeTo(area.right, 0.001));
      expect(driver.rect.center.dy, closeTo(area.top + area.height / 2, 0.001));
    });

    test('只贴右缘，纵向默认居中', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);

      await window.open();

      // 使用者 2026-10-26：只允许桌宠出现在桌面右缘，左缘那套暂时不做。
      expect(window.edge, WindowEdge.right);
      expect(window.anchorY, 0.5);
      expect(window.expanded, isFalse);
    });
  });

  group('拖动宠物', () {
    test('拖到左边松手也回右缘，只记纵向', () async {
      final driver = FakeWindowDriver(area: area);
      final saved = <PetPlacement>[];
      final window = PetWindow(
        driver,
        initialAnchorY: 0.5,
        onPlacementChanged: (placement) async => saved.add(placement),
      );
      addTearDown(window.dispose);
      await window.open();

      await window.beginDrag();
      driver.dragTo(const Offset(1500, 300));
      await window.endDrag();

      expect(saved, hasLength(1));
      final slack = area.height - petBoxSide(area, expanded: false);
      expect(saved.single.anchorY, closeTo(300 / slack, 0.01));
      expect(driver.rect.right, closeTo(area.right, 0.001));
      expect(driver.rect.top, closeTo(300, 0.001));
    });

    test('拖出去又放回原处不写库', () async {
      final driver = FakeWindowDriver(area: area);
      final saved = <PetPlacement>[];
      final window = PetWindow(
        driver,
        onPlacementChanged: (placement) async => saved.add(placement),
      );
      addTearDown(window.dispose);
      await window.open();
      final before = driver.rect;

      await window.beginDrag();
      driver.dragTo(before.topLeft);
      await window.endDrag();

      expect(saved, isEmpty);
      expect(driver.rect, before);
    });

    test('拖动期间 dragging 为真，重复起手只交给系统一次', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();

      expect(window.dragging.value, isFalse);
      await window.beginDrag();
      expect(window.dragging.value, isTrue);
      await window.beginDrag();
      expect(driver.drags, 1);

      await window.endDrag();
      expect(window.dragging.value, isFalse);
    });

    test('没在拖的时候松手什么都不做', () async {
      final driver = FakeWindowDriver(area: area);
      final saved = <PetPlacement>[];
      final window = PetWindow(
        driver,
        onPlacementChanged: (placement) async => saved.add(placement),
      );
      addTearDown(window.dispose);
      await window.open();
      final placed = driver.placed.length;

      driver.dragTo(const Offset(1500, 300));
      await window.endDrag();

      expect(saved, isEmpty);
      expect(driver.placed.length, placed);
    });
  });

  group('三档', () {
    test('常驻档窗口就是宠物框', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver, initialAnchorY: 1);
      addTearDown(window.dispose);
      await window.open();

      expect(window.stage, PetStage.collapsed);
      expect(driver.rect, window.layout!.pet);
      expect(driver.rect.right, closeTo(area.right, 0.001));
      expect(driver.rect.bottom, closeTo(area.bottom, 0.001));
    });

    test('切主界面档：窗口包住主界面与宠物，宠物贴桌面右缘', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      final collapsed = driver.rect;

      await window.setStage(PetStage.main);

      expect(window.expanded, isTrue);
      expect(driver.rect.width, greaterThan(collapsed.width));
      final layout = window.layout!;
      expect(driver.rect, layout.window);
      final main = layout.mainInWindow!;
      // 主界面仍是居中的七成框（按屏幕坐标看中心），宠物站在桌面边缘、不压主界面。
      expect(main.width, closeTo(area.width * mainWidthScale, 0.001));
      expect(layout.main!.center.dx, closeTo(area.left + area.width / 2, 0.001));
      expect(layout.main!.center.dy, closeTo(area.top + area.height / 2, 0.001));
      expect(layout.petInWindow.width, closeTo(petBoxSide(area, expanded: true), 0.001));
      expect(layout.petInWindow.right, closeTo(driver.rect.width, 0.001));
      expect(layout.petInWindow.overlaps(main), isFalse);
    });

    test('拖宠物：宠物跟着指针走，主界面一动不动', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setStage(PetStage.main);
      final mainBefore = window.layout!.main;
      final petBefore = window.layout!.pet;

      await window.beginDrag();
      // 拖动期间窗口铺满工作区：主界面与宠物的屏幕位置各自算，整窗跟手才不牵连。
      expect(driver.rect.width, closeTo(area.width, 0.001));
      expect(window.dragging.value, isTrue);

      await window.dragPetBy(const Offset(-120, -80));
      expect(window.layout!.pet.topLeft, petBefore.topLeft + const Offset(-120, -80));
      expect(window.layout!.main, mainBefore);

      await window.endDrag();
      expect(window.layout!.main, mainBefore);
      // 松手吸回桌面右缘，窗口缩回「主界面 ∪ 宠物」。
      expect(window.layout!.pet.right, closeTo(area.right, 0.001));
      expect(driver.rect, window.layout!.window);
      expect(window.dragging.value, isFalse);
    });

    test('拖宠物至少留 48 像素在屏里，拖出去还抓得回来', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setStage(PetStage.main);

      await window.beginDrag();
      await window.dragPetBy(const Offset(-5000, -5000));

      expect(window.layout!.pet.right, closeTo(area.left + PetWindow.petKeepVisible, 0.001));
      expect(window.layout!.pet.bottom, closeTo(area.top + PetWindow.petKeepVisible, 0.001));
    });

    test('没起手就挪宠物不做任何事', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setStage(PetStage.main);
      final before = window.layout!.pet;

      await window.dragPetBy(const Offset(60, 40));
      await window.endDrag();

      expect(window.layout!.pet, before);
    });

    test('拖到一半换档：不再停在铺满的样子', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setStage(PetStage.main);

      await window.beginDrag();
      expect(driver.rect.width, closeTo(area.width, 0.001));

      await window.setStage(PetStage.collapsed);

      expect(window.dragging.value, isFalse);
      expect(driver.rect.width, lessThan(area.width));
    });

    test('切面板档：窗口包住宠物与面板，宠物在窗口内仍贴边', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      final pet = window.layout!.pet;

      await window.setStage(PetStage.panel);

      final layout = window.layout!;
      expect(driver.rect, layout.window);
      expect(layout.pet, pet);
      expect(layout.panelInWindow, isNotNull);
      expect(layout.petInWindow.right, closeTo(driver.rect.width, 0.001));
      // 面板压在宠物图上，右边缘比图左边多 15 像素（原型 placeX）。
      final image = petImageBounds(
        box: layout.petInWindow,
        edge: WindowEdge.right,
        expanded: false,
      );
      expect(layout.panelInWindow!.right, closeTo(image.left + floatingInset, 0.001));
    });

    test('面板档不交给系统拖；常驻档与主界面档都能拖', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();

      // 面板档要能点面板里的按钮，整窗跟着指针跑就没法点了。
      await window.setStage(PetStage.panel);
      await window.beginDrag();
      expect(driver.drags, 0);

      await window.setStage(PetStage.collapsed);
      await window.beginDrag();
      expect(driver.drags, 1);
      await window.endDrag();

      // 展开态的宠物也要能拖，但不交给系统：那一档窗口里还有主界面，
      // 整窗跟手会把主界面一起搬走。
      await window.setStage(PetStage.main);
      await window.beginDrag();
      expect(driver.drags, 1);
      expect(driver.rect.width, closeTo(area.width, 0.001));
      await window.endDrag();
    });

    test('主界面档关掉置顶，其余两档开着', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();

      // 使用者 2026-10-26：别的窗口被点时要能压到主界面上面，主界面不能一直置顶。
      await window.setStage(PetStage.main);
      expect(driver.alwaysOnTop, isFalse);

      await window.setStage(PetStage.collapsed);
      expect(driver.alwaysOnTop, isTrue);

      await window.setStage(PetStage.panel);
      expect(driver.alwaysOnTop, isTrue);
    });

    test('重复切同一档不重新摆位', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setStage(PetStage.main);
      final placed = driver.placed.length;

      await window.setStage(PetStage.main);

      expect(driver.placed.length, placed);
    });
  });

  group('气泡与布局回传', () {
    test('设了气泡窗口就长高，并把新布局交给界面', () async {
      final driver = FakeWindowDriver(area: area);
      final layouts = <PetLayout>[];
      final window = PetWindow(driver, onLayout: layouts.add);
      addTearDown(window.dispose);
      await window.open();
      final before = driver.rect.height;

      await window.setBubbles(deadlineHeight: 108, reportHeight: null);

      expect(layouts, isNotEmpty);
      expect(driver.rect.height, greaterThan(before));
      expect(window.layout!.deadlineBubble, isNotNull);
      expect(layouts.last, same(window.layout));
    });

    test('气泡没变就不重摆位', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setBubbles(deadlineHeight: 108, reportHeight: 214);
      final placed = driver.placed.length;

      await window.setBubbles(deadlineHeight: 108, reportHeight: 214);

      expect(driver.placed.length, placed);
    });

    test('两档气泡同时撤掉，窗口缩回只剩宠物', () async {
      final driver = FakeWindowDriver(area: area);
      final window = PetWindow(driver);
      addTearDown(window.dispose);
      await window.open();
      await window.setBubbles(deadlineHeight: 108, reportHeight: 214);

      await window.setBubbles(deadlineHeight: null, reportHeight: null);

      expect(window.layout!.deadlineBubble, isNull);
      expect(driver.rect, window.layout!.pet);
    });
  });

  test('系统拖动停下：驱动报一声，窗口自己收尾', () async {
    final driver = FakeWindowDriver(area: area);
    final window = PetWindow(driver);
    addTearDown(window.dispose);
    await window.open();
    await window.beginDrag();
    driver.dragTo(const Offset(1500, 300));

    driver.dropDrag();
    await pumpEventQueue();

    expect(window.dragging.value, isFalse);
    expect(driver.rect.right, closeTo(area.right, 0.001));
  });

  test('重启后回到原位：拿上次的落位起窗，摆出同一个矩形', () async {
    final first = FakeWindowDriver(area: area);
    final saved = <PetPlacement>[];
    final before = PetWindow(
      first,
      initialAnchorY: 0.5,
      onPlacementChanged: (placement) async => saved.add(placement),
    );
    addTearDown(before.dispose);
    await before.open();
    await before.beginDrag();
    first.dragTo(const Offset(1500, 700));
    await before.endDrag();
    final settledRect = first.rect;

    final second = FakeWindowDriver(area: area);
    final after = PetWindow(second, initialAnchorY: saved.single.anchorY);
    addTearDown(after.dispose);
    await after.open();

    expect(second.rect, settledRect);
  });
}
