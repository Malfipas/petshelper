import '../domain/model/day_digest.dart';
import '../domain/port/day_summarizer.dart';
import 'chat_client.dart';
import 'prompts.dart';

/// 用模型写一段日总结。
///
/// 没 key 与这次没成都返回 null——`SummarizeDay` 据此降级成随手记的机械
/// 整合，宁可给一段流水账，也不留空白。
class AiDaySummarizer implements DaySummarizer {
  const AiDaySummarizer(this._client);

  final ChatClient _client;

  @override
  Future<String?> summarize(DayDigest digest) async {
    // 一天什么都没留下就不必问模型，问回来也只会是客套话。
    if (digest.isEmpty) return null;

    final outcome = await _client.complete(
      system: summarySystemPrompt,
      user: summaryUserPrompt(digest),
    );
    return switch (outcome) {
      ChatReply(:final text) => cleanSummary(text),
      ChatNoKey() || ChatError() => null,
    };
  }
}

/// 一段总结最长多少字。超过就截，卡片里再长也是一坨。
const int maxSummaryChars = 200;

/// markdown 的标题井号、列表符号与粗体星号。
///
/// 行首只吃空格与制表符，不吃换行——用 `\s*` 会把上一行留下的空行一起吞掉，
/// 段落就粘成一坨了。
final RegExp _heading = RegExp(r'^[ \t]*#{1,6}[ \t]*', multiLine: true);
final RegExp _bullet = RegExp(r'^[ \t]*[-*·][ \t]+', multiLine: true);

/// 把模型那段话收拾成能放进卡片的一段正文；收拾完不成样子就返回 null。
///
/// 提示词里已经不许用 Markdown，但模型偶尔不听话：卡片里只有一种字号，
/// 井号与星号留着只是噪音，去掉比显示出来好。
String? cleanSummary(String raw) {
  final text = raw
      .replaceAll(_heading, '')
      .replaceAll(_bullet, '')
      .replaceAll('**', '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (text.isEmpty) return null;
  if (text.length <= maxSummaryChars) return text;
  return '${text.substring(0, maxSummaryChars)}…';
}
