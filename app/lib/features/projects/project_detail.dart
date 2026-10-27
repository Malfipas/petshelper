import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/model/project.dart';
import 'projects_notifier.dart';

/// 项目详情的头部：返回键、标题与说明截止、进度行、删除键。
///
/// B13 只到这一排；流程条、待办卡片、进度史由 B14–B16 往下接，
/// 所以这里只画头部，不占下半屏。
class ProjectDetailHeader extends StatelessWidget {
  const ProjectDetailHeader({
    super.key,
    required this.project,
    required this.percent,
    required this.doneSteps,
    required this.totalSteps,
    required this.lastAdvancedAt,
    required this.now,
    required this.onBack,
    required this.onDelete,
    required this.onPickDue,
  });

  final Project project;
  final int percent;
  final int doneSteps;
  final int totalSteps;

  /// 最近一次推进；null 按创建时间算，跟列表口径一致。
  final int? lastAdvancedAt;
  final DateTime now;
  final VoidCallback onBack;
  final VoidCallback onDelete;

  /// 点截止日期那一格：任何时候都能改。
  final VoidCallback onPickDue;

  @override
  Widget build(BuildContext context) {
    final since = relativeSince(lastAdvancedAt ?? project.createdAt, now);
    final desc = project.description.trim();
    final due = dueLabel(project.dueAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Row(
        children: [
          _MiniButton(key: const ValueKey('proj-back'), label: '← 全部项目', onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // 原型是 max-width:46%，这里按可用宽算，超了截断不换行。
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.46),
                          child: Text(
                            project.name,
                            key: const ValueKey('proj-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _Meta(key: const ValueKey('proj-desc'), text: desc),
                        ],
                        // 截止日期随时可改：没填时也给一格「设置截止日期」。
                        ...[
                          const SizedBox(width: 10),
                          Tooltip(
                            message: '点击修改截止日期',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onPickDue,
                                child: due.isEmpty
                                    ? const _Meta(
                                        key: ValueKey('proj-due-empty'),
                                        text: '设置截止日期',
                                      )
                                    : _Meta(key: const ValueKey('proj-due'), text: due),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  '$percent% · 已完成 $doneSteps/$totalSteps 步 · 最近推进 $since',
                  key: const ValueKey('proj-sub'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.ink3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _MiniButton(
            key: const ValueKey('proj-del'),
            label: '删除项目',
            danger: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 标题右侧那一小段灰字：说明与截止各一枚，超过 210 宽截断。
class _Meta extends StatelessWidget {
  const _Meta({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.ink3),
      ),
    );
  }
}

/// 头部那两枚小按钮：返回是中性，删除是危险色。
class _MiniButton extends StatefulWidget {
  const _MiniButton({super.key, required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.danger;
    final color = danger ? AppTheme.danger : (_hover ? AppTheme.primary : AppTheme.ink2);
    final border = danger
        ? (_hover ? const Color(0xFFE3A49C) : const Color(0xFFF0C9C4))
        : (_hover ? AppTheme.primary : AppTheme.line2);
    final fill = danger ? (_hover ? const Color(0xFFFDF3F2) : Colors.white) : Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: EdgeInsets.symmetric(horizontal: danger ? 12 : 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, color: color),
          ),
        ),
      ),
    );
  }
}
