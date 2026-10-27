// material 里也有一套 Step / StepState（步进器用的），这里要的是 domain 的步骤实体。
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../domain/model/step.dart';

part 'project_flow_editor.dart';

/// 分段进度条与「编辑流程」：段数等于步骤数，点一段只看那一步。
///
/// 数值照单页原型 `.barrow` / `.track` / `.flowbtn`：段落高 5、圆角 3、
/// 段间 5、未完成 `#d8e0ec`、已完成主色、悬停亮度 94%、筛中 2 像素描边外扩 2。
class ProjectFlowBar extends StatelessWidget {
  const ProjectFlowBar({
    super.key,
    required this.steps,
    required this.filterStep,
    required this.flowEditing,
    required this.onTapSegment,
    required this.onToggleEdit,
  });

  final List<Step> steps;
  final int? filterStep;
  final bool flowEditing;
  final ValueChanged<int> onTapSegment;
  final VoidCallback onToggleEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: steps.isEmpty
                ? const SizedBox(height: 9)
                : Row(
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        Expanded(
                          child: _Segment(
                            key: ValueKey<String>('flow-seg-$i'),
                            done: steps[i].state == StepState.done,
                            selected: filterStep == i,
                            label: segmentLabel(i, steps[i].name),
                            onTap: () => onTapSegment(i),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          _FlowEditButton(editing: flowEditing, onTap: onToggleEdit),
        ],
      ),
    );
  }
}

/// 一段。悬停时把底色压暗一点，筛中时外面套一圈主色描边。
class _Segment extends StatefulWidget {
  const _Segment({
    super.key,
    required this.done,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.done ? AppTheme.primary : const Color(0xFFD8E0EC);
    final fill = _hover ? Color.lerp(base, Colors.black, 0.06)! : base;

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            height: 9,
            child: Stack(
              children: [
                Positioned.fill(
                  top: 2,
                  bottom: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                if (widget.selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「编辑流程 / 收起编辑」：透明底、无边框、悬停加下划线。
class _FlowEditButton extends StatefulWidget {
  const _FlowEditButton({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  State<_FlowEditButton> createState() => _FlowEditButtonState();
}

class _FlowEditButtonState extends State<_FlowEditButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const ValueKey<String>('flow-edit'),
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            widget.editing ? '收起编辑' : '编辑流程',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: AppTheme.primary,
              decoration: _hover ? TextDecoration.underline : null,
              decorationColor: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 筛选提示行：「第 N 步 · 名 ×」。
///
/// 底 `#eef3fe`、边 `#cfdcfb`、圆角 8、内边距 5/10、宽度随内容，上 8 下 2 左右 2。
class ProjectFilterTip extends StatelessWidget {
  const ProjectFilterTip({super.key, required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey<String>('flow-tip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3FE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCFDCFB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: const ValueKey<String>('flow-tip-clear'),
                  onTap: onClear,
                  child: const Text(
                    '×',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.primary,
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
