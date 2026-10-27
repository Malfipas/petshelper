import 'package:ai_pet_assistant/features/records/day_texts.dart';
import 'package:flutter_test/flutter_test.dart';

/// 第 5 页文字的键与 AI 总结四态：不含数据库，只验规则。
void main() {
  group('文字的钥匙', () {
    test('条目键是 日期|组键|条目', () {
      expect(entryTextKey('2026-10-23', 'p1', 't1'), '2026-10-23|p1|t1');
    });

    test('今日小结两段都退化成 summary', () {
      expect(dayTextKey('2026-10-23'), '2026-10-23|summary|summary');
    });

    test('前缀按天取，不串到别的日子', () {
      final prefix = dayTextPrefix('2026-10-23');
      expect('2026-10-23|p1|t1'.startsWith(prefix), isTrue);
      expect('2026-10-30|p1|t1'.startsWith(prefix), isFalse);
    });
  });

  group('AI 总结四态', () {
    test('我改过的最优先：有没有 key、用没用过 AI 都不动它', () {
      for (final hasKey in <bool>[true, false]) {
        for (final usedAi in <bool>[true, false]) {
          final summary = entrySummaryOf(
            userText: '我自己写的',
            hasKey: hasKey,
            usedAi: usedAi,
            generated: '生成的',
            scratch: '随手记',
          );
          expect(summary.kind, EntrySummaryKind.mine);
          expect(summary.text, '我自己写的');
          expect(summary.degraded, isFalse);
        }
      }
    });

    test('没配 key：降级成随手记原文，并挂那行提示', () {
      final summary = entrySummaryOf(
        userText: '',
        hasKey: false,
        usedAi: true,
        generated: '生成的',
        scratch: '随手记一句',
      );
      expect(summary.kind, EntrySummaryKind.degraded);
      expect(summary.text, '随手记一句');
      expect(summary.degraded, isTrue);
      expect(summary.actionLabel, '编辑');
    });

    test('没配 key 也没有随手记：只剩提示，按钮是「写总结」', () {
      final summary = entrySummaryOf(
        userText: '',
        hasKey: false,
        usedAi: false,
        generated: '',
        scratch: '  ',
      );
      expect(summary.kind, EntrySummaryKind.degraded);
      expect(summary.isEmpty, isTrue);
      expect(summary.degraded, isTrue);
      expect(summary.actionLabel, '写总结');
    });

    test('配了 key 且用过 AI：显示整理出来的那段', () {
      final summary = entrySummaryOf(
        userText: '',
        hasKey: true,
        usedAi: true,
        generated: '整理过的话',
        scratch: '随手记',
      );
      expect(summary.kind, EntrySummaryKind.generated);
      expect(summary.text, '整理过的话');
      expect(summary.degraded, isFalse);
    });

    test('配了 key 也没问过 AI：留白，只给「写总结」', () {
      final summary = entrySummaryOf(
        userText: '',
        hasKey: true,
        usedAi: false,
        generated: '',
        scratch: '随手记',
      );
      expect(summary.kind, EntrySummaryKind.blank);
      expect(summary.isEmpty, isTrue);
      expect(summary.actionLabel, '写总结');
    });

    test('写过的只有空白不算数，仍按后面几态走', () {
      final summary = entrySummaryOf(
        userText: '   ',
        hasKey: true,
        usedAi: false,
        generated: '',
        scratch: '',
      );
      expect(summary.kind, EntrySummaryKind.blank);
    });
  });

  test('整理的正文：先那句回答，再随手记，空的跳过', () {
    expect(entryGeneratedText(scratch: '记了 A', lastAnswer: '答了 B'), '答了 B\n记了 A');
    expect(entryGeneratedText(scratch: '记了 A', lastAnswer: ''), '记了 A');
    expect(entryGeneratedText(scratch: '', lastAnswer: ''), '');
  });

  test('EntryTexts 自己就能按 hasKey 判态', () {
    const texts = EntryTexts(scratch: '随手记', usedAi: true, generated: '整理');
    expect(texts.summaryOf(hasKey: false).kind, EntrySummaryKind.degraded);
    expect(texts.summaryOf(hasKey: true).kind, EntrySummaryKind.generated);
    expect(
      texts.copyWith(userSummary: '我写的').summaryOf(hasKey: false).kind,
      EntrySummaryKind.mine,
    );
  });
}
