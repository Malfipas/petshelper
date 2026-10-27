import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 项目页的页头：标题、件数、一行提示与「新建项目」。
///
/// 标题 16 号 / 600、件数 12 号冷灰、提示与部件同一行右对齐，尺寸照整体原型第 6 页。
class ProjectHeader extends StatelessWidget {
  const ProjectHeader({
    super.key,
    required this.count,
    required this.flash,
    required this.formOpen,
    required this.onNew,
  });

  /// 列表里的项目数，直接写进「N 个项目」。
  final int count;

  /// 页头右侧的一行灰红提示，空串表示不显示。
  final String flash;

  /// 新建表单是否开着，决定右侧那颗键写「新建项目」还是「收起」。
  final bool formOpen;

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '我的项目',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count 个项目',
                key: const ValueKey<String>('proj-count'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.ink3,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (flash.isNotEmpty) ...[
            Text(
              flash,
              key: const ValueKey<String>('proj-flash'),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(width: 12),
          ],
          ProjectButton(
            key: const ValueKey<String>('proj-new'),
            label: formOpen ? '收起' : '新建项目',
            onTap: onNew,
          ),
        ],
      ),
    );
  }
}

/// 项目页里的小按钮。普通态白底细边、主态主色实底、危险态红底；
/// 禁用时整体压到 45% 透明（原型 `button[disabled]{opacity:.45}`）。
class ProjectButton extends StatefulWidget {
  const ProjectButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.enabled = true,
    this.minHeight = 34,
    this.horizontal = 14,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final bool enabled;

  /// 最小高，原型上新建键与弹窗按钮是 34，详情与表单里的小键是 32。
  final double minHeight;

  /// 左右内边距，原型 14，详情返回键 10。
  final double horizontal;

  final double fontSize;

  @override
  State<ProjectButton> createState() => _ProjectButtonState();
}

class _ProjectButtonState extends State<ProjectButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final hover = _hover && enabled;

    late final Color fill;
    late final Color textColor;
    late final Color borderColor;
    if (widget.primary) {
      fill = hover ? const Color(0xFF1D4ED8) : AppTheme.primary;
      textColor = Colors.white;
      borderColor = fill;
    } else if (widget.danger) {
      fill = hover ? const Color(0xFFC8402F) : AppTheme.danger;
      textColor = Colors.white;
      borderColor = fill;
    } else {
      fill = Colors.white;
      textColor = hover ? AppTheme.primary : AppTheme.ink2;
      borderColor = hover ? AppTheme.primary : AppTheme.line2;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: Container(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            padding: EdgeInsets.symmetric(horizontal: widget.horizontal),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: widget.fontSize,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
