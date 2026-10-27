/// 一天的日总结。按天一条，日期是唯一键。
///
/// `summaryEditedAt` 有值表示我自己动过，AI 之后不再覆盖；没动过才允许重新生成。
class DailyRecord {
  const DailyRecord({
    required this.id,
    required this.date,
    this.summaryText = '',
    this.summaryEditedAt,
    required this.createdAt,
  });

  final String id;

  /// `yyyy-MM-dd`。
  final String date;

  final String summaryText;

  /// 我改总结的时间，毫秒时间戳；没改过为 null。
  final int? summaryEditedAt;

  final int createdAt;

  bool get editedByUser => summaryEditedAt != null;

  bool get hasSummary => summaryText.trim().isNotEmpty;
}
