import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/model/settings.dart';
import '../../platform/window/drag_rule.dart';
import '../panel/panel_page.dart';
import 'pet_bubble_metrics.dart';
import 'pet_bubble_view.dart';
import 'pet_frame.dart';
import 'pet_message.dart';
import 'pet_notifier.dart';
import 'pet_stage_port.dart';
import 'pet_visual.dart';

/// 第 1 页 · 桌面常驻态。
///
/// 只做三件事：把宠物摆在窗口给的框里、把气泡挂在头顶、把悬停与点击翻成
/// Notifier 的动作。窗口多大、宠物在哪一块全由 [PetFrame] 说了算——
/// 这一页不认识窗口，也不认识屏幕。
class PetPage extends ConsumerStatefulWidget {
  const PetPage({
    super.key,
    this.onOpenMain,
    this.onViewProject,
    this.onOpenProjects,
    this.onOpenSettings,
  });

  /// 切展开态之后去主界面。路由在 `app/router.dart` 里，由它传进来：
  /// features 不认识 `MainTab`，也不手写地址。
  final VoidCallback? onOpenMain;

  /// 截止气泡点「查看」落到哪个项目。项目页还没建，现在只把这个 id 交出去。
  final void Function(String projectId)? onViewProject;

  /// 播报点「查看」去项目列表——它一次报好几个项目，没有唯一的目标。
  final VoidCallback? onOpenProjects;

  /// 右键宠物打开设置（PRD 第 1 页交互表）。
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<PetPage> createState() => _PetPageState();
}

/// 按下到开始拖动之间的余量。没有它，点一下也会被当成拖动。
const double _dragSlop = 4;

/// 宠物那一块热区的键。
///
/// widget 测试要往这块上放鼠标；形象图在测试里没加载出尺寸，量图会落到边界上。
const Key petHotZoneKey = ValueKey<String>('pet-hotzone');

class _PetPageState extends ConsumerState<PetPage> {
  /// 上一次推给窗口的档位与气泡高度，用来判断要不要再推一次。
  PetViewStage? _pushedStage;
  double? _pushedDeadlineHeight;
  double? _pushedReportHeight;

  Offset? _pressAt;
  bool _dragStarted = false;

  /// 这一轮拖动是不是展开态起来的。只有展开态才由这里喂位移与收尾，
  /// 常驻态窗口就是宠物本身，交给系统跟手。
  bool _dragExpanded = false;

  PetNotifier get _notifier => ref.read(petNotifierProvider.notifier);

