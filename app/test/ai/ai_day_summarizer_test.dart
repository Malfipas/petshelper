import 'package:ai_pet_assistant/ai/ai_day_summarizer.dart';
import 'package:ai_pet_assistant/ai/chat_client.dart';
import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/model/day_digest.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements ChatClient {
  _FakeClient(this._outcome);

  final ChatOutcome _outcome;
  String? user;
  int calls = 0;

  @override
  Future<ChatOutcome> complete({
    required String system,
    required String user,
    List<AiAttachment> attachments = const [],
  }) async {
    calls++;
    this.user = user;
    return _outcome;
  }
}

DayDigest _digest() => const DayDigest(
  date: '2026-10-27',
  doneNames: ['写第三章', '对图表'],
  items: [
    DayDigestItem(name: '写第三章', seconds: 2700, note: '比想象中快'),
    DayDigestItem(name: '对图表', seconds: 3000),
  ],
);

void main() {
  group('AiDaySummarizer', () {
    test('答得上：返回一段正文，材料里带完成件数、分钟数与随手记', () async {
      final client = _FakeClient(const ChatReply('今天主要写第三章，比想象中快。'));
      final summarizer = AiDaySummarizer(client);

      final result = await summarizer.summarize(_digest());

      expect(result, '今天主要写第三章，比想象中快。');
      expect(client.user, contains('日期：2026-10-27'));
      expect(client.user, contains('完成：2 件'));
      // 5700 秒换成 95 分钟，不把秒数原样搬给模型。
      expect(client.user, contains('投入：95 分钟'));
      expect(client.user, contains('写第三章｜45 分钟｜随手记：比想象中快'));
      expect(client.user, contains('对图表｜50 分钟'));
      expect(client.user, isNot(contains('秒')));
    });

    test('这天什么都没有就不发请求', () async {
      final client = _FakeClient(const ChatReply('随便写点'));

      final result = await AiDaySummarizer(client).summarize(
        const DayDigest(date: '2026-10-27'),
      );

      expect(result, isNull);
      expect(client.calls, 0);
    });

    test('没配 key：返回 null，交给用例降级', () async {
      final summarizer = AiDaySummarizer(_FakeClient(const ChatNoKey()));

      expect(await summarizer.summarize(_digest()), isNull);
    });

    test('这次没成：返回 null，别把半截话写进库', () async {
      final summarizer = AiDaySummarizer(_FakeClient(const ChatError('限流了')));

      expect(await summarizer.summarize(_digest()), isNull);
    });
  });

  group('cleanSummary', () {
    test('去掉井号标题、列表符号与粗体星号', () {
      expect(
        cleanSummary('## 今天\n\n- **写完第三章**\n- 对了图表'),
        '今天\n\n写完第三章\n对了图表',
      );
    });

    test('空话返回 null', () {
      expect(cleanSummary('   \n  '), isNull);
    });

    test('过长按上限截断', () {
      final long = '写' * (maxSummaryChars + 40);

      final result = cleanSummary(long);

      expect(result, isNotNull);
      expect(result!.length, maxSummaryChars + 1);
      expect(result.endsWith('…'), isTrue);
    });
  });
}
