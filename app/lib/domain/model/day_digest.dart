/// 日总结的原料：这一天做了什么、投入多久、随手记写了什么、有没有问过 AI。
///
/// 读模型，不是表。由 `SummarizeDay` 从几个 Repository 拼出来，再交给 AI 或降级路径。
class DayDigest {
  const DayDigest({required this.date, this.items = const [], this.doneNames = const []});

  /// `yyyy-MM-dd`。
  final String date;

  final List<DayDigestItem> items;

  /// 当天标记完成的事项名，按完成时间倒序。
  final List<String> doneNames;

  bool get isEmpty => items.isEmpty && doneNames.isEmpty && items.every((i) => i.note.isEmpty);

  /// 当天一共投入多少秒。
  int get totalSeconds => items.fold(0, (sum, item) => sum + item.seconds);
}

/// 一条事项在当天的样子：名称、投入、随手记、有没有问过 AI。
class DayDigestItem {
  const DayDigestItem({required this.name, this.seconds = 0, this.note = '', this.askedAi = false});

  final String name;
  final int seconds;
  final String note;
  final bool askedAi;

  bool get hasNote => note.trim().isNotEmpty;
}
