import 'dart:ui' show Color;

/// 项目依次取的六色：蓝、青、紫、橙、粉、天蓝。
///
/// 按项目新建先后固定，不随月份变；第 7 个项目回到第一个颜色。
const List<Color> projectPalette = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF14B8A6),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
];

/// 独立事项在色带与图例里的键。与 `RecordRepository.soloKey` 同值，
/// 由 `records_notifier_test` 钉住，免得两边各改各的。
const String soloKey = '__solo__';

/// 一天里项目段超过四个时，并出来的「其他项目」共用这个键。
const String restKey = '__rest__';

/// 一天最多摆几个项目段，多出来的并进「其他项目」。
const int maxProjectSegments = 4;

/// 独立事项那一段的灰。
const Color soloColor = Color(0xFF94A3B8);

/// 合并出来的「其他项目」用浅灰蓝。
const Color restColor = Color(0xFFCBD5E1);

/// 日历固定六行，跨月也排得开。
const int calendarRows = 6;

/// 一周的列标题，周一打头。
const List<String> weekdayLabels = <String>['一', '二', '三', '四', '五', '六', '日'];

const List<String> _weekdayNames = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String _two(int value) => value.toString().padLeft(2, '0');

/// 日期键，`yyyy-MM-dd`，也是日历格子的键与 `daily_records.date` 的格式。
String dateKey(DateTime date) => '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// 月份键，`yyyy-MM`。
String monthKey(int year, int month) => '$year-${_two(month)}';

/// 月份条中间那行字：`2026 年 10 月`。
String monthLabel(int year, int month) => '$year 年 $month 月';

/// 右栏标题：`10 月 23 日 周五`。
String dayTitle(DateTime date) => '${date.month} 月 ${date.day} 日 ${_weekdayNames[date.weekday - 1]}';

/// 投入时长的人话：不足一分钟不写「0 分钟」。
String minutesLabel(int seconds) {
  final minutes = (seconds / 60).round();
  return minutes <= 0 ? '不到 1 分钟' : '$minutes 分钟';
}

/// 日历上的一格。
///
/// [inMonth] 为假的是上下月补白：只露日期，不写件数，点了也不切记录。
class CalendarCell {
  const CalendarCell({required this.date, required this.inMonth});

  final DateTime date;
  final bool inMonth;

  String get key => dateKey(date);
}

/// 日历底部色带上的一段。
class DaySegment {
  const DaySegment({required this.key, required this.color, required this.seconds});

  /// 独立事项、某个项目，或合并出来的「其他项目」。
  final String key;
  final Color color;

  /// 这一段占多少秒，用来定宽窄比例。
  final int seconds;
}

/// 图例的一项。
class LegendItem {
  const LegendItem({required this.key, required this.label, required this.color});

  final String key;
  final String label;
  final Color color;
}

/// 一个项目在某个范围内的投入，色带与图例共用。
class ProjectSpend {
  const ProjectSpend({
    required this.id,
    required this.name,
    required this.color,
    required this.seconds,
  });

  final String id;
  final String name;
  final Color color;
  final int seconds;
}

/// 按项目新建先后取色，第 7 个项目回到第一个颜色。
Color projectColorAt(int index) => projectPalette[index % projectPalette.length];

int _secondsDesc(ProjectSpend a, ProjectSpend b) {
  final bySeconds = b.seconds.compareTo(a.seconds);
  // 秒数一样时按 id 兜底，免得每次重排顺序乱跳。
  return bySeconds != 0 ? bySeconds : a.id.compareTo(b.id);
}

/// 一屏六行七列，周一打头；首尾补上上下月的日子当白位。
List<CalendarCell> monthCells(int year, int month) {
  final first = DateTime(year, month);
  final start = DateTime(year, month, 1 - (first.weekday - 1));
  final cells = <CalendarCell>[];
  for (var i = 0; i < calendarRows * 7; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    cells.add(CalendarCell(date: date, inMonth: date.year == year && date.month == month));
  }
  return cells;
}

/// 一天的色带：独立事项在前，项目按投入从多到少排，第五个项目起并成「其他项目」。
List<DaySegment> daySegments({
  required int soloSeconds,
  required List<ProjectSpend> projects,
}) {
  final sorted = projects.where((spend) => spend.seconds > 0).toList()..sort(_secondsDesc);
  final head = sorted.take(maxProjectSegments);
  final restSeconds = sorted
      .skip(maxProjectSegments)
      .fold<int>(0, (sum, spend) => sum + spend.seconds);

  return <DaySegment>[
    if (soloSeconds > 0) DaySegment(key: soloKey, color: soloColor, seconds: soloSeconds),
    for (final spend in head) DaySegment(key: spend.id, color: spend.color, seconds: spend.seconds),
    if (restSeconds > 0) DaySegment(key: restKey, color: restColor, seconds: restSeconds),
  ];
}

/// 图例：当月投入前四的项目，有合并时补「其他项目」，独立事项有投入才列。
///
/// 顺序与原型一致：项目在前、合并项居中、独立事项最后。
List<LegendItem> legendItems({
  required List<ProjectSpend> projects,
  required int soloSeconds,
}) {
  final spent = projects.where((spend) => spend.seconds > 0).toList()..sort(_secondsDesc);
  return <LegendItem>[
    for (final spend in spent.take(maxProjectSegments))
      LegendItem(key: spend.id, label: spend.name, color: spend.color),
    if (spent.length > maxProjectSegments)
      const LegendItem(key: restKey, label: '其他项目', color: restColor),
    if (soloSeconds > 0)
      const LegendItem(key: soloKey, label: '独立事项', color: soloColor),
  ];
}
