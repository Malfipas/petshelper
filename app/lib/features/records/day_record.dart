import '../../domain/model/step.dart';
import '../../domain/model/task_day_entry.dart';
import 'records_calendar.dart';

/// 右栏一组是独立事项，还是某个项目。
enum DayGroupKind { solo, project }

/// 一个项目的步骤快照：组头的 `3/7` 与那行推进说明都从它算。
///
/// 只带记录页用得到的三个数，不搬整套项目详情。
class ProjectSteps {
  ProjectSteps({
    required this.name,
    required List<Step> steps,
    required this.currentStep,
    this.dueAt,
    Map<String, int> openCounts = const <String, int>{},
  }) : steps = List<Step>.unmodifiable(
         // 步骤按流程顺序摆，组头写「第 N 步」才对得上号。
         steps.toList()..sort((a, b) => a.index.compareTo(b.index)),
       ),
       openCounts = Map<String, int>.unmodifiable(openCounts);

  /// 项目名，右栏组头写的就是它。
  final String name;

  /// 按 `index` 升序的步骤。
  final List<Step> steps;

  /// 当前推进到第几步，0 基；-1 表示一步都还没走。
  final int currentStep;

  /// stepId → 这一步还没做完的件数。为 0 说明这一步当天收尾了。
  final Map<String, int> openCounts;

  /// 截止时间，毫秒时间戳；没设截止为 null。
  final int? dueAt;

  int get total => steps.length;

  /// 当前步的序号，1 基；还没开始时是 0。
  int get now => currentStep < 0 ? 0 : currentStep + 1;

  /// 这一步还有没有没做完的事。找不到记录时按「还有」处理，宁可不说已完成。
  bool isStepFinished(String stepId) => (openCounts[stepId] ?? 0) == 0;
}

/// 右栏的一组：独立事项一组，或一个项目一组。
class DayGroup {
  const DayGroup({
    required this.key,
    required this.kind,
    required this.name,
    required this.seconds,
    required this.items,
    this.stepNow = 0,
    this.stepTotal = 0,
    this.dueAt,
    this.stepNote,
  });

  /// 独立事项用 `soloKey`，项目用项目 id。展开态也按它记。
  final String key;
  final DayGroupKind kind;
  final String name;

  /// 组内当天投入合计，单位秒。
  final int seconds;

  /// 组内条目，已按当天时刻排好。
  final List<TaskDayEntry> items;

  /// 当前步序号，1 基；没有步骤或还没开始是 0。
  final int stepNow;

  /// 步骤总数。
  final int stepTotal;

  /// 截止时间，毫秒时间戳；没设截止为 null。
  final int? dueAt;

  /// 项目组那行推进说明，如「第 3 步 写结论 → 已完成，进入第 4 步 对图表」。
  /// 独立事项、没步骤、事项没归步骤时都是 null，那一行不出现。
  final String? stepNote;

  int get count => items.length;

  bool get isSolo => kind == DayGroupKind.solo;
}

/// 组内条目的先后：按当天时刻升序，同一刻按事名。
///
/// 记录页是回看一天怎么过的，先后顺序比时长有意义；没时刻的排最后。
List<TaskDayEntry> sortedDayEntries(List<TaskDayEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final atA = a.atMs;
      final atB = b.atMs;
      if (atA != null && atB != null) {
        final byAt = atA.compareTo(atB);
        if (byAt != 0) return byAt;
      } else if (atA != null) {
        return -1;
      } else if (atB != null) {
        return 1;
      }
      return a.task.name.compareTo(b.task.name);
    });
  return sorted;
}

int _sortAt(TaskDayEntry entry) => entry.atMs ?? 0;

/// 项目组那行推进说明。
///
/// 先说当天真正收尾的那一步（当天完成、且这一步没有剩活），编号最大的那个；
/// 当天没有收尾的步，就说最后动过的那一步在推进。
/// 收尾是这一天最该记下来的事，所以压在「推进中」前面。
String? advanceNoteOf(List<TaskDayEntry> items, ProjectSteps? steps) {
  if (steps == null || steps.steps.isEmpty) return null;
  final withStep = items.where((entry) => entry.task.stepId != null).toList();
  if (withStep.isEmpty) return null;

  final finished = <int>[];
  for (final item in withStep) {
    final stepId = item.task.stepId!;
    if (!item.task.done || !steps.isStepFinished(stepId)) continue;
    final index = steps.steps.indexWhere((step) => step.id == stepId);
    if (index >= 0) finished.add(index);
  }
  if (finished.isNotEmpty) {
    finished.sort();
    return _finishedNote(steps, finished.last);
  }

  withStep.sort((a, b) => _sortAt(b).compareTo(_sortAt(a)));
  final stepId = withStep.first.task.stepId!;
  final index = steps.steps.indexWhere((step) => step.id == stepId);
  if (index < 0) return null;
  if (steps.isStepFinished(stepId)) return _finishedNote(steps, index);
  return '第 ${index + 1} 步 ${steps.steps[index].name} 推进中';
}

