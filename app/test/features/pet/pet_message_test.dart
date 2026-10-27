import 'package:ai_pet_assistant/domain/model/project_digest.dart';
import 'package:ai_pet_assistant/features/pet/pet_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// 头顶气泡的文案与截止档位。全部按日历日算，不按 24 小时。
void main() {
  final now = DateTime(2026, 10, 23, 9).millisecondsSinceEpoch;
  int at(int hour, int minute, {int day = 23}) =>
      DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;

  ProjectDigest digest({
    String id = 'p1',
    String name = '配音练习',
    int? dueAt,
    int doneSteps = 1,
    int totalSteps = 2,
    int? lastAdvancedAt,
    String? currentStepName,
  }) {
    return ProjectDigest(
      projectId: id,
      name: name,
      dueAt: dueAt,
      doneSteps: doneSteps,
      totalSteps: totalSteps,
      lastAdvancedAt: lastAdvancedAt,
      currentStepName: currentStepName,
    );
  }

  group('截止档位', () {
    test('还早、正好过了、已经过期，都不提醒', () {
      expect(
        deadlineStageOf(dueAt: now + const Duration(hours: 30).inMilliseconds, now: now),
        DeadlineStage.none,
      );
      expect(deadlineStageOf(dueAt: now, now: now), DeadlineStage.none);
      expect(deadlineStageOf(dueAt: now - 1000, now: now), DeadlineStage.none);
    });

    test('一天内两档：24 小时内、2 小时内', () {
      expect(deadlineStageOf(dueAt: now + 3 * 3600 * 1000, now: now), DeadlineStage.withinDay);
      expect(deadlineStageOf(dueAt: now + 90 * 60 * 1000, now: now), DeadlineStage.withinTwoHours);
      expect(deadlineStageOf(dueAt: now + 24 * 3600 * 1000, now: now), DeadlineStage.withinDay);
    });
  });

  group('挑最近的一条', () {
    test('多个项目同时逼近只留最早的那个，并带上当前步骤名', () {
      final hint = nearestDeadline([
        digest(id: 'p1', name: '求职', dueAt: at(18, 0), currentStepName: '回面试邮件'),
        digest(id: 'p2', name: '配音练习', dueAt: at(23, 59)),
      ], now: now);

      expect(hint, isNotNull);
      expect(hint!.projectId, 'p1');
      expect(hint.name, '求职 · 回面试邮件');
      expect(hint.stage, DeadlineStage.withinDay);
      expect(hint.urgent, isFalse);
    });

    test('没有截止与已过期的项目都跳过', () {
      expect(
        nearestDeadline([digest(id: 'p1'), digest(id: 'p2', dueAt: now - 1000)], now: now),
        isNull,
      );
    });

    test('两小时内的标成紧急', () {
      final hint = nearestDeadline([digest(dueAt: at(10, 30))], now: now);

      expect(hint!.urgent, isTrue);
      expect(hint.stage, DeadlineStage.withinTwoHours);
    });
  });

  group('截止怎么说', () {
    test('写死日期，不带时刻', () {
      // 《页面操作流程》第 3 节：「将于*截止日期*截止」。写死日期是因为截止气泡
      // 不自动消失，飘到第二天「今天」就不成立了。
      expect(dueLabel(at(23, 59), now: now), '将于 2026年10月23日 截止');
      expect(dueLabel(at(9, 5, day: 24), now: now), '将于 2026年10月24日 截止');
    });

    test('过了的日子也照写日期，不说昨天', () {
      expect(dueLabel(at(20, 0, day: 22), now: now), '将于 2026年10月22日 截止');
    });
  });

  group('上次推进怎么说', () {
    test('从没推进过就没有这一节', () {
      expect(lastAdvancedLabel(null, now: now), isNull);
    });

    test('按日历日算：今早、昨晚、前天', () {
      expect(lastAdvancedLabel(at(8, 0), now: now), '今天');
      expect(lastAdvancedLabel(at(23, 0, day: 22), now: now), '昨天');
      expect(lastAdvancedLabel(at(23, 0, day: 21), now: now), '前天');
    });

    test('一周内说几天前，再久就说月日', () {
      expect(lastAdvancedLabel(at(12, 0, day: 20), now: now), '3天前');
      expect(lastAdvancedLabel(at(12, 0, day: 10), now: now), '10-10');
    });
  });

  group('播报一行', () {
    test('有步骤有推进：项目名、进度、上次推进，竖线隔开', () {
      expect(reportLine(digest(lastAdvancedAt: at(8, 0)), now: now), '配音练习 1/2 50% | 今天');
    });

    test('没拆步骤就说没拆步骤，没推进过就不报时间', () {
      expect(
        reportLine(digest(doneSteps: 0, totalSteps: 0, lastAdvancedAt: null), now: now),
        '配音练习 还没拆步骤',
      );
    });
  });
}
