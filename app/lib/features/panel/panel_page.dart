import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/key_configured.dart';
import '../../app/theme.dart';
import 'panel_notifier.dart';

/// 第 2 页 · 悬停小面板的实体内容。
///
/// 外面那层玻璃框、位置与尺寸由常驻页的 `PetFrame` 摆好（宽 25%、高 35%），
/// 这一层只负责里面的东西：项目名与流程轴（或独立事项）、随手记、动作区、问一问。
/// 所有数值取自 `prototype/整体原型.html` 的 `aside.panel` 一节。
class PanelPage extends ConsumerStatefulWidget {
  const PanelPage({super.key, this.onOpenProject});

  /// 点项目名时回传项目 id，由常驻页切档并落到第 6 页那一个项目。
  ///
  /// 可空：`/panel` 那条地址能直达这一页，那里没有常驻页可回传。
  final void Function(String projectId)? onOpenProject;

  @override
  ConsumerState<PanelPage> createState() => _PanelPageState();
}

/// 面板内边距。原型 `.panel{padding:16px}`。
const double _panelPadding = 16;

/// 流程轴上下外边距。原型 `.track{margin:11px 0 12px}`。
const double _trackTop = 11;
const double _trackBottom = 12;

/// 流程轴段高与段间距。原型 `.track i{height:5px}`、`.track{gap:5px}`。
const double _trackHeight = 5;
const double _trackGap = 5;

/// 只读输入框的底。原型 `.ai textarea[readonly]{background:#f4f7fb}`。
const Color _readonlyBg = Color(0xFFF4F7FB);

/// 回答卡片。原型 `.answer`。
const Color _answerLine = Color(0xFFCFDCFB);
const Color _answerInk = Color(0xFF1F3A6E);
const Color _answerQInk = Color(0xFF4B6591);

/// 问一问输入框最大高度。原型 `.ai textarea{max-height:104px}`，超出就在框里滚。
const double _askMaxHeight = 104;

/// 输入框与计时条的统一高度。
///
/// 使用者 2026-10-25 要求随手记框与问一问框同高、计时条紧贴随手记下方，
/// 三处取同一个数，单行时三者上下的边就对齐了。
const double _controlHeight = 38;

/// 计时条上时钟的字号。原型 `.clock{font-size:21px}`。
const double _clockFontSize = 21;

/// 停止键悬停时的底色。原型 `.timerbar button.stop:hover{background:#c8402f}`。
const Color _stopHover = Color(0xFFC8402F);

class _PanelPageState extends ConsumerState<PanelPage> {
  final TextEditingController _scratch = TextEditingController();
  final TextEditingController _ask = TextEditingController();
  final FocusNode _scratchFocus = FocusNode();
  final FocusNode _askFocus = FocusNode();

  /// 当前把哪个事务的随手记灌进了输入框。任务换了才重新灌，免得打字时被覆盖。
  String? _syncedTaskId;

  @override
  void dispose() {
    _scratch.dispose();
    _ask.dispose();
    _scratchFocus.dispose();
    _askFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panelNotifierProvider);

    // 任务换了才把已落盘的随手记灌进来：同一个任务内的输入由用户自己掌握。
    if (_syncedTaskId != state.taskId) {
      _syncedTaskId = state.taskId;
      _scratch.text = state.scratch;
    }

