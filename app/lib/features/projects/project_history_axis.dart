part of 'project_history.dart';

/// 进度史的时间轴排法：按本地日历日分组，左边一条竖线串起所有节点。
///
/// 与列表读同一份数据、同一组动作，只是换了个排法；切视图不清编辑态。
class _HistoryAxis extends StatelessWidget {
  const _HistoryAxis({required this.entries, required this.args});

  final List<ProgressEntry> entries;
  final _HistoryBodyArgs args;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(entries, args.nowMs);
    return Container(
      key: const ValueKey<String>('hist-axis-list'),
      margin: const EdgeInsets.only(left: 22, top: 6, bottom: 6),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.histLine, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            Padding(
              padding: EdgeInsets.only(left: 14, top: i == 0 ? 0 : 16, bottom: 6),
              child: Text(
                groups[i].label,
                key: ValueKey<String>('hist-day-${groups[i].label}'),
                style: const TextStyle(fontSize: 12, color: AppTheme.ink3),
              ),
            ),
            for (final entry in groups[i].entries) _AxisNode(entry: entry, args: args),
          ],
        ],
      ),
    );
  }

  /// 按日历日分组，顺序沿用传进来的流程顺序。
  static List<_AxisGroup> _groupByDay(List<ProgressEntry> entries, int nowMs) {
    final out = <_AxisGroup>[];
    final index = <String, _AxisGroup>{};
    for (final entry in entries) {
      final key = _dayKey(entry.at);
      final group = index.putIfAbsent(key, () {
        final created = _AxisGroup(label: historyDay(entry.at, nowMs), entries: []);
        out.add(created);
        return created;
      });
      group.entries.add(entry);
    }
    return out;
  }

  static String _dayKey(int atMs) {
    final at = DateTime.fromMillisecondsSinceEpoch(atMs);
    return '${at.year}-${at.month}-${at.day}';
  }
}

class _AxisGroup {
  _AxisGroup({required this.label, required this.entries});

  final String label;
  final List<ProgressEntry> entries;
}

/// 一个节点：白底主色边的圆点压在竖线上，右边是正文与 meta。
class _AxisNode extends StatelessWidget {
  const _AxisNode({required this.entry, required this.args});

  final ProgressEntry entry;
  final _HistoryBodyArgs args;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          key: ValueKey<String>('hist-tl-${entry.id}'),
          padding: const EdgeInsets.fromLTRB(14, 8, 0, 8),
          child: _HistoryBody(entry: entry, args: args, textSize: 13),
        ),
        const Positioned(left: -6, top: 14, child: _AxisDot()),
      ],
    );
  }
}

/// 10×10 的圆点：白底、2 像素主色边。
class _AxisDot extends StatelessWidget {
  const _AxisDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
    );
  }
}
