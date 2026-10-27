import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/model/task_day_entry.dart';
import 'records_notifier.dart';
import 'text_blocks.dart';

/// 第 5 页右栏：今日小结，加上按独立事项与项目分组的一天。
///
/// 条目默认收起，只露事名、时刻与（有计时的）时长；点整行展开这一件的
/// AI 总结与我的感想。
class DayPanel extends ConsumerWidget {
  const DayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordCalendarProvider);
    final notifier = ref.read(recordCalendarProvider.notifier);
    final date = DateTime.parse(state.selected);
    final summary = state.dayDoneCount == 0
        ? ''
        : '完成 ${state.dayDoneCount} 件 · 推进 ${state.dayProjectCount} 个项目';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              dayTitle(date),
              key: const ValueKey<String>('records-day-title'),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
            const Spacer(),
            Text(
              summary,
              key: const ValueKey<String>('records-day-summary'),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10.5,
                color: AppTheme.ink3,
              ),
            ),
          ],
        ),
        if (!state.hasKey) ...[
          const SizedBox(height: 8),
          const Text(
            '请前往设置页配置API key以启用AI总结功能',
            key: ValueKey<String>('records-ai-key-hint'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontMeta,
              color: AppTheme.ink3,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: state.dayGroups.isEmpty
              ? const Center(
                  child: Text(
                    '这天没有记录',
                    key: ValueKey<String>('records-day-empty'),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppTheme.ink3,
                    ),
                  ),
                )
              : ListView(
                  key: const ValueKey<String>('records-day-list'),
                  padding: EdgeInsets.zero,
                  children: [
                    _DaySummary(
                      doneCount: state.dayDoneCount,
                      projectCount: state.dayProjectCount,
                      seconds: state.daySeconds,
                      summaryText: state.summaryText,
                      summaryBusy: state.summaryBusy,
                      summaryDegraded: state.summaryDegraded,
                      thought: state.textsOf(dayTextKey(state.selected)).thought,
                      onGenerate: notifier.generateSummary,
                      onSaveThought: notifier.saveDayThought,
                    ),
                    for (final group in state.dayGroups)
                      _GroupBlock(
                        group: group,
                        date: state.selected,
                        selected: date,
                        color: group.isSolo
                            ? soloColor
                            : state.projectColors[group.key] ?? restColor,
                        openKeys: state.openKeys,
                        hasKey: state.hasKey,
                        textsOf: state.textsOf,
                        onToggle: notifier.toggleOpen,
                        onSaveThought: (taskId, text) => notifier.saveThought(
                          groupKey: group.key,
                          itemId: taskId,
                          text: text,
                        ),
                        onSaveSummary: (taskId, text) => notifier.saveEntrySummary(
                          groupKey: group.key,
                          taskId: taskId,
                          text: text,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 右栏最上面那块「今日小结」：事实行、AI 汇总一段、我的感想。
///
/// 日总结正文由 B23 生成：点标题右侧那个键才发请求，省得每次翻日历都烧一次
/// 额度；没配 key 也能点，生成的是随手记的机械整合，正文上方留一行说明。
class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.doneCount,
    required this.projectCount,
    required this.seconds,
    required this.summaryText,
    required this.summaryBusy,
    required this.summaryDegraded,
    required this.thought,
    required this.onGenerate,
    required this.onSaveThought,
  });

  final int doneCount;
  final int projectCount;
  final int seconds;
  final String summaryText;

  /// 正在等模型。
  final bool summaryBusy;

  /// 现有这段是降级来的。
  final bool summaryDegraded;
  final String thought;
  final VoidCallback onGenerate;
  final ValueChanged<String> onSaveThought;

  @override
  Widget build(BuildContext context) {
    final facts =
        '完成 $doneCount 件 · 推进 $projectCount 个项目 · 投入 ${groupMinutesLabel(seconds)}';
    final ai = summaryText.trim();
    final label = summaryBusy ? '生成中…' : (ai.isEmpty ? '生成小结' : '重新生成');
    return Container(
      key: const ValueKey<String>('records-day-summary-block'),
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '今日小结',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              const Spacer(),
              // 转圈的时候按钮还得在，只是点不动：位置一撤，下面的正文会跳。
              InkWell(
                key: const ValueKey<String>('records-day-summary-generate'),
                onTap: summaryBusy ? null : onGenerate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontMeta,
                      color: summaryBusy ? AppTheme.ink3 : AppTheme.ink2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            facts,
            key: const ValueKey<String>('records-day-summary-facts'),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              height: 1.6,
              color: AppTheme.ink2,
            ),
          ),
          // PRD 要求没 key 时也留一句「先按随手记整合」，别让人以为是模型写的。
          if (ai.isNotEmpty && summaryDegraded)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '未配置 API key，先按随手记整合',
                key: ValueKey<String>('records-day-summary-degraded'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontMeta,
                  color: AppTheme.ink3,
                ),
              ),
            ),
          if (ai.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ai,
                key: const ValueKey<String>('records-day-summary-ai'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontBody,
                  height: 1.7,
                  color: AppTheme.ink2,
                ),
              ),
            ),
          ThoughtBlock(
            key: const ValueKey<String>('records-day-thought'),
            text: thought,
            onSave: onSaveThought,
          ),
        ],
      ),
    );
  }
}

