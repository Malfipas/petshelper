import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/model/project_digest.dart';
import '../../domain/model/settings.dart';
import 'pet_message.dart';

/// 桌宠当前显示哪一档。与 `platform/window/pet_layout.dart` 的 `PetStage` 一一对应，
/// 由界面翻给窗口层——features 不认识窗口。
enum PetViewStage { collapsed, panel, main }

/// 气泡的一条内容。
///
/// 两档结构不同：截止只有一句时间加一件事，播报是一串项目行。用 sealed 分开，
/// 界面按类型画，不用一堆可空字段互相猜。
sealed class PetBubble {
  const PetBubble();
}

/// 截止强提醒。
class DeadlineBubble extends PetBubble {
  const DeadlineBubble({
    required this.projectId,
    required this.headline,
    required this.name,
    required this.urgent,
  });

  final String projectId;

  /// 「今天 23:59 截止」。
  final String headline;

  /// 「求职 · 回面试邮件」。
  final String name;

  /// 这条属于 2 小时档还是 24 小时档。
  ///
  /// 两档气泡长得一样，PRD 只要求「各提醒一次」；留着这个字段是为了让测试能断言
  /// 分档没串（`pet_message_test`、`pet_notifier_test` 都靠它）。
  final bool urgent;
}

/// 开机播报。
class ReportBubble extends PetBubble {
  const ReportBubble({required this.rows});

  /// 每个项目一行，项目名与说明分开存，界面好在同一行里给名字加粗。
  ///
  /// 最多三行；被截掉的项目不提示（《页面操作流程》第 2 节：不写「还有 N 个」）。
  final List<ReportRow> rows;
}

/// 常驻态的状态。侧别与高度跟着设置走，气泡是一个可同时放两档的栈。
class PetState {
  const PetState({
    this.stage = PetViewStage.collapsed,
    this.bubbles = const [],
    this.side = PetSide.right,
    this.anchorY = 0.5,
  });

  final PetViewStage stage;
  final List<PetBubble> bubbles;

  /// 宠物贴哪一侧。气泡朝屏幕内侧展开，所以这一项决定气泡的角。
  final PetSide side;

  /// 纵向位置，0 顶 1 底。
  final double anchorY;

  DeadlineBubble? get deadline {
    for (final bubble in bubbles) {
      if (bubble is DeadlineBubble) return bubble;
    }
    return null;
  }

  ReportBubble? get report {
    for (final bubble in bubbles) {
      if (bubble is ReportBubble) return bubble;
    }
    return null;
  }

  bool get hasBubbles => bubbles.isNotEmpty;

  /// 气泡栈最多同时摆几块。多出来的先挂着不呈现，等前面的收掉再冒出来。
  static const int maxVisibleBubbles = 3;

  /// 这一刻真正摆出来的气泡，按出现时间先后、新的在上。
  ///
  /// 列表本身是「新的插在最前」，所以取前三块就是最新的三块；界面按列表顺序从上往
  /// 下画，正好是「先出现的在下面、后出现的在上面」。
  List<PetBubble> get visibleBubbles => bubbles.length <= maxVisibleBubbles
      ? bubbles
      : bubbles.sublist(0, maxVisibleBubbles);


  /// 摆出来的截止气泡，新的在前。
  List<DeadlineBubble> get deadlines => [
    for (final bubble in visibleBubbles)
      if (bubble is DeadlineBubble) bubble,
  ];

  PetState copyWith({
    PetViewStage? stage,
    List<PetBubble>? bubbles,
    PetSide? side,
    double? anchorY,
  }) {
    return PetState(
      stage: stage ?? this.stage,
      bubbles: bubbles ?? this.bubbles,
      side: side ?? this.side,
      anchorY: anchorY ?? this.anchorY,
    );
  }
}

/// 常驻态的 Notifier：管气泡栈、悬停计时、以及点一下进主界面。
///
/// 窗口本身不归它管——档位变化由界面翻给窗口层，这样同一个 Notifier
/// 在 widget 测试里不需要真的开窗。
class PetNotifier extends Notifier<PetState> {
  /// 悬停多久出面板。PRD 第 1 页定的是 300 毫秒。
  static const Duration hoverOpenDelay = Duration(milliseconds: 300);

  /// 指针移开后多久收面板。留一点余量，免得从宠物挪到面板的路上闪一下。
  static const Duration hoverCloseDelay = Duration(milliseconds: 500);

  /// 播报最多列几行。全列出来气泡会高到盖住屏幕。
  static const int maxReportRows = 3;

  /// 多久重新看一眼截止。开机算一次不够——挂机一整天，2 小时档就错过了。
  static const Duration deadlinePoll = Duration(minutes: 1);

  /// 播报停留多久。PRD 与原型都是「都不点则 15 秒自动收」。
  static const Duration reportLinger = Duration(seconds: 15);

