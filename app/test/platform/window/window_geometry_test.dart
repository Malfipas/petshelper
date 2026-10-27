import 'dart:ui';

import 'package:ai_pet_assistant/platform/window/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// 摆位算术：贴边、两档尺寸、展开时下角锚定、松手后换侧。
///
/// 全部是纯计算，不碰窗口也不需要平台通道，所以这几条能在任何机器上跑。
void main() {
  /// 1920×1080 的屏，扣掉 40 像素任务栏剩 1040。
  const area = ScreenWorkArea(left: 0, top: 0, width: 1920, height: 1040);

  group('两档尺寸', () {
    // 使用者 2026-10-25 要求桌宠占比各降 5 个百分点：20%→15%、30%→25%。
    test('收起取短边的 15%，展开 25%', () {
      expect(petBoxSide(area, expanded: false), closeTo(156, 0.001));
      expect(petBoxSide(area, expanded: true), closeTo(260, 0.001));
    });

    test('屏幕很扁时按短边取，不按宽度拉变形', () {
      const wide = ScreenWorkArea(left: 0, top: 0, width: 3000, height: 500);

      expect(petBoxSide(wide, expanded: false), closeTo(75, 0.001));
    });
  });

  group('贴边', () {
    test('贴右缘时右边与工作区右边重合', () {
      final rect = petBounds(area: area, edge: WindowEdge.right, anchorY: 0.5, expanded: false);

      expect(rect.right, closeTo(area.right, 0.001));
    });

    test('贴左缘时左边与工作区左边重合', () {
      final rect = petBounds(area: area, edge: WindowEdge.left, anchorY: 0.5, expanded: false);

      expect(rect.left, closeTo(area.left, 0.001));
    });
  });

  group('纵向位置', () {
    test('比例 0 贴顶，1 贴底，越界夹回去', () {
      final top = petBounds(area: area, edge: WindowEdge.right, anchorY: 0, expanded: false);
      final bottom = petBounds(area: area, edge: WindowEdge.right, anchorY: 1, expanded: false);
      final over = petBounds(area: area, edge: WindowEdge.right, anchorY: 2, expanded: false);

      expect(top.top, closeTo(area.top, 0.001));
      expect(bottom.bottom, closeTo(area.bottom, 0.001));
      expect(over.bottom, closeTo(area.bottom, 0.001));
    });

    test('比例 0.5 时框中心落在工作区纵向正中', () {
      final rect = petBounds(area: area, edge: WindowEdge.right, anchorY: 0.5, expanded: false);

      expect(rect.center.dy, closeTo(area.top + area.height / 2, 0.001));
    });
  });

  group('展开与收起', () {
    test('展开以贴屏那一侧的下角为锚点：右边与底边不动，往上长', () {
      final collapsed = petBounds(
        area: area,
        edge: WindowEdge.right,
        anchorY: 0.5,
        expanded: false,
      );
      final expanded = petBounds(area: area, edge: WindowEdge.right, anchorY: 0.5, expanded: true);

      expect(expanded.right, closeTo(collapsed.right, 0.001));
      expect(expanded.bottom, closeTo(collapsed.bottom, 0.001));
      expect(expanded.top, lessThan(collapsed.top));
      expect(expanded.width, greaterThan(collapsed.width));
    });

    test('宠物贴底时展开仍不越出工作区', () {
      final expanded = petBounds(area: area, edge: WindowEdge.left, anchorY: 1, expanded: true);

      expect(expanded.bottom, lessThanOrEqualTo(area.bottom + 0.001));
      expect(expanded.top, greaterThanOrEqualTo(area.top - 0.001));
    });
  });

  group('松手落位', () {
    // 使用者 2026-10-26：只允许桌宠出现在桌面右缘，换侧判定整块去掉，只留纵向。
    test('拖到左边松手也只算纵向，横向一律回右缘', () {
      final anchorY = settleAnchorY(
        area: area,
        current: const Rect.fromLTWH(100, 300, 156, 156),
      );

      final restored = petBounds(
        area: area,
        edge: WindowEdge.right,
        anchorY: anchorY,
        expanded: false,
      );
      expect(restored.right, closeTo(area.right, 0.001));
      expect(restored.top, closeTo(300, 0.5));
    });

    test('落位回读后能原样摆回去，误差不超过一个像素', () {
      final side = petBoxSide(area, expanded: false);
      final current = Rect.fromLTWH(1500, 300, side, side);
      final anchorY = settleAnchorY(area: area, current: current);
      final restored = petBounds(
        area: area,
        edge: WindowEdge.right,
        anchorY: anchorY,
        expanded: false,
      );

      expect(restored.top, closeTo(current.top, 1));
      expect(restored.right, closeTo(area.right, 0.001));
    });

    test('松开的是展开框时，收回收起框也贴住同一个底边', () {
      final collapsedSide = petBoxSide(area, expanded: false);
      final expandedSide = petBoxSide(area, expanded: true);
      // 展开态松手判定认的是宠物那块框（窗口并集里的 pet），不是整个窗口。
      final current = Rect.fromLTWH(1400, 200, expandedSide, expandedSide);

      final anchorY = settleAnchorY(area: area, current: current);
      final restored = petBounds(
        area: area,
        edge: WindowEdge.right,
        anchorY: anchorY,
        expanded: false,
      );

      // 锚点按底边反推：收起框的底边落在原位，视觉上宠物脚底没跳。
      expect(restored.bottom, closeTo(current.bottom, 0.5));
      expect(restored.height, closeTo(collapsedSide, 0.001));
      expect(restored.right, closeTo(area.right, 0.001));
    });

    test('多显示器原点为负时也贴得住', () {
      const second = ScreenWorkArea(left: -1920, top: -200, width: 1920, height: 1040);
      final side = petBoxSide(second, expanded: false);
      final anchorY = settleAnchorY(
        area: second,
        current: Rect.fromLTWH(-1900, -100, side, side),
      );
      final restored = petBounds(
        area: second,
        edge: WindowEdge.right,
        anchorY: anchorY,
        expanded: false,
      );

      expect(restored.right, closeTo(second.right, 0.001));
      expect(restored.top, greaterThanOrEqualTo(-200));
    });
  });
}