/// 一组：组头（名称、`3/7`、距截止、组内合计），项目再加一行推进说明。
class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.group,
    required this.date,
    required this.selected,
    required this.color,
    required this.openKeys,
    required this.hasKey,
    required this.textsOf,
    required this.onToggle,
    required this.onSaveThought,
    required this.onSaveSummary,
  });

  final DayGroup group;

  /// 选中那天的 `yyyy-MM-dd`，拼文字钥匙要用。
  final String date;
  final DateTime selected;

  /// 组名前的方点：独立事项固定灰，项目取日历同一色。
  final Color color;
  final Set<String> openKeys;
  final bool hasKey;
  final EntryTexts Function(String key) textsOf;
  final void Function(String taskId) onToggle;
  final void Function(String taskId, String text) onSaveThought;
  final void Function(String taskId, String text) onSaveSummary;

  @override
  Widget build(BuildContext context) {
    final badge = stepBadge(group.stepNow, group.stepTotal);
    final due = dueText(group.dueAt, selected);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.name,
                        key: ValueKey<String>('records-group-name-${group.key}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    if (badge.isNotEmpty) _Badge(label: badge),
                    if (due.isNotEmpty) _Badge(label: due, muted: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                groupSummaryLabel(group),
                key: ValueKey<String>('records-group-summary-${group.key}'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  color: AppTheme.ink3,
                ),
              ),
            ],
          ),
          if (group.stepNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    border: Border.all(color: const Color(0xFFCFDCFB)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    group.stepNote!,
                    key: ValueKey<String>('records-step-note-${group.key}'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final entry in group.items)
            _ItemCard(
              entry: entry,
              open: openKeys.contains(entry.task.id),
              texts: textsOf(entryTextKey(date, group.key, entry.task.id)),
              hasKey: hasKey,
              onToggle: onToggle,
              onSaveThought: (text) => onSaveThought(entry.task.id, text),
              onSaveSummary: (text) => onSaveSummary(entry.task.id, text),
            ),
        ],
      ),
    );
  }
}

/// 一枚小徽标：`3/7` 与「距截止 23 天」。
class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: muted ? AppTheme.histTag : AppTheme.accentSoft,
        border: Border.all(
          color: muted ? AppTheme.line2 : const Color(0xFFCFDCFB),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          color: muted ? AppTheme.ink2 : AppTheme.primary,
        ),
      ),
    );
  }
}

/// 一件的卡片：收起时一行，点开露出当天的明细、AI 总结与我的感想。
///
/// 只有标题行响应点击：展开区里有输入框，整卡可点会把「点输入框」也算成收起。
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.entry,
    required this.open,
    required this.texts,
    required this.hasKey,
    required this.onToggle,
    required this.onSaveThought,
    required this.onSaveSummary,
  });

  final TaskDayEntry entry;
  final bool open;
  final EntryTexts texts;
  final bool hasKey;
  final void Function(String taskId) onToggle;
  final ValueChanged<String> onSaveThought;
  final ValueChanged<String> onSaveSummary;

  @override
  Widget build(BuildContext context) {
    final id = entry.task.id;
    final meta = entryMetaLabel(entry);
    final body = dayEntryBody(entry);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey<String>('records-day-entry-$id'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onToggle(id),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 11, 14, open ? 6 : 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        meta,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          color: AppTheme.ink3,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: AppTheme.ink3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (body.isNotEmpty)
                    Text(
                      body,
                      key: ValueKey<String>('records-day-body-$id'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        height: 1.7,
                        color: AppTheme.ink2,
                      ),
                    ),
                  SummaryBlock(
                    key: ValueKey<String>('records-summary-$id'),
                    summary: texts.summaryOf(hasKey: hasKey),
                    onSave: onSaveSummary,
                  ),
                  ThoughtBlock(
                    key: ValueKey<String>('records-thought-$id'),
                    text: texts.thought,
                    onSave: onSaveThought,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
