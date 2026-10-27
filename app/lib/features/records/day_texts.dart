/// 右栏里一条文字的钥匙：`日期|组键|条目`。
///
/// 组键是 `soloKey` 或项目 id，条目是事项 id；今日小结没有组与条目，
/// 两段都退化成 `summary`（见 [dayTextKey]）。感想与总结各存一列，
/// 所以同一条事项的这两个键相同、owner 类型不同，互不覆盖。
String entryTextKey(String date, String groupKey, String itemId) => '$date|$groupKey|$itemId';

/// 今日小结那块的钥匙，`日期|summary|summary`。
String dayTextKey(String date) => entryTextKey(date, 'summary', 'summary');

/// 某一天全部文字的钥匙前缀。按它一次取出这天的感想与总结。
String dayTextPrefix(String date) => '$date|';

/// 一条事项展开后那段 AI 总结属于哪一态。
///
/// 顺序照原型第五页 `summaryBlock`：我改过的压过一切，没 key 就降级成随手记，
/// 有 key 但这条没用过 AI 就留白。
enum EntrySummaryKind {
  /// 我自己改过，之后生成值再变也不动它。
  mine,

  /// 配了 key，且这条问过 AI，显示整理出来的那段。
  generated,

  /// 没配 key：降级成随手记原文，界面另给一行提示。
  degraded,

  /// 配了 key 但这条没用过 AI，也还没写：留白，只给「写总结」。
  blank,
}

/// 一条事项展开区里那段总结的最终样子。
class EntrySummary {
  const EntrySummary({required this.kind, this.text = ''});

  /// 第四态的空块，界面只画一个「写总结」。
  static const EntrySummary blank = EntrySummary(kind: EntrySummaryKind.blank);

  final EntrySummaryKind kind;

  /// 要显示的正文；[EntrySummaryKind.blank] 时为空串。
  final String text;

  bool get isEmpty => text.trim().isEmpty;

  /// 没配 key 才需要那行「先按随手记整合」。
  bool get degraded => kind == EntrySummaryKind.degraded;

  /// 右下角那个按钮：有正文就是「编辑」，没有就是「写总结」。
  String get actionLabel => isEmpty ? '写总结' : '编辑';
}

/// 判定一段总结该显示什么。
///
/// 四个输入分别来自：我改过的版本（notes 表）、设置里的 key、这条当天问没问过 AI、
/// 以及随手记原文。判定本身不碰数据库，界面与测试共用这一份。
EntrySummary entrySummaryOf({
  required String userText,
  required bool hasKey,
  required bool usedAi,
  required String generated,
  required String scratch,
}) {
  if (userText.trim().isNotEmpty) {
    return EntrySummary(kind: EntrySummaryKind.mine, text: userText.trim());
  }
  if (!hasKey) {
    return EntrySummary(kind: EntrySummaryKind.degraded, text: scratch.trim());
  }
  if (usedAi) {
    return EntrySummary(kind: EntrySummaryKind.generated, text: generated.trim());
  }
  return EntrySummary.blank;
}

/// 有 key、这条也问过 AI 时那段总结的正文。
///
/// B22 接上模型之后这里换成真生成；现在先把「问过的最后一句 + 随手记」拼出来，
/// 让这一态与「留白」「降级」在界面上真的不一样，不假装是模型写的。
String entryGeneratedText({required String scratch, required String lastAnswer}) {
  final parts = <String>[
    if (lastAnswer.trim().isNotEmpty) lastAnswer.trim(),
    if (scratch.trim().isNotEmpty) scratch.trim(),
  ];
  return parts.join('\n');
}

/// 一条事项展开区里要用的文字，全是「当天这一条」的。
///
/// 由 Notifier 一次读齐后放进状态，界面不再自己查库，也不必知道哪一段存哪。
class EntryTexts {
  const EntryTexts({
    this.userSummary = '',
    this.thought = '',
    this.generated = '',
    this.scratch = '',
    this.usedAi = false,
  });

  /// 还什么都没写的空箱子。
  static const EntryTexts empty = EntryTexts();

  /// 我改过的那版总结，压过生成值。
  final String userSummary;

  /// 我的感想。
  final String thought;

  /// 配了 key 时能给出的整理结果；没用到就是空串。
  final String generated;

  /// 随手记原文，没配 key 时降级用它。
  final String scratch;

  /// 这条当天问过 AI 没有。
  final bool usedAi;

  /// 这段总结最终该显示成哪一态。
  EntrySummary summaryOf({required bool hasKey}) => entrySummaryOf(
    userText: userSummary,
    hasKey: hasKey,
    usedAi: usedAi,
    generated: generated,
    scratch: scratch,
  );

  EntryTexts copyWith({String? userSummary, String? thought}) => EntryTexts(
    userSummary: userSummary ?? this.userSummary,
    thought: thought ?? this.thought,
    generated: generated,
    scratch: scratch,
    usedAi: usedAi,
  );
}
