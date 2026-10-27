import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'day_panel.dart';
import 'month_calendar.dart';
import 'records_notifier.dart';

/// 第 5 页 · 我的记录。左栏月历与右栏当天记录，宽度 4:6，间距 20。
///
/// B17 落地左栏月历与右栏头部；分组、感想与 AI 总结由 B18、B19 接着填。
class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  @override
  void initState() {
    super.initState();
    // 每次切回这一页都重读一遍：在别处记的表、勾掉的完成，回来要看得见。
    unawaited(ref.read(recordCalendarProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey<String>('page-records'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 月历高度是固定的，窗口压得很矮时让它自己滚，别硬挤出边界。
          Expanded(flex: 4, child: SingleChildScrollView(child: MonthCalendar())),
          SizedBox(width: 20),
          Expanded(flex: 6, child: DayPanel()),
        ],
      ),
    );
  }
}