/// 某一步收尾之后说什么：后面还有步就点名，没有就说流程走完。
String _finishedNote(ProjectSteps steps, int index) {
  final step = steps.steps[index];
  final next = index + 1 < steps.steps.length ? steps.steps[index + 1] : null;
  return next == null
      ? '第 ${index + 1} 步 ${step.name} → 已完成'
      : '第 ${index + 1} 步 ${step.name} → 已完成，进入第 ${index + 2} 步 ${next.name}';
}

/// 右栏分组：独立事项一组在前（有才出现），项目按当天投入从多到少排。
///
/// 只完成、没计时的项目按 0 秒参与排序，落在最后，但不会因为没投入就不出现。
List<DayGroup> buildDayGroups({
  required List<TaskDayEntry> entries,
  required Map<String, ProjectSteps> projectSteps,
  required DateTime selected,
}) {
  final byKey = <String, List<TaskDayEntry>>{};
  for (final entry in entries) {
    final key = entry.task.projectId ?? soloKey;
    byKey.putIfAbsent(key, () => <TaskDayEntry>[]).add(entry);
  }

  final solo = byKey.remove(soloKey);
  final groups = <DayGroup>[];
  if (solo != null && solo.isNotEmpty) {
    groups.add(
      DayGroup(
        key: soloKey,
        kind: DayGroupKind.solo,
        name: '独立事项',
        seconds: solo.fold<int>(0, (sum, entry) => sum + entry.seconds),
        items: sortedDayEntries(solo),
      ),
    );
  }

  final projects = <DayGroup>[];
  for (final entry in byKey.entries) {
    final steps = projectSteps[entry.key];
    final items = sortedDayEntries(entry.value);
    projects.add(
      DayGroup(
        key: entry.key,
        kind: DayGroupKind.project,
        name: steps?.name ?? '',
        seconds: entry.value.fold<int>(0, (sum, item) => sum + item.seconds),
        items: items,
        stepNow: steps?.now ?? 0,
        stepTotal: steps?.total ?? 0,
        dueAt: steps?.dueAt,
        stepNote: advanceNoteOf(items, steps),
      ),
    );
  }
  projects.sort((a, b) {
    final bySeconds = b.seconds.compareTo(a.seconds);
    if (bySeconds != 0) return bySeconds;
    final byName = a.name.compareTo(b.name);
    return byName != 0 ? byName : a.key.compareTo(b.key);
  });
  return <DayGroup>[...groups, ...projects];
}

/// 组头右侧那行：独立事项报件数，项目报推进了几项；后面都跟当天投入。
String groupSummaryLabel(DayGroup group) {
  final head = group.isSolo ? '${group.count} 件' : '推进 ${group.count} 项';
  return '$head · ${groupMinutesLabel(group.seconds)}';
}

/// 组头用的时长：没计时就写 0 分钟，不写「不到 1 分钟」。
String groupMinutesLabel(int seconds) {
  final minutes = (seconds / 60).round();
  return '${minutes < 0 ? 0 : minutes} 分钟';
}

/// 组头的小徽标：`3/7`。没有步骤时返回空串，界面据此不画。
String stepBadge(int now, int total) => total <= 0 ? '' : '$now/$total';

/// 距截止：按选中的那一天算，回看旧日子看到的是那天的处境。
String dueText(int? dueAt, DateTime from) {
  if (dueAt == null) return '';
  final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(due.year, due.month, due.day);
  final days = end.difference(start).inDays;
  return days >= 0 ? '距截止 $days 天' : '已过 ${-days} 天';
}

/// 条目右侧的时刻，`10:20`。
String clockLabel(int? atMs) {
  if (atMs == null) return '';
  final at = DateTime.fromMillisecondsSinceEpoch(atMs);
  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// 条目右侧那行元信息：`20 分钟 · 10:20`。
///
/// 没计过时就不提计时这件事，只留时刻；时刻也没有就返回空串，界面不画。
String entryMetaLabel(TaskDayEntry entry) {
  final clock = clockLabel(entry.atMs);
  if (!entry.timed) return clock;
  return clock.isEmpty
      ? minutesLabel(entry.seconds)
      : '${minutesLabel(entry.seconds)} · $clock';
}

/// 展开后那一行：这件当天投了多少、怎么收的。
///
/// 没计过时就没有可讲的事实，返回空串；界面据此不画箭头、也不响应点击。
/// AI 总结与感想由 B19 接在这行下面。
String dayEntryBody(TaskDayEntry entry) {
  if (!entry.timed) return '';
  final clock = clockLabel(entry.atMs);
  return clock.isEmpty
      ? '当天投入 ${minutesLabel(entry.seconds)}。'
      : '$clock 结束，当天投入 ${minutesLabel(entry.seconds)}。';
}
