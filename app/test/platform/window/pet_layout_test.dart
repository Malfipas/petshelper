import 'dart:ui';

import 'package:ai_pet_assistant/platform/window/pet_layout.dart';
import 'package:ai_pet_assistant/platform/window/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// 三档布局的算术：窗口该多大、宠物与面板在窗口里的哪个位置。
void main() {
  const area = ScreenWorkArea(left: 0, top: 0, width: 1920, height: 1040);

  // 使用者 2026-10-25 觉得桌宠与小任务窗口都太大，宽高各降 5 个百分点。
  test('四档比例：桌宠 15%/25%，面板 25%/35%', () {
    expect(collapsedScale, 0.15);
    expect(expandedScale, 0.25);
    expect(panelWidthScale, 0.25);
    expect(panelHeightScale, 0.35);
  });

  group('常驻档', () {
    test('窗口就是宠物框，没有面板与主界面', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.collapsed,
      );

      expect(
        layout.window,
        petBounds(area: area, edge: WindowEdge.right, anchorY: 0.5, expanded: false),
      );
      expect(layout.pet, layout.window);
      expect(layout.panel, isNull);
      expect(layout.main, isNull);
      expect(layout.petInWindow.left, 0);
      expect(layout.petInWindow.top, 0);
    });
  });

  group('面板档', () {
    test('窗口包住宠物与面板，宠物仍贴右缘', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.panel,
      );

      final pet = layout.pet;
      final panel = layout.panel!;
      final image = petImageBounds(box: pet, edge: WindowEdge.right, expanded: false);
      expect(panel.right, closeTo(image.left + floatingInset, 0.001));
      expect(panel.width, closeTo(area.width * panelWidthScale, 0.001));
      expect(panel.height, closeTo(area.height * panelHeightScale, 0.001));
      expect(layout.window, pet.expandToInclude(panel));
      expect(layout.window.right, closeTo(area.right, 0.001));
      expect(layout.petInWindow.right, closeTo(layout.window.width, 0.001));
    });

    test('贴左缘时面板在宠物右边', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.left,
        anchorY: 0.5,
        stage: PetStage.panel,
      );

      final image = petImageBounds(box: layout.pet, edge: WindowEdge.left, expanded: false);
      expect(layout.panel!.left, closeTo(image.right - floatingInset, 0.001));
      expect(layout.window.left, closeTo(area.left, 0.001));
      expect(layout.petInWindow.left, 0);
    });

    test('面板竖直方向夹在工作区内，不越出上下边', () {
      for (final anchor in [0.0, 1.0]) {
        final layout = petLayout(
          area: area,
          edge: WindowEdge.right,
          anchorY: anchor,
          stage: PetStage.panel,
        );
        final panel = layout.panel!;
        expect(panel.top, greaterThanOrEqualTo(area.top));
        expect(panel.bottom, lessThanOrEqualTo(area.bottom));
      }
    });
  });

  group('主界面档', () {    // 使用者 2026-10-25 的两条要求合起来改了这里：主界面照旧七成居中，
    // 宠物改成贴**桌面**边缘（不再坐进主界面里），窗口取两者的并集。
    test('主界面宽高各七成、整块居中，窗口是它与宠物的并集', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
      );

      // 整体原型 `.main{width:70vw;height:70vh}` + `translate(-50%,-50%)`。
      expect(layout.main!.width, closeTo(area.width * mainWidthScale, 0.001));
      expect(layout.main!.height, closeTo(area.height * mainHeightScale, 0.001));
      expect(layout.main!.center.dx, closeTo(area.left + area.width / 2, 0.001));
      expect(layout.main!.center.dy, closeTo(area.top + area.height / 2, 0.001));
      expect(layout.window, layout.main!.expandToInclude(layout.pet));
    });

    test('宠物切展开图贴桌面右缘，且不压在主界面上', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
      );

      expect(layout.pet.width, closeTo(petBoxSide(area, expanded: true), 0.001));
      expect(layout.pet.right, closeTo(area.right, 0.001));
      expect(layout.window.right, closeTo(area.right, 0.001));
      // 主界面七成居中，两侧各留一成半；宠物收在这一成半的空当里，不盖页面。
      expect(layout.pet.left, greaterThanOrEqualTo(layout.main!.right));
      expect(layout.pet.overlaps(layout.main!), isFalse);
    });

    test('贴左缘时宠物贴桌面左边，同样不压主界面', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.left,
        anchorY: 0.5,
        stage: PetStage.main,
      );

      expect(layout.pet.left, closeTo(area.left, 0.001));
      expect(layout.window.left, closeTo(area.left, 0.001));
      expect(layout.main!.center.dx, closeTo(area.left + area.width / 2, 0.001));
      expect(layout.pet.right, lessThanOrEqualTo(layout.main!.left));
    });

    test('主界面固定居中：换了屏也只跟着屏心走，没有可拖的地方', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
      );

      expect(layout.main!.center.dx, closeTo(area.left + area.width / 2, 0.001));
      expect(layout.main!.center.dy, closeTo(area.top + area.height / 2, 0.001));
    });

    test('拖宠物时按 petOverride 摆宠物，主界面一动不动', () {
      final still = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
      );
      final dragged = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
        petOverride: const Rect.fromLTWH(400, 300, 288, 288),
        windowOverride: Rect.fromLTWH(area.left, area.top, area.width, area.height),
      );

      expect(dragged.pet, const Rect.fromLTWH(400, 300, 288, 288));
      expect(dragged.main, still.main);
      // 窗口在拖动期间铺满工作区，界面才能把指针位移当成纯位移。
      expect(dragged.window.size, Size(area.width, area.height));
    });

    test('小屏兜到最小 880×560 后被屏幕夹住，大屏只按七成不设上限', () {
      // 800×600：最小宽 880 已经比屏幕宽，只能取满宽；高 560 装得下。
      const narrow = ScreenWorkArea(left: 0, top: 0, width: 800, height: 600);
      final onNarrow = petLayout(
        area: narrow,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
      );
      expect(onNarrow.main!.width, closeTo(800, 0.001));
      expect(onNarrow.main!.height, closeTo(mainMinHeight, 0.001));
      expect(onNarrow.window.contains(onNarrow.pet.topLeft), isTrue);

      // 4K：七成就是 2688，不再封顶。封顶 720 比最小 880 还小，那是自相矛盾。
      const wide = ScreenWorkArea(left: 0, top: 0, width: 3840, height: 2160);
      final onWide = petLayout(
        area: wide,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
      );
      expect(onWide.main!.width, closeTo(3840 * 0.7, 0.001));
      expect(onWide.main!.height, closeTo(2160 * 0.7, 0.001));
      expect(onWide.window.right, closeTo(wide.right, 0.001));
    });
  });

  group('气泡', () {
    test('气泡压住宠物头顶 5 像素，宽取工作区四分之一', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.collapsed,
        showDeadlineBubble: true,
      );

      final image = petImageBounds(box: layout.pet, edge: WindowEdge.right, expanded: false);
      expect(layout.deadlineBubble, isNotNull);
      expect(layout.reportBubble, isNull);
      // 原型 `bubbles.top = r.top + 5 - 栈高`：栈底边压进图顶 5 像素。
      expect(layout.deadlineBubble!.bottom, closeTo(image.top + bubbleOverlap, 0.001));
      expect(layout.deadlineBubble!.width, closeTo(area.width * bubbleWidthScale, 0.001));
      expect(layout.deadlineBubble!.height, deadlineBubbleHeight);
      expect(layout.window.top, closeTo(layout.deadlineBubble!.top, 0.001));
      expect(layout.petInWindow.top, greaterThan(0));
    });

    test('贴右缘时气泡往屏幕里侧伸，压进宠物图 15 像素', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.collapsed,
        showReportBubble: true,
      );

      final image = petImageBounds(box: layout.pet, edge: WindowEdge.right, expanded: false);
      expect(layout.reportBubble!.right, closeTo(image.left + floatingInset, 0.001));
      expect(layout.reportBubble!.right, lessThan(area.right));
    });

    test('贴左缘时气泡朝右探，同样压进宠物图 15 像素', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.left,
        anchorY: 0.5,
        stage: PetStage.collapsed,
        showReportBubble: true,
      );

      final image = petImageBounds(box: layout.pet, edge: WindowEdge.left, expanded: false);
      expect(layout.reportBubble!.left, closeTo(image.right - floatingInset, 0.001));
      expect(layout.reportBubble!.left, greaterThan(area.left));
    });

    test('两档同时在时上下摞起来，中间留一道缝', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.collapsed,
        showDeadlineBubble: true,
        showReportBubble: true,
      );

      expect(layout.reportBubble!.top, closeTo(layout.deadlineBubble!.bottom + bubbleGap, 0.001));
      expect(layout.reportBubble!.height, reportBubbleHeight);
    });

    test('宠物贴得太高时气泡夹在工作区顶部，不翻到脚下', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0,
        stage: PetStage.collapsed,
        showDeadlineBubble: true,
        showReportBubble: true,
      );

      expect(layout.deadlineBubble!.top, closeTo(area.top + floatingMargin / 2, 0.001));
      expect(layout.window.top, greaterThanOrEqualTo(area.top));
    });

    test('内容再高也只占工作区三成，多出来的在气泡里滚', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.collapsed,
        showReportBubble: true,
        reportHeight: 900,
      );

      expect(layout.reportBubble!.height, closeTo(area.height * bubbleMaxHeightScale, 0.001));
    });

    test('面板档：面板接在气泡下方，谁都不盖谁', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.panel,
        showDeadlineBubble: true,
      );

      expect(layout.panel!.top, closeTo(layout.deadlineBubble!.bottom + panelStackGap, 0.001));
    });

    test('面板档没有气泡时，面板顶也从宠物图顶往下 5 起', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.panel,
      );

      final image = petImageBounds(box: layout.pet, edge: WindowEdge.right, expanded: false);
      expect(layout.panel!.top, closeTo(image.top + bubbleOverlap, 0.001));
    });

    test('主界面档不给气泡让位：宠物已经站在桌面边缘', () {
      final layout = petLayout(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        stage: PetStage.main,
        showDeadlineBubble: true,
        showReportBubble: true,
      );

      expect(layout.deadlineBubble, isNull);
      expect(layout.reportBubble, isNull);
      expect(layout.window, mainBounds(area: area).expandToInclude(layout.pet));
    });
  });

  group('多屏', () {
    test('副屏在主屏左侧、原点为负时也贴得住', () {
      const leftScreen = ScreenWorkArea(left: -1920, top: 0, width: 1920, height: 1040);
      final layout = petLayout(
        area: leftScreen,
        edge: WindowEdge.left,
        anchorY: 0.5,
        stage: PetStage.main,
      );

      // 主界面左边界在主屏里那一块（-1632），宠物贴到副屏最左（-1920），窗口从宠物起头。
      expect(layout.main!.left, closeTo(-1920 + 1920 * (1 - mainWidthScale) / 2, 0.001));
      expect(layout.pet.left, closeTo(-1920, 0.001));
      expect(layout.window.left, closeTo(-1920, 0.001));
    });
  });
}
