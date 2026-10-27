import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pet_bubble_metrics.dart';
import 'pet_message.dart';
import 'pet_notifier.dart';

/// 截止强提醒，三行：
///
/// 行 1 事项名称、行 2 红色「将于 2026年10月31日 截止」、行 3 底部只右侧两个按钮。
/// 按《页面操作流程》第 3 节，这一档不自动消失，也不摆任何时间说明文字。
class DeadlineBubbleView extends StatelessWidget {
  const DeadlineBubbleView({
    super.key,
    required this.bubble,
    required this.onView,
    required this.onDismiss,
  });

  final DeadlineBubble bubble;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      deadline: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 行 1：事项名称。
          Text(
            bubble.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 21 / 14,
              color: AppTheme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // 行 2：红色那句截止时间，独占剩下的一整块。
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bubble.headline,
                key: const ValueKey<String>('bubble-deadline-when'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTheme.fontMeta,
                  height: 1.5,
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // 行 3：底部，只有右侧两个按钮。
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _BubbleButton(label: '查看', primary: true, onTap: onView),
              const SizedBox(width: 8),
              _BubbleButton(label: '知道了', onTap: onDismiss),
            ],
          ),
        ],
      ),
    );
  }
}

/// 开机播报：项目列表从页面顶部开始往下排，底部只右侧两个按钮。
///
/// 《页面操作流程》第 2 节：不写「开机播报」「15 秒后自动收起」这类说明文字，
/// 剩余位置全部留给列表。
class ReportBubbleView extends StatelessWidget {
  const ReportBubbleView({
    super.key,
    required this.bubble,
    required this.onView,
    required this.onDismiss,
  });

  final ReportBubble bubble;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                key: const ValueKey<String>('bubble-report-rows'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < bubble.rows.length; i++)
                    _ReportRowView(row: bubble.rows[i], first: i == 0),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _BubbleButton(label: '查看', primary: true, onTap: onView),
              const SizedBox(width: 8),
              _BubbleButton(label: '知道了', onTap: onDismiss),
            ],
          ),
        ],
      ),
    );
  }
}

/// 播报的一行：项目名加粗、说明浅色，行与行之间一道虚线（原型 `.brow`）。
class _ReportRowView extends StatelessWidget {
  const _ReportRowView({required this.row, required this.first});

  final ReportRow row;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!first) const _DashedDivider(),
        Padding(
          padding: EdgeInsets.only(top: first ? 2 : 7, bottom: 7),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTheme.fontBody,
                    height: 1.6,
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  row.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTheme.fontBody,
                    height: 1.6,
                    color: AppTheme.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 行间虚线。原型是 `border-top:1px dashed`，Flutter 没有现成的虚线边框。
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dash = 4.0;
          const gap = 4.0;
          final count = (constraints.maxWidth / (dash + gap)).floor();
          return Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                Container(width: dash, height: 1, color: AppTheme.line),
                const SizedBox(width: gap),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 气泡外壳：白底、12 圆角、13×15 内边距，截止那一档左边压一道 4px 红条。
class _BubbleCard extends StatelessWidget {
  const _BubbleCard({required this.child, this.deadline = false});

  final Widget child;
  final bool deadline;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(BubbleMetrics.radius));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      // 圆角边框只允许四边同色，截止那道红条不能画在边框上，单放一层。
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line),
            borderRadius: radius,
          ),
          child: Stack(
            children: [
              if (deadline)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(color: AppTheme.danger),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BubbleMetrics.paddingH,
                  vertical: BubbleMetrics.paddingV,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 气泡里的动作按钮。原型 `.bx button{min-height:30px;padding:0 10px;border-radius:6px}`。
class _BubbleButton extends StatelessWidget {
  const _BubbleButton({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? AppTheme.primary : AppTheme.ink2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: BubbleMetrics.footerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: primary ? AppTheme.primary : AppTheme.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontMeta,
            color: color,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
