import 'dart:ui' show Color;

import '../../domain/model/task_day_entry.dart';
import 'day_record.dart';
import 'day_texts.dart';
import 'records_calendar.dart';

/// 日历一格上的数：完成几件、底部色带由哪几段拼成。
class DayStat {
  const DayStat({this.doneCount = 0, this.segments = const <DaySegment>[]});

  /// 当天完成的事项数，0 时格子右下角不写字。
  final int doneCount;

  final List<DaySegment> segments;

  DayStat copyWith({int? doneCount, List<DaySegment>? segments}) => DayStat(
    doneCount: doneCount ?? this.doneCount,
    segments: segments ?? this.segments,
  );
}

/// 第 5 页左栏的全部状态：正在看哪个月、选中哪天、每格怎么画、图例高亮谁。
class RecordsState {
  const RecordsState({
    required this.year,
    required this.month,
    required this.selected,
    this.cells = const <CalendarCell>[],
    this.stats = const <String, DayStat>{},
    this.legend = const <LegendItem>[],
    this.projectColors = const <String, Color>{},
    this.highlight,
    this.dayEntries = const <TaskDayEntry>[],
    this.dayGroups = const <DayGroup>[],
    this.openKeys = const <String>{},
    this.daySeconds = 0,
    this.dayProjects = const <String, Set<String>>{},
    this.dayDoneCount = 0,
    this.dayProjectCount = 0,
    this.hasKey = false,
    this.summaryText = '',
    this.summaryBusy = false,
    this.summaryDegraded = false,
    this.entryTexts = const <String, EntryTexts>{},
    this.loading = true,
  });

  final int year;
  final int month;

  /// 选中的那一天，`yyyy-MM-dd`。
  final String selected;

  /// 六行七列的格子，含上下月补白。
  final List<CalendarCell> cells;

  /// 日期键 → 件数与色带。
  final Map<String, DayStat> stats;

  final List<LegendItem> legend;

  /// 项目 id → 颜色。按项目新建先后固定，右栏的事项色点也走这张表。
  final Map<String, Color> projectColors;

  /// 图例上正高亮的那一项，其余色段压到 25% 透明。
  final String? highlight;

  /// 右栏这一天动过的事项：开过表的，加上只标记完成的。顺序由分组定。
  final List<TaskDayEntry> dayEntries;

  /// 右栏的分组：独立事项在前，项目按当天投入从多到少。
  final List<DayGroup> dayGroups;

  /// 已经展开的那些事项的 id。切日期时清空，回来仍默认收起。
  final Set<String> openKeys;

  /// 当天投入合计，秒。今日小结那一行用。
  final int daySeconds;

  /// 日期键 → 这一天推进过的项目。
  ///
  /// 「推进」按两件事算：当天在这个项目上开过表，或当天完成了这个项目里的一件事。
  /// 只点「标记完成」、没跑过秒的事项没有流水，光看流水会把它漏成 0。
  final Map<String, Set<String>> dayProjects;

  /// 右栏标题右侧报的件数。独立事项与项目事项一起算，PRD 写的是「完成 5 件 · 推进 2 个项目」。
  final int dayDoneCount;

  /// 这一天推进过几个项目，独立事项不算。
  final int dayProjectCount;

  /// 配了 key 没有。它决定每条总结走「生成」还是「降级成随手记」。
  final bool hasKey;

  /// 选中这一天已生成好的日总结，今日小结那段用它。
  final String summaryText;

  /// 正在等模型写这一段。期间按钮变「生成中…」且不再受理点击。
  final bool summaryBusy;

  /// 这一段是降级来的（没 key 或这次没成，写的是随手记的机械整合）。
  /// 界面据此在正文上方留一行说明，与 PRD 里「先按随手记整合」一致。
  final bool summaryDegraded;

  /// 钥匙 → 这一条展开区要用的文字。钥匙由 `entryTextKey` 拼。
  final Map<String, EntryTexts> entryTexts;

  final bool loading;

  DayStat? statOf(String key) => stats[key];

  /// 取某一条的文字，没有就给空箱子，界面不必到处判空。
  EntryTexts textsOf(String key) => entryTexts[key] ?? EntryTexts.empty;

  RecordsState copyWith({
    int? year,
    int? month,
    String? selected,
    List<CalendarCell>? cells,
    Map<String, DayStat>? stats,
    List<LegendItem>? legend,
    Map<String, Color>? projectColors,
    String? highlight,
    bool clearHighlight = false,
    List<TaskDayEntry>? dayEntries,
    List<DayGroup>? dayGroups,
    Set<String>? openKeys,
    int? daySeconds,
    Map<String, Set<String>>? dayProjects,
    int? dayDoneCount,
    int? dayProjectCount,
    bool? hasKey,
    String? summaryText,
    bool? summaryBusy,
    bool? summaryDegraded,
    bool clearSummaryDegraded = false,
    Map<String, EntryTexts>? entryTexts,
    bool? loading,
  }) => RecordsState(
    year: year ?? this.year,
    month: month ?? this.month,
    selected: selected ?? this.selected,
    cells: cells ?? this.cells,
    stats: stats ?? this.stats,
    legend: legend ?? this.legend,
    projectColors: projectColors ?? this.projectColors,
    highlight: clearHighlight ? null : (highlight ?? this.highlight),
    dayEntries: dayEntries ?? this.dayEntries,
    dayGroups: dayGroups ?? this.dayGroups,
    openKeys: openKeys ?? this.openKeys,
    daySeconds: daySeconds ?? this.daySeconds,
    dayProjects: dayProjects ?? this.dayProjects,
    dayDoneCount: dayDoneCount ?? this.dayDoneCount,
    dayProjectCount: dayProjectCount ?? this.dayProjectCount,
    hasKey: hasKey ?? this.hasKey,
    summaryText: summaryText ?? this.summaryText,
    summaryBusy: summaryBusy ?? this.summaryBusy,
    summaryDegraded: clearSummaryDegraded ? false : (summaryDegraded ?? this.summaryDegraded),
    entryTexts: entryTexts ?? this.entryTexts,
    loading: loading ?? this.loading,
  );
}