  /// 托盘点「唤出主界面」时打的那一下闸。
  ValueNotifier<int>? _mainRequests;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _mainRequests = _notifier.mainRequests..addListener(_onMainRequested);
  }

  @override
  void dispose() {
    _mainRequests?.removeListener(_onMainRequested);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// 托盘要主界面：走和点宠物同一条路，别让它只把窗口拿到前面。
  void _onMainRequested() => unawaited(_openMain());

  /// Esc 把气泡全关掉。原型里截止气泡没有关闭按钮，只能这样收。
  ///
  /// F8 造一组气泡 / 再按一下收掉：真气泡要等真实截止与项目数据凑齐才出现，
  /// 实机上不一定碰得到，留一个键专门看气泡这一块。
  ///
  /// 用全局键盘钩子而不是 `Focus`：宠物窗口不该为了收气泡去抢输入焦点。
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f8) {
      _notifier.togglePreviewBubbles();
      return true;
    }
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (ref.read(petNotifierProvider).bubbles.isEmpty) return false;
    _notifier.dismissAllBubbles();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(petFrameProvider);
    final state = ref.watch(petNotifierProvider);
    final port = ref.watch(petStagePortProvider);

    // 状态一变就让窗口尺寸跟上。晚一拍气泡或面板就会被窗口裁掉。
    ref.listen<PetState>(petNotifierProvider, (_, next) => _push(port, next));

    return Material(
      key: const ValueKey<String>('page-pet'),
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: frame.size,
        child: Stack(
          children: [
            if (state.stage == PetViewStage.main && frame.main != null)
              Positioned.fromRect(rect: frame.main!, child: const _MainSurface()),
            if (state.stage == PetViewStage.panel && frame.panel != null)
              Positioned.fromRect(
                rect: frame.panel!,
                child: MouseRegion(
                  onEnter: (_) => _notifier.hoverEnter(),
                  onExit: (_) => _notifier.hoverExit(),
                  child: _PanelSurface(onOpenProject: _viewProject),
                ),
              ),
            if (frame.deadlineBubble != null && state.deadlines.isNotEmpty)
              Positioned.fromRect(
                rect: frame.deadlineBubble!,
                child: Column(
                  key: const ValueKey<String>('bubble-deadline-stack'),
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < state.deadlines.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == state.deadlines.length - 1 ? 0 : 8),
                        child: SizedBox(
                          height: BubbleMetrics.deadline(),
                          child: DeadlineBubbleView(
                            key: ValueKey<String>('bubble-deadline-${state.deadlines[i].projectId}'),
                            bubble: state.deadlines[i],
                            onView: () => _viewProject(state.deadlines[i].projectId),
                            onDismiss: () => _notifier.dismissDeadline(state.deadlines[i].projectId),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (frame.reportBubble != null && state.report != null)
              Positioned.fromRect(
                rect: frame.reportBubble!,
                child: ReportBubbleView(
                  bubble: state.report!,
                  onView: _viewReport,
                  onDismiss: () => _notifier.dismiss(PetBubbleKind.report),
                ),
              ),
            _pet(frame, state, port),
          ],
        ),
      ),
    );
  }

  /// 宠物这一块：悬停出面板、左键拖窗口、点一下切档。
  Widget _pet(PetFrame frame, PetState state, PetStagePort port) {
    final expanded = state.stage == PetViewStage.main;
    return Positioned.fromRect(
      key: petHotZoneKey,
      rect: frame.pet,
      child: MouseRegion(
        onEnter: (_) {
          if (port.dragging.value) return;
          _notifier.hoverEnter();
        },
        onExit: (_) => _notifier.hoverExit(),
        child: Listener(
          onPointerDown: (event) {
            if (!canStartDrag(event.buttons)) return;
            _pressAt = event.position;
            _dragStarted = false;
            _dragExpanded = expanded;
          },
          onPointerMove: (event) {
            // 已经在拖：展开态由这里逐帧喂位移（窗口铺满、宠物自己走），常驻态不管。
            if (_dragStarted) {
              if (_dragExpanded && event.delta != Offset.zero) {
                unawaited(port.dragBy(event.delta));
              }
              return;
            }
            final from = _pressAt;
            if (from == null) return;
            if (!canStartDrag(event.buttons)) return;
            if ((event.position - from).distance <= _dragSlop) return;
            _dragStarted = true;
            _pressAt = null;
            unawaited(_startDrag(port, expanded: expanded));
          },
          onPointerUp: (_) => _endDrag(port),
          onPointerCancel: (_) => _endDrag(port),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: expanded ? _collapse : _openMain,
            onSecondaryTapDown: (_) => unawaited(_openSettings()),
            child: _PetImage(
              side: state.side,
              expanded: expanded,
              breathing: state.stage == PetViewStage.collapsed,
            ),
          ),
        ),
      ),
    );
  }

  /// 拖动起手：先收掉面板，再让窗口层开始拖宠物。
  ///
  /// 顺序不能反——面板还在的时候窗口是面板档，窗口层会拒绝起手拖动。
  /// 主界面档不收：那里没有面板，收起等于把用户刚点开的界面关掉；它拖的是
  /// 整只宠物，主界面钉在原地。
  Future<void> _startDrag(PetStagePort port, {required bool expanded}) async {
    if (expanded) {
      await port.beginDrag();
      // 起手就抬手的话，beginDrag 可能还没回来：补一次收尾，别让窗口停在铺满的样子。
      if (!_dragStarted) await port.endDrag();
      return;
    }
    _notifier.onDragStart();
    await port.showCollapsed();
    await port.beginDrag();
  }

  /// 抬手。只有展开态需要显式收尾；常驻态由窗口层从系统拖动反推。
  void _endDrag(PetStagePort port) {
    _pressAt = null;
    if (!_dragStarted) return;
    _dragStarted = false;
    if (_dragExpanded) unawaited(port.endDrag());
  }

  /// 点一下：切展开态、窗口涨到主界面档，再交给路由开主界面。
  Future<void> _openMain() async {
    _notifier.openMain();
    await ref.read(petStagePortProvider).showMain();
    if (!mounted) return;
    widget.onOpenMain?.call();
  }

  /// 再点一下展开态：收回到常驻档。
  void _collapse() {
    _notifier.collapse();
    unawaited(ref.read(petStagePortProvider).showCollapsed());
  }

  /// 截止气泡点「查看」：收起气泡、切展开态，再落到那个项目。
  void _viewProject(String projectId) {
    _notifier.dismiss(PetBubbleKind.deadline);
    unawaited(_openMain().then((_) => widget.onViewProject?.call(projectId)));
  }

  /// 播报点「查看」：收起气泡、切展开态，去项目列表。
  void _viewReport() {
    _notifier.dismiss(PetBubbleKind.report);
    unawaited(_openMain().then((_) => widget.onOpenProjects?.call()));
  }

  /// 右键宠物：先切到主界面档，再跳设置页。
  ///
  /// 只跳路由不切档的话，设置页会被塞进收起档那个小窗里——宽两百多的框装一张
  /// 四百二十宽的卡片。已经在主界面档时不再走一遍 `_openMain`，免得刚摆好的
  /// 窗口又收放一次。
  Future<void> _openSettings() async {
    if (_pushedStage == PetViewStage.main) {
      widget.onOpenSettings?.call();
      return;
    }
    await _openMain().then((_) => widget.onOpenSettings?.call());
  }

  /// 把档位与气泡占位推给窗口。内容没变就不推，免得窗口一直重摆。
  ///
  /// 气泡高度按原型的内容高度算好一起推：窗口不知它多高就会把字裁掉。
  void _push(PetStagePort port, PetState next) {
    final report = next.report;
    final deadlineHeight = next.deadlines.isEmpty
        ? null
        : BubbleMetrics.deadlineStack(next.deadlines.length);
    final reportHeight = report == null
        ? null
        : BubbleMetrics.report(rows: report.rows.length);
    if (deadlineHeight != _pushedDeadlineHeight || reportHeight != _pushedReportHeight) {
      _pushedDeadlineHeight = deadlineHeight;
      _pushedReportHeight = reportHeight;
      unawaited(port.showBubbles(deadlineHeight: deadlineHeight, reportHeight: reportHeight));
    }
    if (next.stage != _pushedStage) {
      _pushedStage = next.stage;
      unawaited(switch (next.stage) {
        PetViewStage.collapsed => port.showCollapsed(),
        PetViewStage.panel => port.showPanel(),
        PetViewStage.main => port.showMain(),
      });
    }
  }
}

