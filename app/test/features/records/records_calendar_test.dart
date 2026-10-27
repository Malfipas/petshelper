import 'package:ai_pet_assistant/data/repository/record_repository.dart';
import 'package:ai_pet_assistant/features/records/records_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// 月历的纯规则：怎么排格子、色带怎么拼、图例列谁。
///
/// 《页面操作流程》第 5 节定的口径：周一打头、六行七列、底部 3 像素分段色条、
/// 独立事项固定灰、项目六色轮换、一天最多四个项目段、图例只列当月投入前四。
void main() {
  group('日历格子', () {
    test('一个月固定六行七列，周一打头，首尾用上下月的日子补齐', () {
      final cells = monthCells(2026, 10);

      expect(cells, hasLength(42));
      // 2026-10-01 是周四，第一个格子退回 9 月 28 日（周一）。
      expect(cells.first.date, DateTime(2026, 9, 28));
      expect(cells.first.inMonth, isFalse);
      expect(cells[3].date, DateTime(2026, 10, 1));
      expect(cells[3].inMonth, isTrue);
      expect(cells.where((cell) => cell.inMonth), hasLength(31));
    });

    test('格子键是补零的 yyyy-MM-dd', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(monthKey(2026, 1), '2026-01');
    });

    test('月份条与右栏标题的写法', () {
      expect(monthLabel(2026, 10), '2026 年 10 月');
      expect(dayTitle(DateTime(2026, 10, 23)), '10 月 23 日 周五');
      expect(dayTitle(DateTime(2026, 10, 19)), '10 月 19 日 周一');
    });

    test('投入时长不足一分钟不写 0 分钟', () {
      expect(minutesLabel(0), '不到 1 分钟');
      expect(minutesLabel(20), '不到 1 分钟');
      expect(minutesLabel(1500), '25 分钟');
    });
  });

  group('色带', () {
    ProjectSpend spend(String id, int seconds) => ProjectSpend(
      id: id,
      name: id,
      color: projectPalette[0],
      seconds: seconds,
    );

    test('独立事项排第一段，项目按投入从多到少', () {
      final segments = daySegments(
        soloSeconds: 300,
        projects: [spend('p1', 600), spend('p2', 1800)],
      );

      expect(segments.map((segment) => segment.key), [soloKey, 'p2', 'p1']);
      expect(segments.first.color, soloColor);
      expect(segments.first.seconds, 300);
    });

    test('没有投入的段不出现', () {
      expect(daySegments(soloSeconds: 0, projects: [spend('p1', 0)]), isEmpty);
    });

    test('第五个项目起并成「其他项目」，秒数累加', () {
      final segments = daySegments(
        soloSeconds: 0,
        projects: [
          spend('p1', 500),
          spend('p2', 400),
          spend('p3', 300),
          spend('p4', 200),
          spend('p5', 100),
          spend('p6', 50),
        ],
      );

      expect(segments, hasLength(5));
      expect(segments.map((segment) => segment.key).toList(), ['p1', 'p2', 'p3', 'p4', restKey]);
      expect(segments.last.seconds, 150);
      expect(segments.last.color, restColor);
    });

    test('一天最多四段项目加上一段独立事项', () {
      final segments = daySegments(
        soloSeconds: 60,
        projects: [for (var i = 0; i < 8; i++) spend('p$i', 100 - i)],
      );

      expect(segments.first.key, soloKey);
      expect(segments.where((segment) => segment.key == restKey), hasLength(1));
      expect(segments.length, lessThanOrEqualTo(maxProjectSegments + 2));
    });
  });

  group('图例', () {
    ProjectSpend spend(String id, int seconds) => ProjectSpend(
      id: id,
      name: '项目$id',
      color: projectPalette[0],
      seconds: seconds,
    );

    test('只列当月有投入的项目，按投入从多到少取前四', () {
      final items = legendItems(
        soloSeconds: 0,
        projects: [
          spend('p1', 100),
          spend('p2', 300),
          spend('p3', 0),
          spend('p4', 200),
          spend('p5', 50),
        ],
      );

      expect(items.map((item) => item.label).toList(), ['项目p2', '项目p4', '项目p1', '项目p5']);
    });

    test('超过四个项目补「其他项目」，独立事项排最后', () {
      final items = legendItems(
        soloSeconds: 120,
        projects: [for (var i = 0; i < 5; i++) spend('p$i', 100 + i)],
      );

      expect(items.last.key, soloKey);
      expect(items.map((item) => item.key).toList(), ['p4', 'p3', 'p2', 'p1', restKey, soloKey]);
      expect(items[items.length - 2].label, '其他项目');
    });

    test('一件没投入时图例空着', () {
      expect(
        legendItems(soloSeconds: 0, projects: [spend('p1', 0)]),
        isEmpty,
      );
    });
  });

  group('配色', () {
    test('项目六色轮换，第 7 个项目回到第一个颜色', () {
      expect(projectColorAt(0), projectPalette[0]);
      expect(projectColorAt(5), projectPalette[5]);
      expect(projectColorAt(6), projectPalette[0]);
    });

    test('独立事项的键与取数层写的是同一个值', () {
      expect(soloKey, RecordRepository.soloKey);
    });
  });
}
