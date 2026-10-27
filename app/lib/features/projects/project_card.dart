import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'projects_notifier.dart';

/// 列表里的一行项目卡片。
///
/// 数字全部由 [ProjectRow] 带进来，这里只负责照原型画：名与百分比在首行、
/// 4 像素细进度条居中、下一步与最近推进在末行、右中一个箭头。
class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.row,
    required this.now,
    required this.onTap,
    required this.onMark,
  });

  final ProjectRow row;

  /// 算「最近推进」相对文案用的当前时间。
  final DateTime now;

  final VoidCallback onTap;

  /// 名称右侧那枚标记按钮：把该项目首个未完成事项摆进小任务窗口。
  final VoidCallback onMark;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

/// 项目卡上那枚标记键。样式与独立事项页的那枚一致，免得两页两种认法。
class _MarkButton extends StatefulWidget {
  const _MarkButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MarkButton> createState() => _MarkButtonState();
}

class _MarkButtonState extends State<_MarkButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '标记为当前事项，放进小任务窗口',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? AppTheme.primarySoft : Colors.white,
              border: Border.all(color: _hover ? AppTheme.primary : AppTheme.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.push_pin_outlined,
              size: 14,
              color: _hover ? AppTheme.primary : AppTheme.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final since = relativeSince(row.lastAdvancedAt ?? row.createdAt, widget.now);
    final pct = row.percent.clamp(0, 100);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          key: ValueKey('proj-card-${row.id}'),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? const Color(0xFFB9C8DD) : AppTheme.line),
            boxShadow: _hover
                ? const [BoxShadow(color: Color(0x12323C50), blurRadius: 16, offset: Offset(0, 6))]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 项目名右侧的标记按钮。《页面操作流程》第 6 节：点它把该项目首个
                      // 未完成步骤的首个未完成事项摆进小任务窗口，不开始计时。
                      _MarkButton(
                        key: ValueKey<String>('proj-mark-${row.id}'),
                        onTap: widget.onMark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _Bar(id: row.id, percent: pct),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (row.nextStep.isEmpty)
                                const TextSpan(text: ' ')
                              else ...[
                                const TextSpan(text: '下一步：'),
                                TextSpan(
                                  text: row.nextStep,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.ink,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.ink2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '最近推进：$since',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppTheme.ink3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 原型里箭头是绝对定位，压在右侧内边距上，内容不额外让位。
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      color: Color(0xFFC3CCDA),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4 像素细进度条：底 `#eef1f6`，填充主色，宽度按百分比。
class _Bar extends StatelessWidget {
  const _Bar({required this.id, required this.percent});

  final String id;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F6),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percent / 100,
        child: Container(
          key: ValueKey('proj-bar-$id'),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