/// 宠物形象。收起用右缘那张，展开用正面一张。
///
/// 竖条图放进正方形框会留白，所以靠右对齐，留白落在屏幕内侧，
/// 看上去仍是贴着边站的。正常态给一点呼吸起伏（±1.5% 缩放）。
class _PetImage extends StatefulWidget {
  const _PetImage({required this.side, required this.expanded, required this.breathing});

  final PetSide side;
  final bool expanded;
  final bool breathing;

  @override
  State<_PetImage> createState() => _PetImageState();
}

class _PetImageState extends State<_PetImage> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
    lowerBound: 1,
    upperBound: 1.015,
  );

  @override
  void initState() {
    super.initState();
    _syncBreath();
  }

  @override
  void didUpdateWidget(covariant _PetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breathing != widget.breathing) _syncBreath();
  }

  void _syncBreath() {
    if (widget.breathing) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 1;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ScaleTransition(
        scale: _breath,
        child: Image.asset(
          petImageOf(side: widget.side, expanded: widget.expanded),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 悬停面板的内容。位置与尺寸由 `PetFrame.panel` 让出来，样式与内容在 `PanelPage` 里。
class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.onOpenProject});

  /// 面板里点项目名要落到第 6 页那一个项目；动作在常驻页里做，面板只管回传 id。
  final void Function(String projectId) onOpenProject;

  @override
  Widget build(BuildContext context) {
    return PanelPage(onOpenProject: onOpenProject);
  }
}

/// 主界面档的垫底一层。真内容由 B11 的壳接上，这里只把窗口填满，
/// 让「点一下开主界面」有一条看得见的路。
class _MainSurface extends StatelessWidget {
  const _MainSurface();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.shellBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPage),
        border: Border.all(color: AppTheme.line),
      ),
      alignment: Alignment.center,
      child: const Text(
        '主界面',
        style: TextStyle(
          fontSize: AppTheme.fontPageTitle,
          color: AppTheme.ink2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
