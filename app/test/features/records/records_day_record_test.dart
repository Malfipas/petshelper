import 'package:ai_pet_assistant/domain/model/step.dart';
import 'package:ai_pet_assistant/domain/model/task_day_entry.dart';
import 'package:ai_pet_assistant/domain/model/task_item.dart';
import 'package:ai_pet_assistant/features/records/day_record.dart';
import 'package:ai_pet_assistant/features/records/records_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// 右栏分组的纯规则：组头、推进说明、时间文案、分组顺序。
void main() {
  /// 一次事项，默认独立、没计时。
  TaskItem task(
    String id, {
    String? projectId,
    String? stepId,
    String name = '写第三章',
    bool done = true,
    int? doneAt,
  }) => TaskItem(
    id: id,
    scope: projectId == null ? TaskScope.solo : TaskScope.project,
    projectId: projectId,
    stepId: stepId,
    name: name,
    done: done,
    doneAt: doneAt,
  );

  TaskDayEntry entry(
    String id, {
    int seconds = 0,
    int? atMs,
    String? projectId,
    String? stepId,
    String name = '写第三章',
    bool done = true,
  }) => TaskDayEntry(
    task: task(id, projectId: projectId, stepId: stepId, name: name, done: done),
    seconds: seconds,
    atMs: atMs,
  );

  Step step(String id, int index, String name) =>
      Step(id: id, projectId: 'p1', index: index, name: name);

  group('条目先后', () {
    test('按当天时刻升序', () {
      final sorted = sortedDayEntries([
        entry('t1', atMs: DateTime(2026, 10, 23, 20).millisecondsSinceEpoch),
        entry('t2', atMs: DateTime(2026, 10, 23, 10).millisecondsSinceEpoch),
      ]);
      expect(sorted.map((item) => item.task.id), ['t2', 't1']);
    });

    test('没有时刻的排最后，同一刻按事名', () {
      final sorted = sortedDayEntries([
        entry('t1', name: '写正文'),
        entry(
          't2',
          name: '整理图表',
          atMs: DateTime(2026, 10, 23, 10).millisecondsSinceEpoch,
        ),
        entry(
          't3',
          name: '查资料',
          atMs: DateTime(2026, 10, 23, 10).millisecondsSinceEpoch,
        ),
      ]);
      // 同一刻按事名排：「整理图表」在「查资料」前，没时刻的垫底。
      expect(sorted.map((item) => item.task.id), ['t2', 't3', 't1']);
    });
  });

  group('项目组头', () {
    ProjectSteps steps({
      required int currentStep,
      Map<String, int> openCounts = const <String, int>{},
      int? dueAt,
    }) => ProjectSteps(
      name: '毕业论文',
      steps: [step('s1', 0, '开题'), step('s2', 1, '写第三章'), step('s3', 2, '对图表')],
      currentStep: currentStep,
      dueAt: dueAt,
      openCounts: openCounts,
    );

    test('当前步从 0 基换成 1 基，步数给总数', () {
      final badge = stepBadge(steps(currentStep: 2).now, steps(currentStep: 2).total);
      expect(badge, '3/3');
    });

    test('还没开始的项目报 0/总步', () {
      final snapshot = steps(currentStep: -1);
      expect(stepBadge(snapshot.now, snapshot.total), '0/3');
    });

    test('没有步骤时不画徽标', () {
      expect(stepBadge(0, 0), '');
    });

    test('步骤乱序进来，按 index 摆好再写「第 N 步」', () {
      final snapshot = ProjectSteps(
        name: '毕业论文',
        steps: [step('s2', 1, '写第三章'), step('s1', 0, '开题')],
        currentStep: 0,
        openCounts: const <String, int>{},
      );
      expect(snapshot.steps.map((item) => item.id), ['s1', 's2']);
    });

    test('该步全做完：说已完成，并点出下一步', () {
      final note = advanceNoteOf(
        [entry('t1', projectId: 'p1', stepId: 's1')],
        steps(currentStep: 1, openCounts: const <String, int>{}),
      );
      expect(note, '第 1 步 开题 → 已完成，进入第 2 步 写第三章');
    });

    test('最后一步做完：只说已完成，不提下一步', () {
      final note = advanceNoteOf(
        [entry('t1', projectId: 'p1', stepId: 's3')],
        steps(currentStep: 2, openCounts: const <String, int>{}),
      );
      expect(note, '第 3 步 对图表 → 已完成');
    });

    test('该步还剩一件没做完：写推进中', () {
      final note = advanceNoteOf(
        [entry('t1', projectId: 'p1', stepId: 's2')],
        steps(currentStep: 1, openCounts: const <String, int>{'s2': 2}),
      );
      expect(note, '第 2 步 写第三章 推进中');
    });

    test('没有收尾的步：说最后动过的那一步在推进', () {
      final note = advanceNoteOf(
        [
          entry(
            't1',
            projectId: 'p1',
            stepId: 's1',
            atMs: DateTime(2026, 10, 23, 10).millisecondsSinceEpoch,
            done: false,
          ),
          entry(
            't2',
            projectId: 'p1',
            stepId: 's2',
            atMs: DateTime(2026, 10, 23, 16).millisecondsSinceEpoch,
            done: false,
          ),
        ],
        steps(currentStep: 1, openCounts: const <String, int>{'s1': 1, 's2': 1}),
      );
      expect(note, '第 2 步 写第三章 推进中');
    });

    test('当天既收尾了一步又往后推进了：先说收尾那一步', () {
      final note = advanceNoteOf(
        [
          entry(
            't1',
            projectId: 'p1',
            stepId: 's1',
            atMs: DateTime(2026, 10, 23, 10).millisecondsSinceEpoch,
          ),
          entry(
            't2',
            projectId: 'p1',
            stepId: 's2',
            atMs: DateTime(2026, 10, 23, 16).millisecondsSinceEpoch,
            done: false,
          ),
        ],
        steps(currentStep: 1, openCounts: const <String, int>{}),
      );
      expect(note, '第 1 步 开题 → 已完成，进入第 2 步 写第三章');
    });

    test('当天只开了表、那一步其实早做完了：仍写已完成', () {
      final note = advanceNoteOf(
        [
          entry('t1', projectId: 'p1', stepId: 's2', done: false),
        ],
        steps(currentStep: 1, openCounts: const <String, int>{}),
      );
      expect(note, '第 2 步 写第三章 → 已完成，进入第 3 步 对图表');
    });

    test('事项没归步骤、项目没步骤：都不出这行', () {
      expect(advanceNoteOf([entry('t1', projectId: 'p1')], steps(currentStep: 0)), isNull);
      expect(advanceNoteOf([entry('t1', projectId: 'p1', stepId: 's1')], null), isNull);
    });
  });

  group('文案', () {
    test('距截止按选中那天算', () {
      final due = DateTime(2026, 11, 15).millisecondsSinceEpoch;
      expect(dueText(due, DateTime(2026, 10, 23)), '距截止 23 天');
      expect(dueText(due, DateTime(2026, 11, 15)), '距截止 0 天');
      expect(dueText(DateTime(2026, 10, 20).millisecondsSinceEpoch, DateTime(2026, 10, 23)),
          '已过 3 天');
      expect(dueText(null, DateTime(2026, 10, 23)), '');
    });

    test('组头时长：没计时写 0 分钟，不写「不到 1 分钟」', () {
      expect(groupMinutesLabel(0), '0 分钟');
      expect(groupMinutesLabel(30), '1 分钟');
      expect(groupMinutesLabel(95 * 60), '95 分钟');
    });

    test('组头右侧：独立事项报件数，项目报推进项数', () {
      const solo = DayGroup(
        key: soloKey,
        kind: DayGroupKind.solo,
        name: '独立事项',
        seconds: 48 * 60,
        items: <TaskDayEntry>[],
      );
      const project = DayGroup(
        key: 'p1',
        kind: DayGroupKind.project,
        name: '毕业论文',
        seconds: 95 * 60,
        items: <TaskDayEntry>[],
      );
      expect(groupSummaryLabel(solo), '0 件 · 48 分钟');
      expect(groupSummaryLabel(project), '推进 0 项 · 95 分钟');
    });

    test('条目元信息与展开内容', () {
      final timed = entry('t1', seconds: 1200, atMs: DateTime(2026, 10, 23, 10, 20).millisecondsSinceEpoch);
      expect(entryMetaLabel(timed), '20 分钟 · 10:20');
      expect(dayEntryBody(timed), '10:20 结束，当天投入 20 分钟。');

      // 没计过时就不提计时，只留时刻；展开也没事实可讲。
      final untimed = entry('t2', atMs: DateTime(2026, 10, 23, 15).millisecondsSinceEpoch);
      expect(entryMetaLabel(untimed), '15:00');
      expect(dayEntryBody(untimed), '');

      // 连时刻都没有就什么都不写。
      expect(entryMetaLabel(entry('t3')), '');
    });

    test('没有时刻时只报时长', () {
      expect(clockLabel(null), '');
      expect(entryMetaLabel(entry('t1', seconds: 600)), '10 分钟');
    });
  });

  group('分组', () {
    test('独立事项在前，项目按投入从多到少，只完成的排后面', () {
      final groups = buildDayGroups(
        entries: [
          entry('t1', seconds: 300, projectId: 'p1', atMs: 1),
          entry('t2', seconds: 0, projectId: 'p2', atMs: 2),
          entry('t3', seconds: 3600, projectId: 'p3', atMs: 3),
          entry('t4', seconds: 600, atMs: 4),
        ],
        projectSteps: {
          'p1': ProjectSteps(
            name: '毕业论文',
            steps: [step('s1', 0, '开题')],
            currentStep: 0,
          ),
          'p2': ProjectSteps(name: '健身计划', steps: const <Step>[], currentStep: -1),
          'p3': ProjectSteps(name: '毕业设计', steps: const <Step>[], currentStep: -1),
        },
        selected: DateTime(2026, 10, 23),
      );

      expect(groups.map((group) => group.name), ['独立事项', '毕业设计', '毕业论文', '健身计划']);
    });

    test('没有独立的条目就不出独立那组', () {
      final groups = buildDayGroups(
        entries: [entry('t1', seconds: 600, projectId: 'p1', atMs: 1)],
        projectSteps: {
          'p1': ProjectSteps(name: '毕业论文', steps: const <Step>[], currentStep: -1),
        },
        selected: DateTime(2026, 10, 23),
      );
      expect(groups.single.kind, DayGroupKind.project);
    });

    test('项目被删了名字取不到，仍按 id 出一组，不把条目吞掉', () {
      final groups = buildDayGroups(
        entries: [entry('t1', seconds: 600, projectId: 'gone', atMs: 1)],
        projectSteps: const <String, ProjectSteps>{},
        selected: DateTime(2026, 10, 23),
      );
      expect(groups.single.key, 'gone');
      expect(groups.single.name, '');
      expect(groups.single.items, hasLength(1));
    });
  });
}
