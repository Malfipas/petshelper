/// 两档气泡的内容高度。
///
/// 整体原型的气泡是内容自然高度（`.bubble{max-height:30vh}`，超出在气泡内部滚动），
/// 而窗口必须先知道「占多高」才让得开头顶那块地方。这里按字号与行数把高度算出来，
/// 界面与窗口共用同一份数，两边不会漂。
///
/// 每个数都对着 `prototype/整体原型.html` 的 `.bubble` 规则抄：内边距 13×15、
/// 标题 12 号、事务名 14 号、行 13 号配 1.6 倍行高、按钮 30 高。
class BubbleMetrics {
  const BubbleMetrics._();

  /// 气泡内边距，原型 `.bubble{padding:13px 15px}`。
  static const double paddingV = 13;
  static const double paddingH = 15;

  /// 气泡圆角，原型 `border-radius:12px`。
  static const double radius = 12;

  /// 标题行高，原型 `.bt{font-size:12px}` 配 1.5 倍行高。
  static const double titleHeight = 18;

  /// 标题与内容之间，原型 `.bt{margin-bottom:6px}`。
  static const double titleGap = 6;

  /// 事务名行高，原型 `.bname{font-size:14px;line-height:1.5}`。
  static const double nameHeight = 21;

  /// 操作行与内容之间，原型 `.bx{margin-top:10px}`。
  static const double footerGap = 10;

  /// 操作行高度，原型 `.bx button{min-height:30px}`。
  static const double footerHeight = 30;

  /// 播报的一行，原型 `.brow{padding:7px 0;font-size:13px;line-height:1.6}`。
  ///
  /// 行与行之间那道虚线占 1 像素，算进来才不会把最后一行挤出去。
  static const double rowHeight = 1 + 14 + 13 * 1.6;

  /// 播报首行上内边距更小，原型 `.brow:first-of-type{padding-top:2px}`，且没有分隔线。
  static const double rowHeightFirst = 2 + 7 + 13 * 1.6;

  /// 截止气泡第二行那句红字：「将于 2026年10月31日 截止」，12 号配 1.5 倍行高。
  static const double dueHeight = 18;

  /// 舍入余量：窗口宁可多让几像素，也不裁字。
  static const double slack = 4;

  /// 气泡栈里两块之间的缝。
  static const double stackGap = 8;

  /// 截止气泡要占的高度：事务名 + 截止那句 + 操作行。
  static double deadline() =>
      paddingV * 2 + nameHeight + dueHeight + footerGap + footerHeight + slack;

  /// [count] 块截止气泡摞起来的高度。
  static double deadlineStack(int count) {
    if (count <= 0) return 0;
    return deadline() * count + stackGap * (count - 1);
  }

  /// 播报气泡要占的高度：每项目一行 + 操作行。
  static double report({required int rows}) {
    var height = paddingV * 2 + footerGap + footerHeight + slack;
    for (var i = 0; i < rows; i++) {
      height += i == 0 ? rowHeightFirst : rowHeight;
    }
    return height;
  }
}