  Timer? _openTimer;
  Timer? _closeTimer;
  Timer? _pollTimer;
  Timer? _reportTimer;

  /// 已经提醒过的截止档（`项目:档位`），同一档只提醒一次。
  final Set<String> _shownDeadlines = {};

  bool _reportPublished = false;
  bool _bubblesEnabled = true;

  /// 拖过一轮之后，指针还没离开宠物：这段时间不弹面板。
  ///
  /// 整体原型用 `dragSuppress` 卡这条：按下置真，`pointerleave` 才清；只点一下
  /// 不算拖，松手就清。少了它，拖完手还停在宠物上，面板立刻又弹出来。
  bool _hoverSuppressed = false;

  /// 托盘点「唤出主界面」时打一下这个闸。
  ///
  /// 托盘那一层拿不到路由，也不该管导航：它只管把「用户要看主界面」这件事报进来，
  /// 由常驻页收到后走和点宠物同一条路——切展开态、叫路由去主界面。
  final ValueNotifier<int> mainRequests = ValueNotifier(0);

  /// 请求把主界面打开：只可能由托盘调用。
  void requestMain() => mainRequests.value++;

  @override
  PetState build() {
    ref.onDispose(() {
      mainRequests.dispose();
      _openTimer?.cancel();
      _closeTimer?.cancel();
      _pollTimer?.cancel();
      _reportTimer?.cancel();
    });
    unawaited(_load());
    return const PetState();
  }

  /// 指针进到宠物上：等一会儿出面板。
  void hoverEnter() {
    if (_hoverSuppressed) return;
    if (state.stage == PetViewStage.main) return;
    _closeTimer?.cancel();
    _openTimer?.cancel();
    _openTimer = Timer(hoverOpenDelay, () {
      state = state.copyWith(stage: PetViewStage.panel);
    });
  }

  /// 指针离开：等一会儿收面板，同时解除拖动后的悬停封锁。
  void hoverExit() {
    _hoverSuppressed = false;
    _openTimer?.cancel();
    if (state.stage != PetViewStage.panel) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(hoverCloseDelay, () {
      if (state.stage == PetViewStage.panel) {
        state = state.copyWith(stage: PetViewStage.collapsed);
      }
    });
  }

