import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/model/ai_attachment.dart';
import '../../domain/model/planned_step.dart';
import 'project_ai_state.dart';

/// 输入框与附件键的统一高度。与悬停面板的问一问同口径（38）。
const double _controlHeight = 38;

/// 输入框最多长到多高，超出就在框里滚。与面板的 104 一致。
const double _askMaxHeight = 104;

/// 附件标签的高度。
const double _chipHeight = 26;

/// 项目详情页的「AI 帮助」块（PRD 第 6 页 588–605 行）。
///
/// 收起时只占一行，展开后是「写一句目标（可带图与文件）→ 发出去拆 → 看一下
/// 要不要 → 应用到项目」。拆出来的东西不直接落库：模型偶尔给得离谱，先让人
/// 看一眼，点「应用到项目」才算数。
///
/// 输入区沿用悬停小面板问一问的样式：38 高、圆角 8、线二档描边、右侧
/// 42×38 的白底发送键，两处的「问一句」看起来才是一件东西。
class ProjectAiHelp extends StatefulWidget {
  const ProjectAiHelp({
    super.key,
    required this.help,
    required this.onToggle,
    required this.onGoalChanged,
    required this.onAsk,
    required this.onApply,
    required this.onPickAttachments,
    required this.onRemoveAttachment,
  });

  final AiHelp help;
  final VoidCallback onToggle;
  final ValueChanged<String> onGoalChanged;
  final VoidCallback onAsk;
  final VoidCallback onApply;
  final VoidCallback onPickAttachments;
  final ValueChanged<String> onRemoveAttachment;

  @override
  State<ProjectAiHelp> createState() => _ProjectAiHelpState();
}

class _ProjectAiHelpState extends State<ProjectAiHelp> {
  late final TextEditingController _goal = TextEditingController(text: widget.help.goal);

  @override
  void didUpdateWidget(covariant ProjectAiHelp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部把草稿改掉了（换项目、应用到项目之后）才回写，否则会打断正在打字的人。
    if (widget.help.goal != _goal.text) _goal.text = widget.help.goal;
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final help = widget.help;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.line),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'AI 帮助',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontCardTitle,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              const Spacer(),
              if (help.open)
                _AiButton(
                  buttonKey: 'project-ai-toggle',
                  label: '收起',
                  filled: false,
                  onTap: widget.onToggle,
                )
              else
                _AiButton(
                  buttonKey: 'project-ai-toggle',
                  label: '展开',
                  filled: true,
                  onTap: widget.onToggle,
                ),
            ],
          ),
          if (!help.open)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '如果不知道该怎么做，不如让AI帮你拆解任务',
                key: ValueKey<String>('project-ai-caption'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontMeta,
                  color: AppTheme.ink3,
                ),
              ),
            ),
          if (help.open) ...[
            const SizedBox(height: 12),
            _askRow(help),
            if (help.attachments.isNotEmpty) _attachmentRow(help),
            if (help.hint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  help.hint,
                  key: const ValueKey<String>('project-ai-hint'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontMeta,
                    color: AppTheme.ink3,
                  ),
                ),
              ),
            if (help.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  help.error,
                  key: const ValueKey<String>('project-ai-error'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontBody,
                    color: AppTheme.danger,
                  ),
                ),
              ),
            if (help.steps.isNotEmpty) _planBlock(help),
          ],
        ],
      ),
    );
  }

  /// 一行：带附件 → 目标输入 → 发送。三者的高度都对齐到 38。
  Widget _askRow(AiHelp help) {
    final canAttach = !help.busy && help.remainingSlots > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Opacity(
          opacity: canAttach ? 1 : 0.4,
          child: SizedBox(
            width: _controlHeight,
            height: _controlHeight,
            child: OutlinedButton(
              key: const ValueKey<String>('project-ai-attach'),
              onPressed: canAttach ? widget.onPickAttachments : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.ink2,
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.attach_file, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _controlHeight,
              maxHeight: _askMaxHeight,
            ),
            child: TextField(
              key: const ValueKey<String>('project-ai-goal'),
              controller: _goal,
              enabled: !help.busy,
              minLines: 1,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onChanged: widget.onGoalChanged,
              // 回车直接发；空目标又没附件时按 canAsk 什么也不做，和灰掉的发送键一致。
              onSubmitted: (_) {
                if (widget.help.canAsk) widget.onAsk();
              },
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                height: 20 / 13,
                color: AppTheme.ink,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: '输入你想拆解的任务或任务步骤',
                hintMaxLines: 1,
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: AppTheme.ink3,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppTheme.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppTheme.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppTheme.line),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Opacity(
          opacity: help.canAsk ? 1 : 0.4,
          child: SizedBox(
            width: 42,
            height: _controlHeight,
            child: OutlinedButton(
              key: const ValueKey<String>('project-ai-ask'),
              onPressed: help.canAsk ? widget.onAsk : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.ink2,
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: help.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  // quarterTurns 走顺时针，3 格即逆时针 90°，与面板那个键同口径。
                  : const RotatedBox(
                      quarterTurns: 3,
                      child: Icon(Icons.send_outlined, size: 18),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// 已选附件：一行小标签，点右边的叉移掉。图片与文件用不同图标区分。
  Widget _attachmentRow(AiHelp help) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final item in help.attachments) _attachmentChip(item),
      ],
    ),
  );

  Widget _attachmentChip(AiAttachment item) => Container(
    key: ValueKey<String>('project-ai-attachment-${item.name}'),
    height: _chipHeight,
    padding: const EdgeInsets.only(left: 8, right: 4),
    decoration: BoxDecoration(
      color: AppTheme.primarySoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.isImage ? Icons.image_outlined : Icons.description_outlined,
          size: 14,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontMeta,
              color: AppTheme.ink2,
            ),
          ),
        ),
        InkWell(
          key: ValueKey<String>('project-ai-remove-${item.name}'),
          borderRadius: BorderRadius.circular(6),
          onTap: widget.help.busy ? null : () => widget.onRemoveAttachment(item.name),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close, size: 13, color: AppTheme.ink3),
          ),
        ),
      ],
    ),
  );

  Widget _planBlock(AiHelp help) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (help.reply.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            help.reply,
            key: const ValueKey<String>('project-ai-reply'),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontBody,
              color: AppTheme.ink2,
              height: 1.5,
            ),
          ),
        ),
      const SizedBox(height: 10),
      for (var i = 0; i < help.steps.length; i++) _stepRow(i + 1, help.steps[i]),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: _AiButton(
          buttonKey: 'project-ai-apply',
          label: help.applied ? '已应用' : '应用到项目',
          filled: !help.applied,
          onTap: help.canApply ? widget.onApply : null,
        ),
      ),
    ],
  );

  Widget _stepRow(int index, PlannedStep step) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(color: AppTheme.primarySoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontBadge,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.name,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontBody,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              if (step.task.isNotEmpty)
                Text(
                  step.task,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontMeta,
                    color: AppTheme.ink2,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 这一块里的按钮：实心主色与白底描边两种，高度 34。
class _AiButton extends StatelessWidget {
  const _AiButton({
    required this.buttonKey,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String buttonKey;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = filled ? AppTheme.primary : Colors.white;
    final foreground = filled ? Colors.white : AppTheme.ink2;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: InkWell(
          key: ValueKey<String>(buttonKey),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: filled ? null : Border.all(color: AppTheme.line),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontBody,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