    return Container(
      padding: const EdgeInsets.all(_panelPadding),
      decoration: BoxDecoration(
        // 原型 `background:var(--glass)` 配 `backdrop-filter:blur(14px)`。
        // 桌面端实时模糊要单独的窗口通道，这里用高不透明度的白顶替，
        // 面板本身仍读得清；B24 视觉打磨时再评估要不要换 BackdropFilter。
        color: Colors.white.withValues(alpha: 0.96),
        // 原型 `.panel{border-radius:var(--r)}`，`--r` 是 10，不是页面那张纸的 14。
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.line),
        // 原型 `--shadow:0 12px 32px rgba(30,50,80,.16)`。
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3250).withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      // 内容不再整块滚动：问一问那一行要钉在窗口最下方，中间留给回答区，
      // 所以这一层必须是「定高列 + 可伸缩的回答区」，不能套在滚动视图里。
      child: state.isEmpty ? _buildEmpty() : _buildBody(state),
    );
  }

  /// 空态。《页面操作流程》第 4 节：「无事项状态，正中央显示『当前暂无事项』」，
  /// 下面跟一句往哪走——空态只给一句「没有」等于把用户堵在面板里。
  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当前暂无事项',
            key: ValueKey<String>('panel-empty-title'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink),
          ),
          SizedBox(height: 6),
          Text(
            '点桌宠进主界面挑一件',
            key: ValueKey<String>('panel-empty-hint'),
            style: TextStyle(fontSize: 12, color: AppTheme.ink3),
          ),
        ],
      ),
    );
  }

  /// 面板主体按《页面操作流程》第 4 节的行序摆：
  /// 行 1—3 名字与截止、胶囊条、共几步第几步 → 行 4—5 随手记 →
  /// 行 6 开始／计时行 → 行 7 标记完成 → 行 8 问一问。
  Widget _buildBody(PanelState state) {
    final started = state.running || state.elapsedMs > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.kind == PanelKind.project) _buildProject(state) else _buildSolo(state),
        _buildScratch(),
        _buildActions(state),
        // 类型 2 的规则：计时行出现时「标记完成」这一行消失。
        if (!(state.kind == PanelKind.solo && started)) _buildFinishLink(),
        Expanded(child: _buildAnswers(state)),
        _buildAsk(state),
      ],
    );
  }

  /// 类型 1 的行 1—行 3：项目名与截止、胶囊条、共几步第几步。
  Widget _buildProject(PanelState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitleLine(
          name: state.title,
          nameKey: const ValueKey<String>('panel-project-name'),
          due: state.dueLabel,
          onTap: state.projectId == null ? null : () => widget.onOpenProject?.call(state.projectId!),
        ),
        Padding(
          padding: const EdgeInsets.only(top: _trackTop, bottom: _trackBottom),
          child: _Track(
            total: state.totalSteps,
            current: state.currentStep,
            names: state.stepNames,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            state.metaLabel,
            key: const ValueKey<String>('panel-meta'),
            style: const TextStyle(fontSize: 12, color: AppTheme.ink2),
          ),
        ),
      ],
    );
  }

  /// 类型 2 的行 1：事项名与截止。独立事项没有截止字段，没填就只显示名字。
  Widget _buildSolo(PanelState state) {
    return _buildTitleLine(
      name: state.title,
      nameKey: const ValueKey<String>('panel-solo-name'),
      due: state.dueLabel,
    );
  }

  /// 行 1：左边名字，右边截止时间；没填截止就只留名字。
  ///
  /// 项目名可点（PRD 第 2 页 370 行）：落到第 6 页并展开这个项目。独立事项没有
  /// 项目页可落，不传 `onTap`。
  Widget _buildTitleLine({
    required String name,
    required Key nameKey,
    required String? due,
    VoidCallback? onTap,
  }) {
    final label = Text(
      name,
      key: nameKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: onTap == null
                ? label
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const ValueKey<String>('panel-project-link'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: label,
                    ),
                  ),
          ),
          if (due != null)
            Text(
              due,
              key: const ValueKey<String>('panel-due'),
              style: const TextStyle(fontSize: 11, color: AppTheme.ink3),
            ),
        ],
      ),
    );
  }

  /// 随手记：标签 11 三档墨，输入框与问一问同高、随内容长高，圆角 8、边框线二档。
  ///
  /// 这一格仍然失焦即落盘——小任务窗口的随手记是边做边记的，不该再要一次「保存」；
  /// 第 4 页编辑框里那份随手记改成了手动保存，两边口径不同，别混。
  Widget _buildScratch() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) ref.read(panelNotifierProvider.notifier).commitScratch();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('随手记', style: TextStyle(fontSize: 11, color: AppTheme.ink3)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _controlHeight),
              child: TextField(
                key: const ValueKey<String>('panel-scratch'),
                controller: _scratch,
                focusNode: _scratchFocus,
                onChanged: ref.read(panelNotifierProvider.notifier).draftScratch,
                // 行数与问一问一致：单行时两者等高，写长了各自长高。
                minLines: 1,
                maxLines: null,
                style: const TextStyle(fontSize: 13, height: 20 / 13, color: AppTheme.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '在此处记录你的成果',
                  // 占位文字只占一行：窗口窄的时候折成两行会把框撑高，
                  // 随手记与问一问就不再等高了。
                  hintMaxLines: 1,
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.ink3),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: AppTheme.line2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: AppTheme.line2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 问一问：输入最小高与随手记一致，右侧 42×36 的发送键。AI 未接通时只读、键禁用。
  ///
  /// 这一行钉在面板最底部，上方剩余的空间全给回答内容。
  Widget _buildAsk(PanelState state) {
    // 直接 watch 全站开关而不是读 state.aiReady：设置页存完 key 面板还开着，
    // 这一行要立刻从只读变成可写，不能等下一次 refresh。
    final enabled = ref.watch(keyConfiguredProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _controlHeight,
                    maxHeight: _askMaxHeight,
                  ),
                  child: TextField(
                    key: const ValueKey<String>('panel-ask'),
                    controller: _ask,
                    focusNode: _askFocus,
                    readOnly: !enabled,
                    minLines: 1,
                    maxLines: null,
                    style: TextStyle(
                      fontSize: 13,
                      height: 20 / 13,
                      // 只读时字色降一档：原型 `.ai textarea[readonly]{color:var(--ink2)}`。
                      color: enabled ? AppTheme.ink : AppTheme.ink2,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: enabled ? Colors.white : _readonlyBg,
                      // 没配 key 时占位文字直接指路设置页，原型 `renderAi` 就是这么写的。
                      hintText: enabled ? '有什么可以帮助你的' : '请前往设置页配置API key',
                      // 与随手记同一口径：占位文字只占一行，框高才守得住 38。
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.ink3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: AppTheme.line),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: AppTheme.line),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                // 原型 `.ai button:disabled{opacity:.4}`。
                opacity: enabled ? 1 : 0.4,
                child: SizedBox(
                  width: 42,
                  height: _controlHeight,
                  child: OutlinedButton(
                    key: const ValueKey<String>('panel-send'),
                    onPressed: enabled
                        ? () {
                            ref.read(panelNotifierProvider.notifier).ask(_ask.text);
                            _ask.clear();
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.ink2,
                      side: const BorderSide(color: AppTheme.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    // quarterTurns 走顺时针，3 格即逆时针 90°，与设计稿一致。
                    child: const RotatedBox(
                      quarterTurns: 3,
                      child: Icon(Icons.send_outlined, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 问答记录。原型 `.answers`：上边距 10、条间 8；
  /// 每条卡片 13/1.65、内边距 10/12、圆角 8，问题那一行 12 号深蓝灰。
  ///
  /// 高度不再封顶 150，而是把面板中间剩下的空间全占住：回答多了在框里滚，
  /// 没有回答时这块空白就是回答内容的预留区。
  Widget _buildAnswers(PanelState state) {
    if (state.answers.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey<String>('panel-answers'),
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < state.answers.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == state.answers.length - 1 ? 0 : 8),
                child: Container(
                  key: ValueKey<String>('panel-answer-$i'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    border: Border.all(color: _answerLine),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '你问：${state.answers[i].question}',
                          style: const TextStyle(fontSize: 12, color: _answerQInk),
                        ),
                      ),
                      Text(
                        state.answers[i].text,
                        style: const TextStyle(fontSize: 13, height: 1.65, color: _answerInk),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 行 6：没开始过给「开始」按钮，跑过或攒过时长给计时行。
  Widget _buildActions(PanelState state) {
    final started = state.running || state.elapsedMs > 0;
    if (started) return _buildTimerBar(state);
    return Padding(
      // 上边距 4 与随手记框的下边距合成 8：动作区紧贴随手记。
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 44,
        child: FilledButton(
          key: const ValueKey<String>('panel-start'),
          onPressed: () => unawaited(ref.read(panelNotifierProvider.notifier).start()),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
            textStyle: const TextStyle(fontSize: 15),
          ),
          child: const Text('开始'),
        ),
      ),
    );
  }

  /// 行 7「标记完成」。不必先计时也能收尾。
  Widget _buildFinishLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: InkWell(
          key: const ValueKey<String>('panel-finish'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => ref.read(panelNotifierProvider.notifier).finish(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text('标记完成', style: TextStyle(fontSize: 12, color: AppTheme.ink2)),
          ),
        ),
      ),
    );
  }

  /// 计时行：左边走秒（`00:00:00`），右边「暂停／开始」与「停止」。
  ///
  /// 《页面操作流程》第 4 节：「点击暂停按钮，计时暂停，暂停按钮变为开始按钮」。
  /// 暂停之后按键换成「开始」，再点接着走；「停止」才是收尾。规格里没有「重置」
  /// 这一档，也就不留它。
  Widget _buildTimerBar(PanelState state) {
    final notifier = ref.read(panelNotifierProvider.notifier);
    // 暂停中或根本没在跑（攒过时长但已停表）都算「可以按开始」。
    final resumable = state.paused || !state.running;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: _controlHeight,
        child: Row(
          key: const ValueKey<String>('panel-timerbar'),
          children: [
            Expanded(
              child: Text(
                state.clockLabel,
                key: const ValueKey<String>('panel-clock'),
                style: TextStyle(
                  fontSize: _clockFontSize,
                  height: 1,
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  // 暂停时数字转灰：原型 `.timerbar.paused .clock{color:var(--ink2)}`。
                  color: state.paused ? AppTheme.ink2 : AppTheme.ink,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimerButton(
                  key: ValueKey<String>(resumable ? 'panel-resume' : 'panel-pause'),
                  icon: resumable ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  iconSize: 15,
                  label: resumable ? '开始' : '暂停',
                  onTap: resumable
                      ? () => unawaited(notifier.continueFromSpent())
                      : notifier.pause,
                ),
                const SizedBox(width: 8),
                _TimerButton(
                  key: const ValueKey<String>('panel-stop'),
                  icon: Icons.stop_rounded,
                  iconSize: 14,
                  label: '停止',
                  danger: true,
                  onTap: () => unawaited(notifier.stop()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 计时条上的图标按钮：44 × 38、圆角 10；停止键红底白图标。
///
/// 悬停按原型换边色：普通键边变主色、图标也变主色；停止键底色压深一档。
/// 只改颜色不挪位置，面板是悬停弹层，不做抬升免得指针一抖就跳。
class _TimerButton extends StatefulWidget {
  const _TimerButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final double iconSize;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_TimerButton> createState() => _TimerButtonState();
}

class _TimerButtonState extends State<_TimerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusControl);
    final background = widget.danger ? (_hover ? _stopHover : AppTheme.danger) : Colors.white;
    final border = widget.danger
        ? (_hover ? _stopHover : AppTheme.danger)
        : (_hover ? AppTheme.primary : AppTheme.line);
    final iconColor = widget.danger ? Colors.white : (_hover ? AppTheme.primary : AppTheme.ink);
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 200),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: SizedBox(
          width: 44,
          height: 38,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: border),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// 流程轴：等分成「步骤总数」段，当前步及之前的段用主色。
///
/// 每段带步名的悬停提示——原型 `buildTrack` 给每段挂了 `tip` 浮层，
/// 鼠标停上去能看到这一步叫什么。
class _Track extends StatelessWidget {
  const _Track({required this.total, required this.current, required this.names});

  final int total;

  /// 当前步，从 1 起；亮前这么多段。
  final int current;

  /// 按顺序排好的步名，可能为空或比 [total] 短。
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('panel-track'),
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: i < names.length
                ? Tooltip(
                    key: ValueKey<String>('panel-track-tip-$i'),
                    message: '第 ${i + 1} 步 · ${names[i]}',
                    waitDuration: const Duration(milliseconds: 200),
                    child: _segment(i),
                  )
                : _segment(i),
          ),
      ],
    );
  }

  /// 一段灰色或蓝色的细条。
  Widget _segment(int i) {
    return Container(
      key: ValueKey<String>('panel-track-$i'),
      height: _trackHeight,
      margin: EdgeInsets.only(right: i == total - 1 ? 0 : _trackGap),
      decoration: BoxDecoration(
        color: i < current ? AppTheme.primary : AppTheme.track,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