  /// 页面里点「开始」：跳过悬停的 300 毫秒，直接把面板摆出来。
  ///
  /// 主界面档也照切：这时主界面正开着，用户刚点完「开始」，要看到的是计时条
  /// 而不是还停在页面里。窗口档位由常驻页按 stage 翻给窗口层。
  void openPanel() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    state = state.copyWith(stage: PetViewStage.panel);
  }

  /// 点一下：切到主界面档。跳转由界面做，Notifier 不认识路由。
  void openMain() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    state = state.copyWith(stage: PetViewStage.main);
  }

  /// 回到常驻档。
  void collapse() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    state = state.copyWith(stage: PetViewStage.collapsed);
  }

  /// 拖动开始时收起面板：拖动期间显示面板既挡视线，也占着窗口尺寸。
  ///
  /// 顺手封锁悬停，直到指针离开——否则拖完手还停在宠物上，面板马上又弹。
  void onDragStart() {
    _hoverSuppressed = true;
    collapse();
  }

  /// 关掉某一档气泡。
  void dismiss(PetBubbleKind kind) {
    if (kind == PetBubbleKind.report) {
      _reportTimer?.cancel();
      _reportTimer = null;
    }
    state = state.copyWith(
      bubbles: [
        for (final bubble in state.bubbles)
          if (!_isKind(bubble, kind)) bubble,
      ],
    );
  }

  /// 关掉某一个项目的那一条截止气泡。
  ///
  /// 《页面操作流程》第 3 节给截止气泡配了「知道了」，一条对一个项目；
  /// 多个项目同时逼近时各挂一条，不能一键全清。
  void dismissDeadline(String projectId) {
    state = state.copyWith(
      bubbles: [
        for (final bubble in state.bubbles)
          if (!(bubble is DeadlineBubble && bubble.projectId == projectId)) bubble,
      ],
    );
  }

  /// 一次关掉所有气泡。原型用 Esc 全关，截止气泡除此之外没有别的收法。
  void dismissAllBubbles() {
    _reportTimer?.cancel();
    _reportTimer = null;
    state = state.copyWith(bubbles: const []);
  }

  /// 按一下造一组气泡，再按一下收掉：实机测气泡用。
  ///
  /// 真气泡要等真实的截止与项目数据凑齐才出现，实机上不一定碰得到。这里直接造
  /// 两条占位内容，走的是同一条「进状态 → 算高度 → 摆窗口 → 画气泡」的路，
  /// 量的仍是真窗口与真气泡，只是内容不是从库里读的。
  void togglePreviewBubbles() {
    if (state.bubbles.isNotEmpty) {
      dismissAllBubbles();
      return;
    }
    _reportTimer?.cancel();
    state = state.copyWith(
      bubbles: const [
        DeadlineBubble(
          projectId: 'preview',
          headline: '将于 2026年10月31日 截止',
          name: '求职 · 回面试邮件',
          urgent: true,
        ),
        ReportBubble(
          rows: [
            ReportRow(name: '配音练习', detail: '3/7 42% | 昨天'),
            ReportRow(name: '毕设论文', detail: '1/7 14% | 3天前'),
          ],
        ),
      ],
    );
  }

  /// 播报自己会走：15 秒不点就收，原型与 PRD 都这么定。
  void _startReportLinger() {
    final linger = ref.read(petReportLingerProvider);
    _reportTimer?.cancel();
    if (linger == null) return;
    _reportTimer = Timer(linger, () => dismiss(PetBubbleKind.report));
  }

  /// 重新看一眼截止：进了 24 小时或 2 小时窗口就补一条气泡。
  Future<void> refreshDeadlines() async {
    final List<ProjectDigest> digests;
    try {
      digests = await ref.read(projectRepositoryProvider).digests();
    } on Object {
      return;
    }
    _applyDeadline(digests);
  }

  /// 读设置与项目摘要，铺开首屏的气泡。
  Future<void> _load() async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).current();
      _bubblesEnabled = settings.bubbleEnabled;
      // 侧别不跟设置走：使用者 2026-10-26 定下桌宠只出现桌面右缘，左缘那一套
      // 暂时不做。设置里存着的旧值留着不动，等左缘真做回来再用。
      state = state.copyWith(side: PetSide.right, anchorY: settings.anchorY);
      final digests = await ref.read(projectRepositoryProvider).digests();
      _applyReport(digests);
      _applyDeadline(digests);
    } on Object {
      // 库读不出来就只显示形象：桌宠还能拖、还能点，不因为一次读失败就白屏。
    }
  }

  void _applyReport(List<ProjectDigest> digests) {
    if (!_bubblesEnabled || _reportPublished || digests.isEmpty) return;
    _reportPublished = true;
    final now = _now;
    final rows = digests.take(maxReportRows).map((digest) => reportRow(digest, now: now)).toList();
    state = state.copyWith(
      bubbles: [
        ReportBubble(rows: rows),
        ...state.bubbles,
      ],
    );
    _startReportLinger();
  }

  /// 有人还没到期才开轮询。
  ///
  /// 没有截止就一个定时器都不留：挂机一整天不该为了「可能不会有的事」每分钟醒一次。
  void _syncPoll(List<ProjectDigest> digests) {
    final interval = ref.read(petPollIntervalProvider);
    final now = _now;
    final upcoming =
        interval != null && digests.any((digest) => digest.hasDue && digest.dueAt! > now);
    if (upcoming && _pollTimer == null) {
      _pollTimer = Timer.periodic(interval, (_) => unawaited(refreshDeadlines()));
    } else if (!upcoming && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _applyDeadline(List<ProjectDigest> digests) {
    _syncPoll(digests);
    if (!_bubblesEnabled) return;
    final now = _now;
    // 一件一条（《页面操作流程》第 3 节）：同一轮里多个项目同时逼近就一起挂出来。
    final fresh = [
      for (final hint in deadlineHints(digests, now: now))
        if (!_shownDeadlines.contains('${hint.projectId}:${hint.stage.name}')) hint,
    ];
    if (fresh.isEmpty) return;
    for (final hint in fresh) {
      _shownDeadlines.add('${hint.projectId}:${hint.stage.name}');
    }
    final replaced = {for (final hint in fresh) hint.projectId};
    state = state.copyWith(
      bubbles: [
        for (final hint in fresh.reversed)
          DeadlineBubble(
            projectId: hint.projectId,
            headline: dueLabel(hint.dueAt, now: now),
            name: hint.name,
            urgent: hint.urgent,
          ),
        // 一个项目一条：同一项目的新档替换旧的，别的项目的气泡留着不动。
        ...state.bubbles.where(
          (bubble) => bubble is! DeadlineBubble || !replaced.contains(bubble.projectId),
        ),
      ],
    );
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  bool _isKind(PetBubble bubble, PetBubbleKind kind) => switch (kind) {
    PetBubbleKind.deadline => bubble is DeadlineBubble,
    PetBubbleKind.report => bubble is ReportBubble,
  };
}

/// 截止轮询间隔。给 `null` 就不轮询：界面测试不想留一个挂着的定时器。
final petPollIntervalProvider = Provider<Duration?>((ref) => PetNotifier.deadlinePoll);

/// 播报气泡自己收起的时长。给 `null` 就不自动收，同样是给测试用的。
final petReportLingerProvider = Provider<Duration?>((ref) => PetNotifier.reportLinger);

/// 常驻态页面唯一的状态入口。
final petNotifierProvider = NotifierProvider<PetNotifier, PetState>(PetNotifier.new);
