import '../model/day_digest.dart';

/// 日总结的那一下，由 `ai/` 层在 B23 实现。
///
/// 返回一段话；没配 key、超时、答非所问时返回 null——用例据此走降级路径，
/// 不拿空字符串或错误文案顶上去。
abstract interface class DaySummarizer {
  Future<String?> summarize(DayDigest digest);
}
