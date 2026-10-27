import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/model/task_item.dart';
import 'solo_notifier.dart';

/// 独立事项的一行。
///
/// 三件事叠在一行里：多选框（做没做过）、名称与元信息（哪来的、做过多久）、
/// 右侧按钮（开始 / 走秒 / 已完成）。展开的详情由外面塞进 [detail]。
class SoloRow extends StatefulWidget {
  const SoloRow({
    super.key,
    required this.task,
    required this.now,
    required this.isCurrent,
    required this.isRunning,
    required this.isPaused,
    required this.clockLabel,
    required this.open,
    required this.onTapHead,
    required this.onToggleDone,
    required this.onStart,
    required this.onOpenPanel,
    required this.onMark,
    this.detail,
  });

  final TaskItem task;

  /// 算「今天建的」用的当下时间。
  final DateTime now;

  /// 是不是面板此刻摆着的那一件。角标与浅蓝底都看它。
  final bool isCurrent;

  /// 这一条正在走秒。
  final bool isRunning;

  /// 这一条在计时但暂停着。暂停时按钮仍占着钟的位置，点它回面板继续。
  final bool isPaused;

  /// 走秒到哪儿了，`mm:ss`。
  final String clockLabel;

  /// 详情展开着没。
  final bool open;

  final VoidCallback onTapHead;
  final VoidCallback onToggleDone;
  final VoidCallback onStart;
  final VoidCallback onOpenPanel;

  /// 标记按钮：把这一件设成小任务窗口的当前事项，但不开始计时。
  final VoidCallback onMark;

  /// 展开时的详情，收起时传 null。
  final Widget? detail;

  @override
  State<SoloRow> createState() => _SoloRowState();
}

class _SoloRowState extends State<SoloRow> {
  bool _hover = false;

  static const double _rowMinHeight = 72;
  static const Color _hoverBorder = Color(0xFFC6D3E4);
  static const Color _currentBorder = Color(0xFFCFDCFB);
  static const Color _openBorder = Color(0xFFB9C8DD);
  static const Color _doneBg = Color(0xFFFAFBFE);
  static const Color _doneButtonBg = Color(0xFFF7F8FB);

  Color get _borderColor {
    if (widget.open) return _openBorder;
    if (widget.isCurrent) return _currentBorder;
    if (_hover) return _hoverBorder;
    return AppTheme.line;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final card = AnimatedContainer(
      key: ValueKey<String>('solo-row-${task.id}'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.ease,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isCurrent
            ? AppTheme.accentSoft
            : task.done
            ? _doneBg
            : Colors.white,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapHead,
                // 列表里高度是不定的，不能拿 Row 的 stretch 去拉那条竖条；
                // 用 Stack 贴着行头画，整行多高它就多高。
                child: Stack(
                  children: [
                    // 当前行的左边那条 3 像素竖条。原型用的是 inset 阴影，
                    // Flutter 的 BoxDecoration 没有这一项，就实打实画一条。
                    if (widget.isCurrent)
                      const Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(width: 3, child: ColoredBox(color: AppTheme.primary)),
                      ),
                    _buildHead(task),
                  ],
                ),
              ),
            ),
            if (widget.open && widget.detail != null) widget.detail!,
          ],
        ),
      ),
    );

    return card;
  }

  Widget _buildHead(TaskItem task) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 名称列定宽 42%：说明不能把行撑高，名称也不该因为说明长短而忽宽忽窄。
        final nameWidth = constraints.maxWidth * 0.42;
        return Container(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          padding: EdgeInsets.only(left: widget.isCurrent ? 13 : 16, right: 16),
          child: Row(
            children: [
              _CheckBox(
                key: ValueKey<String>('solo-check-${task.id}'),
                done: task.done,
                running: widget.isRunning || widget.isPaused,
                onTap: widget.onToggleDone,
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: nameWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: task.done ? AppTheme.ink3 : AppTheme.ink,
                          decoration: task.done ? TextDecoration.lineThrough : null,
                          decorationColor: AppTheme.ink3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _metaText(task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.ink3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: task.done ? AppTheme.ink3 : AppTheme.ink2,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.isCurrent && !task.done) ...[
                const SizedBox(width: 8),
                const _CurrentChip(),
              ],
              const SizedBox(width: 14),
              // 「开始」左侧那枚标记按钮。《页面操作流程》第 5 节：点它把这一件设成
              // 小任务窗口的当前事项，但不开始计时。
              if (!task.done) ...[
                _MarkButton(key: ValueKey<String>('solo-mark-${task.id}'), onTap: widget.onMark),
                const SizedBox(width: 8),
              ],
              _buildButton(task),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton(TaskItem task) {
    if (task.done) {
      return Container(
        key: ValueKey<String>('solo-done-${task.id}'),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _doneButtonBg,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('已完成', style: TextStyle(fontSize: 13, color: AppTheme.ink3)),
      );
    }
    if (widget.isRunning || widget.isPaused) {
      final paused = widget.isPaused && !widget.isRunning;
      return GestureDetector(
        key: ValueKey<String>('solo-clock-${task.id}'),
        onTap: widget.onOpenPanel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 32,
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: paused ? AppTheme.warmSoft : AppTheme.primary,
              border: paused ? Border.all(color: AppTheme.warm) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.clockLabel,
              style: TextStyle(
                fontSize: 13,
                color: paused ? AppTheme.ink : Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      );
    }
    return _StartButton(key: ValueKey<String>('solo-start-${task.id}'), onTap: widget.onStart);
  }

  String _metaText(TaskItem task) {
    final created = relativeDay(task.createdAt, widget.now);
    if (task.spentSec <= 0) return created;
    return '$created · 已做 ${minutesOf(task.spentSec)} 分钟';
  }
}

/// 18 见方、圆角 6 的两像素框。三套配色对应没做过、正在计时、已完成。
class _CheckBox extends StatelessWidget {
  const _CheckBox({super.key, required this.done, required this.running, required this.onTap});

  final bool done;
  final bool running;
  final VoidCallback onTap;

  static const Color _border = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppTheme.primary
        : running
        ? AppTheme.warmSoft
        : Colors.white;
    final borderColor = done
        ? AppTheme.primary
        : running
        ? AppTheme.warm
        : _border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
        ),
      ),
    );
  }
}

/// 「当前」角标：只在未完成且是面板当前事务时出现。
class _CurrentChip extends StatelessWidget {
  const _CurrentChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFDCFB)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('当前', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
    );
  }
}

/// 标记键：把这一件设为小任务窗口的当前事项，不开计时。
///
/// 图标是图钉，悬停给出提示；样式比「开始」轻一档，免得两个键抢同一个注意力。
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.ease,
            height: 32,
            width: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? AppTheme.primarySoft : Colors.white,
              border: Border.all(color: _hover ? AppTheme.primary : AppTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.push_pin_outlined,
              size: 15,
              color: _hover ? AppTheme.primary : AppTheme.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 开始键：白底主色字，悬停时边框与底一起提一档。
class _StartButton extends StatefulWidget {
  const _StartButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.ease,
          height: 32,
          constraints: const BoxConstraints(minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? AppTheme.primarySoft : Colors.white,
            border: Border.all(color: _hover ? AppTheme.primary : AppTheme.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('开始', style: TextStyle(fontSize: 13, color: AppTheme.primary)),
        ),
      ),
    );
  }
}
