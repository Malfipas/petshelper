import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/model/chat_message.dart';
import '../../domain/model/note.dart';
import '../../domain/model/task_day_entry.dart';
import '../../domain/usecase/summarize_day.dart';
import 'day_record.dart';
import 'day_texts.dart';
import 'records_calendar.dart';
import 'records_state.dart';

export 'day_record.dart';
export 'day_texts.dart';
export 'records_calendar.dart';
export 'records_state.dart';

/// 第 5 页左栏的状态：看哪个月、选中哪天、每格件数与色带、图例高亮谁。
///
/// 这一页只读不写：不改事项状态、不碰计时，也不写日总结（那是 B18、B19 的事）。
class RecordCalendarNotifier extends Notifier<RecordsState> {
  RecordCalendarNotifier({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// 页面算「今天」「当月」用的时钟，测试里能固定住。
  final DateTime Function() _now;

  @override
  RecordsState build() {
    final today = _today();
    unawaited(_load(year: today.year, month: today.month, selected: dateKey(today)));
    return RecordsState(year: today.year, month: today.month, selected: dateKey(today));
  }

  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 今天，`yyyy-MM-dd`。格子的「今天」样式与「今天」键共用它。
  String get today => dateKey(_today());

  /// 读一个月的数：每格完成件数、每段投入，以及右栏选中那天的明细。
  Future<void> _load({
    required int year,
    required int month,
    required String selected,
    bool clearHighlight = false,
  }) async {
    final records = ref.read(recordRepositoryProvider);
    final tasks = ref.read(taskRepositoryProvider);
    final projects = await ref.read(projectRepositoryProvider).all();

    // 项目色按新建先后排定：同一个项目在哪个月、哪一天都是同一色。
    final ordered = projects.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final colorOf = <String, Color>{
      for (var i = 0; i < ordered.length; i++) ordered[i].id: projectColorAt(i),
    };
    final nameOf = <String, String>{for (final project in ordered) project.id: project.name};

    final monthStart = DateTime(year, month);
    final monthEnd = DateTime(year, month + 1);
    final secondsByDay = await records.daySecondsByProject(monthKey(year, month));
    final done = await tasks.doneBetween(
      monthStart.millisecondsSinceEpoch,
      monthEnd.millisecondsSinceEpoch,
    );

    final doneByDay = <String, int>{};
    // 完成事项所属的项目也要算进「推进」：点「标记完成」不跑秒，没有流水。
    final doneProjectsByDay = <String, Set<String>>{};
    for (final task in done) {
      final at = task.doneAt;
      if (at == null) continue;
      final key = dateKey(DateTime.fromMillisecondsSinceEpoch(at));
      doneByDay[key] = (doneByDay[key] ?? 0) + 1;
      final projectId = task.projectId;
      if (projectId != null) {
        doneProjectsByDay.putIfAbsent(key, () => <String>{}).add(projectId);
      }
    }

    // 每天推进过的项目 = 当天有投入的项目 ∪ 当天被完成的事项所属项目。
    final projectsByDay = <String, Set<String>>{
      for (final entry in doneProjectsByDay.entries) entry.key: <String>{...entry.value},
    };
    for (final entry in secondsByDay.entries) {
      final set = projectsByDay.putIfAbsent(entry.key, () => <String>{});
      for (final key in entry.value.keys) {
        if (key != soloKey) set.add(key);
      }
    }

    final stats = <String, DayStat>{};
    final monthSeconds = <String, int>{};
    for (final entry in secondsByDay.entries) {
      final perKey = entry.value;
      final soloSeconds = perKey[soloKey] ?? 0;
      if (soloSeconds > 0) {
        monthSeconds[soloKey] = (monthSeconds[soloKey] ?? 0) + soloSeconds;
      }
      final spends = <ProjectSpend>[];
      for (final spend in perKey.entries) {
        if (spend.key == soloKey || spend.value <= 0) continue;
        monthSeconds[spend.key] = (monthSeconds[spend.key] ?? 0) + spend.value;
        spends.add(
          ProjectSpend(
            id: spend.key,
            name: nameOf[spend.key] ?? '',
            color: colorOf[spend.key] ?? restColor,
            seconds: spend.value,
          ),
        );
      }
      stats[entry.key] = DayStat(
        doneCount: doneByDay[entry.key] ?? 0,
        segments: daySegments(soloSeconds: soloSeconds, projects: spends),
      );
    }
    // 只有完成、没开过表的日子也得让件数露出来。
    for (final entry in doneByDay.entries) {
      final old = stats[entry.key];
      stats[entry.key] = old == null
          ? DayStat(doneCount: entry.value)
          : old.copyWith(doneCount: entry.value);
    }

    final legend = legendItems(
      soloSeconds: monthSeconds[soloKey] ?? 0,
      projects: <ProjectSpend>[
        for (final project in ordered)
          ProjectSpend(
            id: project.id,
            name: project.name,
            color: colorOf[project.id]!,
            seconds: monthSeconds[project.id] ?? 0,
          ),
      ],
    );

    final entries = await _entriesOf(selected);
    final groups = await _groupOf(entries, DateTime.parse(selected));
    final settings = await ref.read(settingsRepositoryProvider).current();
    final hasKey = settings.keyConfigured;
    final texts = await _textsOf(date: selected, entries: entries, hasKey: hasKey);
    final record = await records.byDate(selected);

    if (!ref.mounted) return;
    state = RecordsState(
      year: year,
      month: month,
      selected: selected,
      cells: monthCells(year, month),
      stats: stats,
      legend: legend,
      projectColors: colorOf,
      highlight: clearHighlight ? null : state.highlight,
      dayEntries: entries,
      dayGroups: groups,
      // 换月、回今天时展开态一起清，和点日期一致。
      openKeys: clearHighlight ? const <String>{} : state.openKeys,
      daySeconds: _totalSeconds(entries),
      dayProjects: projectsByDay,
      dayDoneCount: doneByDay[selected] ?? 0,
      dayProjectCount: projectsByDay[selected]?.length ?? 0,
      hasKey: hasKey,
      summaryText: record?.summaryText ?? '',
      entryTexts: texts,
      // 换月或回今天，同一天的那段文字可能是另一份库里的；降级标记不继承。
      loading: false,
    );
  }

  /// 某一天动过的事项：开过表的，加上只标记完成的。
  Future<List<TaskDayEntry>> _entriesOf(String date) async {
    final day = DateTime.parse(date);
    final from = DateTime(day.year, day.month, day.day);
    return ref
        .read(taskRepositoryProvider)
        .entriesForDay(
          from.millisecondsSinceEpoch,
          from.add(const Duration(days: 1)).millisecondsSinceEpoch,
        );
  }

  /// 把当天的条目分好组：组头要的步骤数、当前步与推进说明都在这里补齐。
  ///
  /// 只有当天动过的项目才读步骤，一天通常一两个，不会把整页拖慢。
  Future<List<DayGroup>> _groupOf(List<TaskDayEntry> entries, DateTime day) async {
    final stepsOf = <String, ProjectSteps>{};
    final projectIds = <String>{
      for (final entry in entries)
        if (entry.task.projectId != null) entry.task.projectId!,
    };

    if (projectIds.isNotEmpty) {
      final projects = ref.read(projectRepositoryProvider);
      final tasks = ref.read(taskRepositoryProvider);
      for (final projectId in projectIds) {
        final bundle = await projects.load(projectId);
        final project = bundle.project;
        if (project == null) continue;
        // 这一步还剩几件没做完，决定推进说明写「推进中」还是「已完成」。
        final openCounts = <String, int>{};
        for (final task in await tasks.byProject(projectId)) {
          final stepId = task.stepId;
          if (stepId == null || task.done) continue;
          openCounts[stepId] = (openCounts[stepId] ?? 0) + 1;
        }
        stepsOf[projectId] = ProjectSteps(
          name: project.name,
          steps: bundle.steps,
          currentStep: project.currentStep,
          dueAt: project.dueAt,
          openCounts: openCounts,
        );
      }
    }

    return buildDayGroups(entries: entries, projectSteps: stepsOf, selected: day);
  }

  /// 展开区要用的文字：我改过的总结、感想、随手记，配了 key 时还有整理结果。
  ///
  /// 一天的感想与总结各查一次（按日期前缀），随手记按事项查。只有配了 key
  /// 才去翻对话：没 key 时走降级那一态，用不到这一项，省掉每条一次查询。
  Future<Map<String, EntryTexts>> _textsOf({
    required String date,
    required List<TaskDayEntry> entries,
    required bool hasKey,
  }) async {
    final notes = ref.read(noteRepositoryProvider);
    final prefix = dayTextPrefix(date);
    final thoughts = await notes.textsOfPrefix(NoteOwner.dayThought, prefix);
    final mine = await notes.textsOfPrefix(NoteOwner.daySummary, prefix);
    final chats = ref.read(chatRepositoryProvider);
    final dayKey = dayTextKey(date);

    final texts = <String, EntryTexts>{
      // 今日小结自己那条：只有感想，没有总结。
      dayKey: EntryTexts(thought: thoughts[dayKey] ?? ''),
    };

    for (final entry in entries) {
      final task = entry.task;
      final key = entryTextKey(date, task.projectId ?? soloKey, task.id);
      final scratch = await notes.textOf(NoteOwner.task, task.id);
      var usedAi = false;
      var lastAnswer = '';
      if (hasKey) {
        for (final message in await chats.thread(ChatOwner.panel, task.id)) {
          if (message.isFromUser) {
            usedAi = true;
          } else {
            lastAnswer = message.content;
          }
        }
      }
      texts[key] = EntryTexts(
        userSummary: mine[key] ?? '',
        thought: thoughts[key] ?? '',
        scratch: scratch,
        usedAi: usedAi,
        generated: entryGeneratedText(scratch: scratch, lastAnswer: lastAnswer),
      );
    }
    return texts;
  }

  int _totalSeconds(List<TaskDayEntry> entries) =>
      entries.fold<int>(0, (sum, entry) => sum + entry.seconds);

  /// 往前翻一个月，选中落到那个月 1 号。
  Future<void> previousMonth() {
    final first = DateTime(state.year, state.month - 1);
    return _load(
      year: first.year,
      month: first.month,
      selected: dateKey(first),
      clearHighlight: true,
    );
  }

  /// 往后翻一个月，选中落到那个月 1 号。
  Future<void> nextMonth() {
    final first = DateTime(state.year, state.month + 1);
    return _load(
      year: first.year,
      month: first.month,
      selected: dateKey(first),
      clearHighlight: true,
    );
  }

  /// 回到今天：月份与选中一起回来。
  Future<void> goToday() {
    final today = _today();
    return _load(
      year: today.year,
      month: today.month,
      selected: dateKey(today),
      clearHighlight: true,
    );
  }

  /// 点一格：只换右栏，不重读整月。
  Future<void> select(String date) async {
    if (date == state.selected) return;
    final entries = await _entriesOf(date);
    final groups = await _groupOf(entries, DateTime.parse(date));
    final texts = await _textsOf(date: date, entries: entries, hasKey: state.hasKey);
    final record = await ref.read(recordRepositoryProvider).byDate(date);
    if (!ref.mounted) return;
    state = state.copyWith(
      selected: date,
      dayEntries: entries,
      dayGroups: groups,
      // 切到别的日期再回来，事项仍是收起（原型第五页）。
      openKeys: const <String>{},
      daySeconds: _totalSeconds(entries),
      dayDoneCount: state.stats[date]?.doneCount ?? 0,
      dayProjectCount: state.dayProjects[date]?.length ?? 0,
      summaryText: record?.summaryText ?? '',
      entryTexts: texts,
      // 换了一天，上一段是降级来的这件事就不作数了。
      clearSummaryDegraded: true,
    );
  }

  /// 生成（或重新生成）选中那天的日总结。
  ///
  /// 没配 key 也能点：`SummarizeDay` 会降级成随手记的机械整合，这正是 PRD
  /// 里「未配置 key 时先按随手记整合」那一格。我自己改过的总结不会被覆盖
  /// （用例返回 `SummarizeDaySkipEdited`），这里把库里那一版再摆回界面。
  Future<void> generateSummary() async {
    if (state.summaryBusy) return;
    final date = state.selected;
    state = state.copyWith(summaryBusy: true, clearSummaryDegraded: true);
    final outcome = await ref
        .read(summarizeDayProvider)(date: date, nowMs: _now().millisecondsSinceEpoch);
    if (!ref.mounted) return;
    // 等模型的这几秒里可能点了别的日子，回来只认当前这天。
    if (state.selected != date) {
      state = state.copyWith(summaryBusy: false);
      return;
    }
    switch (outcome) {
      case SummarizeDaySummarized(:final text):
        state = state.copyWith(
          summaryText: text,
          summaryBusy: false,
          clearSummaryDegraded: true,
        );
      case SummarizeDayDegraded(:final text):
        state = state.copyWith(summaryText: text, summaryBusy: false, summaryDegraded: true);
      case SummarizeDaySkipEdited(:final record):
        state = state.copyWith(
          summaryText: record.summaryText,
          summaryBusy: false,
          clearSummaryDegraded: true,
        );
      case SummarizeDayNothing():
        // 这天没什么可写的：不动已有文字，也不留一条空记录。
        state = state.copyWith(summaryBusy: false);
    }
  }

  /// 点某一条：展开或收起它的总结与感想。
  void toggleOpen(String taskId) {
    final open = <String>{...state.openKeys};
    if (!open.remove(taskId)) open.add(taskId);
    state = state.copyWith(openKeys: open);
  }

  /// 点图例：高亮这一项，再点一次取消。
  void toggleHighlight(String key) {
    final same = state.highlight == key;
    state = state.copyWith(highlight: same ? null : key, clearHighlight: same);
  }

  /// 写一条事项当天的感想。空白等于删掉。
  Future<void> saveThought({
    required String groupKey,
    required String itemId,
    required String text,
  }) => _saveText(NoteOwner.dayThought, entryTextKey(state.selected, groupKey, itemId), text);

  /// 写今日小结那块感想。
  Future<void> saveDayThought(String text) =>
      _saveText(NoteOwner.dayThought, dayTextKey(state.selected), text);

  /// 存我改过的这条总结。存过之后这一条就一直显示我写的，不再被生成值盖掉。
  Future<void> saveEntrySummary({
    required String groupKey,
    required String taskId,
    required String text,
  }) => _saveText(NoteOwner.daySummary, entryTextKey(state.selected, groupKey, taskId), text);

  Future<void> _saveText(NoteOwner owner, String key, String text) async {
    await ref.read(noteRepositoryProvider).save(owner, key, text, _now().millisecondsSinceEpoch);
    await _reloadTexts();
  }

  /// 只重算文字，不动日历与分组：刚写完感想不该让整页跳一下。
  Future<void> _reloadTexts() async {
    final texts = await _textsOf(
      date: state.selected,
      entries: state.dayEntries,
      hasKey: state.hasKey,
    );
    if (!ref.mounted) return;
    state = state.copyWith(entryTexts: texts);
  }

  /// 重新读一遍当前这个月，选中不动。
  Future<void> refresh() => _load(
    year: state.year,
    month: state.month,
    selected: state.selected,
  );
}

/// 第 5 页左栏的 Notifier。
final recordCalendarProvider = NotifierProvider<RecordCalendarNotifier, RecordsState>(
  RecordCalendarNotifier.new,
);
