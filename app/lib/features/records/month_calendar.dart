import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'records_notifier.dart';

/// 日历格子的浅色，取原型 `.cal-day` 一族：
/// 普通格白底细边、补白格更浅、悬停再浅一档、今天浅蓝底淡蓝边。
const Color _cellLine = Color(0xFFEEF1F7);
const Color _cellOut = Color(0xFFFAFBFD);
const Color _cellHover = Color(0xFFF8FAFD);
const Color _cellOutInk = Color(0xFFB6BFCD);
const Color _todayFill = Color(0xFFF5F9FF);
const Color _todayLine = Color(0xFF93C5FD);

/// 第 5 页左栏：月份条、周标题、六行七列的格子与图例。
class MonthCalendar extends ConsumerWidget {
  const MonthCalendar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordCalendarProvider);
    final notifier = ref.read(recordCalendarProvider.notifier);
    // 数据还没回来时格子先占位，免得首帧闪一下高度。
    CalendarCell? cellAt(int index) =>
        index < state.cells.length ? state.cells[index] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ArrowButton(
              icon: Icons.chevron_left,
              buttonKey: const ValueKey<String>('records-prev'),
              tooltip: '上个月',
              onTap: () => unawaited(notifier.previousMonth()),
            ),
            const SizedBox(width: 4),
            Text(
              monthLabel(state.year, state.month),
              key: const ValueKey<String>('records-month'),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(width: 4),
            _ArrowButton(
              icon: Icons.chevron_right,
              buttonKey: const ValueKey<String>('records-next'),
              tooltip: '下个月',
              onTap: () => unawaited(notifier.nextMonth()),
            ),
            const Spacer(),
            _TodayButton(onTap: () => unawaited(notifier.goToday())),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < weekdayLabels.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdayLabels[i],
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      color: AppTheme.ink3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < calendarRows; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == calendarRows - 1 ? 0 : 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++) ...[
                  if (col > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _DayCell(
                      cell: cellAt(row * 7 + col),
                      stat: state.statOf(cellAt(row * 7 + col)?.key ?? ''),
                      selected: cellAt(row * 7 + col)?.key == state.selected,
                      today: notifier.today,
                      highlight: state.highlight,
                      onTap: notifier.select,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        _Legend(
          items: state.legend,
          highlight: state.highlight,
          onTap: notifier.toggleHighlight,
        ),
      ],
    );
  }
}

/// 月份条两端的小箭头：透明底，悬停铺一层浅灰。
class _ArrowButton extends StatefulWidget {
  const _ArrowButton({
    required this.icon,
    required this.buttonKey,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Key buttonKey;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            key: widget.buttonKey,
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? _cellHover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: AppTheme.ink2),
          ),
        ),
      ),
    );
  }
}

/// 月份条右端的「今天」。
class _TodayButton extends StatefulWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          key: const ValueKey<String>('records-today'),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? AppTheme.primary : _cellLine),
          ),
          child: Text(
            '今天',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _hover ? AppTheme.primary : AppTheme.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 一格：左上日期、右下件数、底部色带。
class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.cell,
    required this.stat,
    required this.selected,
    required this.today,
    required this.highlight,
    required this.onTap,
  });

  /// 数据还没回来时是 null，格子照样占位。
  final CalendarCell? cell;
  final DayStat? stat;
  final bool selected;

  /// 今天，`yyyy-MM-dd`。走 Notifier 的时钟，测试里固定得住。
  final String today;

  /// 图例高亮的那一项，其余色段压到 25% 透明。
  final String? highlight;

  final Future<void> Function(String date) onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cell = widget.cell;
    if (cell == null) {
      return const SizedBox(height: 40);
    }

    final isToday = cell.key == widget.today;
    final segments = widget.stat?.segments ?? const <DaySegment>[];
    final doneCount = widget.stat?.doneCount ?? 0;

    late final Color fill;
    late final Color border;
    late final Color ink;
    if (widget.selected) {
      fill = AppTheme.primary;
      border = AppTheme.primary;
      ink = Colors.white;
    } else if (isToday) {
      fill = _todayFill;
      border = _todayLine;
      ink = AppTheme.ink;
    } else if (!cell.inMonth) {
      fill = _cellOut;
      border = _cellLine;
      ink = _cellOutInk;
    } else {
      fill = _hover ? _cellHover : Colors.white;
      border = _hover ? AppTheme.line2 : _cellLine;
      ink = AppTheme.ink;
    }

    final body = Container(
      key: ValueKey<String>('records-cell-${cell.key}'),
      height: 40,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 2,
            child: Text(
              '${cell.date.day}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: ink,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (doneCount > 0 && cell.inMonth)
            Positioned(
              right: 4,
              bottom: 8,
              child: Text(
                '$doneCount',
                key: ValueKey<String>('records-count-${cell.key}'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: widget.selected ? Colors.white70 : AppTheme.ink3,
                ),
              ),
            ),
          if (segments.isNotEmpty)
            Positioned(
              left: 4,
              right: 4,
              bottom: 3,
              child: Row(
                key: ValueKey<String>('records-bar-${cell.key}'),
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: segments[i].seconds < 1 ? 1 : segments[i].seconds,
                      child: Opacity(
                        key: ValueKey<String>('records-seg-${cell.key}-$i'),
                        opacity: _opacityOf(segments[i].key),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: segments[i].color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    return MouseRegion(
      cursor: cell.inMonth ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: cell.inMonth ? () => unawaited(widget.onTap(cell.key)) : null,
        child: body,
      ),
    );
  }

  double _opacityOf(String key) {
    final highlight = widget.highlight;
    if (highlight == null || highlight == key) return 1;
    return 0.25;
  }
}

/// 图例：项目色点加名字，点了只高亮那一项，再点取消。
class _Legend extends StatelessWidget {
  const _Legend({required this.items, required this.highlight, required this.onTap});

  final List<LegendItem> items;
  final String? highlight;
  final void Function(String key) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        key: ValueKey<String>('records-legend'),
        height: 12,
      );
    }
    return Wrap(
      key: const ValueKey<String>('records-legend'),
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final item in items)
          _LegendItem(
            item: item,
            dimmed: highlight != null && highlight != item.key,
            onTap: () => onTap(item.key),
          ),
      ],
    );
  }
}

class _LegendItem extends StatefulWidget {
  const _LegendItem({required this.item, required this.dimmed, required this.onTap});

  final LegendItem item;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  State<_LegendItem> createState() => _LegendItemState();
}

class _LegendItemState extends State<_LegendItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.dimmed ? 0.4 : 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Row(
            key: ValueKey<String>('records-legend-${widget.item.key}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  color: _hover ? AppTheme.ink : AppTheme.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
