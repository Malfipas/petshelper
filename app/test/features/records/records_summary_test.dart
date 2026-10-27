import 'dart:async';

import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart';
import 'package:ai_pet_assistant/domain/model/day_digest.dart';
import 'package:ai_pet_assistant/domain/port/day_summarizer.dart';
import 'package:ai_pet_assistant/features/records/records_notifier.dart';
import 'package:ai_pet_assistant/features/records/records_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 右栏「今日小结」那条路：点按钮才发请求、降级留提示、我改过的不覆盖。
///
/// 请求本身在 `test/ai/ai_day_summarizer_test.dart` 与 `usecases_test.dart`
/// 分别覆盖，这里只看页面上看得见的那几格。
class _FakeSummarizer implements DaySummarizer {
  /// 模型会答什么；null 表示没 key 或这次没成。
  String? answer;

  /// 设了就一直挂着，用来检查「生成中…」那一帧。
  Completer<void>? gate;

  DayDigest? seen;
  int calls = 0;

  @override
  Future<String?> summarize(DayDigest digest) async {
    calls++;
    seen = digest;
    final pending = gate;
    if (pending != null) await pending.future;
    return answer;
  }
}

void main() {
  late AppDb db;
  late ProviderContainer container;
  late _FakeSummarizer summarizer;

  final base = DateTime(2026, 10, 24, 9);

  setUp(() {
    db = AppDb.memory();
    summarizer = _FakeSummarizer();
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        recordCalendarProvider.overrideWith(
          () => RecordCalendarNotifier(now: () => base),
        ),
        daySummarizerProvider.overrideWithValue(summarizer),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: 704, height: 560, child: RecordsPage())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 某天跑过一段 45 分钟的事项，日总结才有材料可写。
  Future<void> seedDay(DateTime day) async {
    final tasks = container.read(taskRepositoryProvider);
    final end = DateTime(day.year, day.month, day.day, 9);
    final from = end.subtract(const Duration(minutes: 45)).millisecondsSinceEpoch;
    final id = await tasks.createSolo(name: '写第三章', nowMs: from);
    await tasks.logSession(
      taskId: id,
      startedAt: from,
      endedAt: end.millisecondsSinceEpoch,
      seconds: 45 * 60,
    );
    await tasks.setDone(id, true, end.millisecondsSinceEpoch);
  }

  Future<void> seedToday() => seedDay(base);

  const today = '2026-10-24';

  final generateButton = find.byKey(const ValueKey<String>('records-day-summary-generate'));

  testWidgets('点「生成小结」：请求带的是选中的这天，回来后正文与按钮一起变', (tester) async {
    await seedToday();
    await pumpPage(tester);
    expect(find.text('生成小结'), findsOneWidget);

    summarizer.answer = '今天写完第三章，45 分钟都花在它上面。';
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(summarizer.calls, 1);
    expect(summarizer.seen?.date, today);
    expect(find.text('今天写完第三章，45 分钟都花在它上面。'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
    // 落库了：下次进这一天直接读，不再烧一次额度。
    final stored = await container.read(recordRepositoryProvider).byDate(today);
    expect(stored?.summaryText, '今天写完第三章，45 分钟都花在它上面。');
  });

  testWidgets('没配 key：照样能点，出来的是流水账，上方留一行说明', (tester) async {
    await seedToday();
    await pumpPage(tester);

    summarizer.answer = null;
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('records-day-summary-degraded')), findsOneWidget);
    expect(find.text('未配置 API key，先按随手记整合'), findsOneWidget);
    // 降级也有正文，不是空白。
    expect(find.byKey(const ValueKey<String>('records-day-summary-ai')), findsOneWidget);
  });

  testWidgets('我改过这一天的总结：点了也不覆盖', (tester) async {
    await seedToday();
    // reviseSummary 才是「人改的」那条路，setSummary 是 AI 写的。
    final records = container.read(recordRepositoryProvider);
    await records.ensureDay(today, base.millisecondsSinceEpoch);
    await records.reviseSummary(today, '我自己的说法', base.millisecondsSinceEpoch);
    await pumpPage(tester);

    summarizer.answer = '模型写的另一段';
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('我自己的说法'), findsOneWidget);
    expect(find.text('模型写的另一段'), findsNothing);
    // 也没往降级那条路上走。
    expect(find.byKey(const ValueKey<String>('records-day-summary-degraded')), findsNothing);
  });

  testWidgets('等模型的时候按钮变「生成中…」且点不动，回来后复原', (tester) async {
    await seedToday();
    await pumpPage(tester);

    summarizer.answer = '写完了。';
    summarizer.gate = Completer<void>();
    await tester.tap(generateButton);
    await tester.pump();

    expect(find.text('生成中…'), findsOneWidget);

    // 挂着的时候再点一下，不该再发一次请求。
    await tester.tap(generateButton, warnIfMissed: false);
    await tester.pump();
    expect(summarizer.calls, 1);

    summarizer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('写完了。'), findsOneWidget);
    expect(find.text('生成中…'), findsNothing);
  });

  testWidgets('等的时候换了日子：回来不把那段写到新的一天上', (tester) async {
    await seedToday();
    await seedDay(DateTime(2026, 10, 23));
    await pumpPage(tester);

    summarizer.answer = '今天写的这段。';
    summarizer.gate = Completer<void>();
    await tester.tap(generateButton);
    await tester.pump();

    // 切到前一天（那天也有内容，右栏不是空态）。
    await tester.tap(find.text('23').first);
    await tester.pumpAndSettle();

    summarizer.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('今天写的这段。'), findsNothing);
    expect(find.text('生成小结'), findsOneWidget);
  });
}
