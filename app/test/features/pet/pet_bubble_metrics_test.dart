import 'package:ai_pet_assistant/features/pet/pet_bubble_metrics.dart';
import 'package:ai_pet_assistant/platform/window/pet_layout.dart';
import 'package:ai_pet_assistant/platform/window/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('气泡高度', () {
    test('截止气泡 = 内边距 + 事务名 + 截止那句 + 操作行 + 余量', () {
      // 《页面操作流程》第 3 节：三行，第一行名称、第二行红字、第三行按钮。
      expect(
        BubbleMetrics.deadline(),
        BubbleMetrics.paddingV * 2 +
            BubbleMetrics.nameHeight +
            BubbleMetrics.dueHeight +
            BubbleMetrics.footerGap +
            BubbleMetrics.footerHeight +
            BubbleMetrics.slack,
      );
    });

    test('截止气泡摞三块 = 三块相加再加两道缝', () {
      final one = BubbleMetrics.deadlineStack(1);
      final three = BubbleMetrics.deadlineStack(3);

      expect(one, closeTo(BubbleMetrics.deadline(), 0.001));
      expect(
        three,
        closeTo(BubbleMetrics.deadline() * 3 + BubbleMetrics.stackGap * 2, 0.001),
      );
      expect(BubbleMetrics.deadlineStack(0), 0);
    });

    test('播报每多一行就高一行，没有标题也没有「还有 N 个」', () {
      final one = BubbleMetrics.report(rows: 1);
      final two = BubbleMetrics.report(rows: 2);
      final three = BubbleMetrics.report(rows: 3);

      expect(two - one, closeTo(BubbleMetrics.rowHeight, 0.001));
      expect(three - two, closeTo(BubbleMetrics.rowHeight, 0.001));
    });

    test('三行播报还在工作区三成以内，不必滚动', () {
      const area = ScreenWorkArea(left: 0, top: 0, width: 1920, height: 1040);
      final height = BubbleMetrics.report(rows: 3);

      expect(height, lessThan(area.height * bubbleMaxHeightScale));
    });

    test('播报比截止高：它要多排几行', () {
      expect(BubbleMetrics.report(rows: 3), greaterThan(BubbleMetrics.deadline()));
    });
  });
}
