import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/chat_client.dart';
import '../../ai/prompts.dart';
import '../../app/key_configured.dart';
import '../../app/providers.dart';
import '../../domain/model/note.dart';
import '../../domain/model/project_digest.dart';
import '../../domain/model/step.dart';
import '../../domain/model/task_item.dart';
import '../../domain/usecase/start_task.dart';

/// 面板当前摆的是哪一种。
///
/// 三种形态的字段并不一样：项目待办要流程轴与步数，独立事项只有名字，
/// 空态什么都没有。用一个枚举分开，界面按它选分支，不用一堆可空字段互相猜。
enum PanelKind { empty, project, solo }

/// 问一问的一条回答。B09 只留结构，等 B22 接上模型才开始有内容。
class PanelAnswer {
  const PanelAnswer({required this.question, required this.text});

  /// 用户问的那句。
  final String question;

  /// 助手的回答。
  final String text;
}

/// 面板的状态。
///
/// 只装显示要用的东西：当前事务是哪一件、走到第几步、随手记草稿写到哪。
/// 草稿与已落盘值分开记，是为了「没改就不写库」——每失焦一次都写一遍
/// 会让 `notes` 的 `updatedAt` 无意义地跳。
class PanelState {
  const PanelState({
    this.kind = PanelKind.empty,
    this.taskId,
    this.projectId,
    this.title = '',
    this.stepIndex = -1,
    this.totalSteps = 0,
    this.stepName,
    this.stepNames = const [],
    this.dueLabel,
    this.isDone = false,
    this.running = false,
    this.paused = false,
    this.elapsedMs = 0,
    this.scratch = '',
    this.savedScratch = '',
    this.answers = const [],
    this.aiReady = false,
  });

  final PanelKind kind;

  /// 当前事务的 id；空态为 null。
  final String? taskId;

  /// 这一件属于哪个项目；独立事项与空态为 null。
  ///
  /// 只给「点项目名落到第 6 页」用，取数不用它——取数认 `taskId`。
  final String? projectId;

  /// 项目名（形态 A）或事项名（形态 B）。
  final String title;

  /// 项目当前走在第几步，0 起；-1 表示还没开始。取自 `Project.currentStep`。
  final int stepIndex;

  /// 步骤总数。0 表示这件事没拆步骤，不画流程轴。
  final int totalSteps;

  /// 当前走在哪一步的名字。
  final String? stepName;

  /// 按顺序排好的步名，给流程轴每一段做悬停提示（原型 `buildTrack` 里的 `tip`）。
  final List<String> stepNames;

  /// 第一行右侧那一截截止时间，形如「2026年10月31日 截止」。
  ///
  /// 《页面操作流程》第 4 节：项目事项取项目的截止日期，没填就整截不出现；
  /// 独立事项本来没有这个字段，恒为 null。
  final String? dueLabel;

  /// 这一件是否已经标记完成。完成后动作区换成一句「这件事已标记为完成」，
  /// 而不是像原先那样立刻跳去下一件——原型 `renderAction` 就是这么画的。
  final bool isDone;

  /// 这一件正在计时。计时条只在它为真时出现。
  final bool running;

  /// 计时中但按了暂停。
  final bool paused;

  /// 这一轮已走的毫秒数，用来画时钟。走秒期间每秒更新一次，但不写库。
  final int elapsedMs;

  /// 随手记草稿，可能还没落盘。
  final String scratch;

  /// 上次落盘时的文本，用来判断草稿有没有动过。
  final String savedScratch;

  final List<PanelAnswer> answers;

  /// AI 是否已接通。B09 恒为 false。
  final bool aiReady;

  bool get isEmpty => kind == PanelKind.empty;

  bool get hasTrack => totalSteps > 0;

  /// 当前步序号，从 1 起，封顶到总步数；还没开始或没步骤时为 0。
  ///
  /// 流程轴亮前这么多段——原型 `for(i=0;i<t.current;i++)` 里 `t.current` 就是它。
  int get currentStep {
    if (totalSteps == 0) return 0;
    if (stepIndex < 0) return 0;
    final value = stepIndex + 1;
    return value > totalSteps ? totalSteps : value;
  }

  /// 第三行那一句。《页面操作流程》第 4 节定死格式「共7步·第3步·做初稿」，
  /// 步名缺失时只写前两截。
  String get metaLabel {
    final head = '共$totalSteps步';
    if (currentStep == 0) return head;
    final name = stepName;
    return name == null ? '$head·第$currentStep步' : '$head·第$currentStep步·$name';
  }

  /// 时钟文字 `HH:MM:SS`。《页面操作流程》第 4 节要求「以 00:00:00 的格式呈现」，
  /// 小时不限一位，分与秒各补到两位。
  String get clockLabel {
    final total = elapsedMs ~/ 1000;
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  PanelState copyWith({
    PanelKind? kind,
    String? taskId,
    String? projectId,
    String? title,
    int? stepIndex,
    int? totalSteps,
    String? stepName,
    List<String>? stepNames,
    String? dueLabel,
    bool? isDone,
    bool? running,
    bool? paused,
    int? elapsedMs,
    String? scratch,
    String? savedScratch,
    List<PanelAnswer>? answers,
    bool? aiReady,
  }) {
    return PanelState(
      kind: kind ?? this.kind,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      stepIndex: stepIndex ?? this.stepIndex,
      totalSteps: totalSteps ?? this.totalSteps,
      stepName: stepName ?? this.stepName,
      stepNames: stepNames ?? this.stepNames,
      dueLabel: dueLabel ?? this.dueLabel,
      isDone: isDone ?? this.isDone,
      running: running ?? this.running,
      paused: paused ?? this.paused,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      scratch: scratch ?? this.scratch,
      savedScratch: savedScratch ?? this.savedScratch,
      answers: answers ?? this.answers,
      aiReady: aiReady ?? this.aiReady,
    );
  }
}

/// 悬停小面板的状态入口。
///
/// 管三件事：现在摆哪一件事、随手记写到哪、勾完成之后换到哪一件。
/// 不认识的：窗口尺寸（`PetFrame` 管）、悬停计时（`PetNotifier` 管）、
/// 写库细节（Repository 管）。
class PanelNotifier extends Notifier<PanelState> {
  /// 显式指定的当前事务。空表示交给 [refresh] 自己挑。
  String? _preferredTaskId;

  /// AI 是否接通，跟着设置页的 key 走。
  ///
  /// 原先这里写死 false，设置页存了 key 面板还写着「未配置」——B21 实机撞上的
  /// 就是这一条。改成读全站开关，设置页一存这边立刻跟着变。
  bool get _aiReady => ref.read(keyConfiguredProvider);

  /// 走秒订阅。服务每秒推一次，把净时长搬进状态里。
  StreamSubscription<void>? _tickSub;

  @override
  PanelState build() {
    _tickSub?.cancel();
    _tickSub = ref.read(timerServiceProvider).ticks.listen((_) => _syncTimer());
    ref.onDispose(() {
      _tickSub?.cancel();
      _tickSub = null;
    });
    unawaited(refresh());
    return const PanelState();
  }

  /// 重新挑一次当前事务并读它的随手记。
  ///
  /// 挑选顺序：显式指定的那件（完成了也留着，动作区要显示完成态）→ 最近推进过的
  /// 项目里第一条未完成待办 → 第一条未完成独立事项 → 空态。读库失败也落到空态：
  /// 面板空着比白屏好。
  Future<void> refresh() async {
    try {
      final digests = _sortedDigests(await ref.read(projectRepositoryProvider).digests());
      final tasks = ref.read(taskRepositoryProvider);

      final preferred = _preferredTaskId;
      if (preferred != null) {
        final item = await tasks.byId(preferred);
        if (item != null) {
          await _apply(item, digests);
          return;
        }
        _preferredTaskId = null;
      }

      for (final digest in digests) {
        final items = await tasks.byProject(digest.projectId);
        final open = _firstOpen(items);
        if (open != null) {
          _preferredTaskId = open.id;
          await _apply(open, digests);
          return;
        }
      }

      final open = _firstOpen(await tasks.solo());
      if (open != null) {
        _preferredTaskId = open.id;
        await _apply(open, digests);
        return;
      }

      _preferredTaskId = null;
      if (ref.mounted) state = _withoutTask();
    } on Object {
      // 容器已经销毁（页面退出、测试收尾）时读库还会回来，此时不能再写状态。
      if (ref.mounted) state = _withoutTask();
    }
  }

  /// 标记某个项目：把它首个未完成步骤里首个未完成的事项摆到面板上，不开始计时。
  ///
  /// 《页面操作流程》第 6 节：「点击后该项目首个未完成步骤的首个未完成事项进入小任务
  /// 窗口」。项目里一件未完成的事项都没有时返回 false，界面什么都不做。
  Future<bool> markProject(String projectId) async {
    final bundle = await ref.read(projectRepositoryProvider).load(projectId);
    final ordered = [...bundle.steps]..sort((a, b) => a.index.compareTo(b.index));
    final items = await ref.read(taskRepositoryProvider).byProject(projectId);
    for (final step in ordered) {
      final open = _firstOpen([
        for (final item in items)
          if (item.stepId == step.id) item,
      ]);
      if (open == null) continue;
      await setCurrentTask(open.id);
      return ref.mounted && !state.isEmpty;
    }
    return false;
  }

  /// 换成别的事务。切之前先把上一件的随手记落盘，切回来才读得到。
  Future<void> setCurrentTask(String taskId) async {
    if (taskId == _preferredTaskId) return;
    await commitScratch();
    _preferredTaskId = taskId;
    await refresh();
  }

  /// 随手记改了字：只动草稿，不写库。
  void draftScratch(String text) {
    state = state.copyWith(scratch: text);
  }

  /// 把草稿落盘。没改过就不写，免得 `updatedAt` 白跳一次。
  Future<void> commitScratch() async {
    final id = state.taskId;
    if (id == null) return;
    if (state.scratch == state.savedScratch) return;
    final text = state.scratch;
    state = state.copyWith(savedScratch: text);
    try {
      await ref.read(noteRepositoryProvider).save(NoteOwner.task, id, text, _now);
    } on Object {
      // 写失败只影响下次能不能读回，不拦着用户继续写。
    }
  }

  /// 开始计时。[baseMs] 不为 0 表示从历史累计接着走——「继续」按钮走这条。
  ///
  /// 先过 `StartTask`：另一条在跑、这件已完成、这件已被删，三种都只返回结果，
  /// 界面不动——原型也没有提示，只是不响应。
  Future<void> start({int baseMs = 0}) async {
    final id = state.taskId;
    if (id == null || state.running) return;
    final service = ref.read(timerServiceProvider);
    try {
      final outcome = await ref.read(startTaskProvider)(
        taskId: id,
        runningTaskId: service.running?.taskId,
        nowMs: _now,
      );
      if (outcome is! StartTaskStarted) return;
      service.start(id, baseMs: baseMs);
      state = state.copyWith(running: true, paused: false, elapsedMs: baseMs);
    } on Object {
      // 库异常时保持原样，面板仍显示「开始」。
    }
  }

  /// 暂停：表停在已经走过的地方，不结算、不标完成，等「继续」接着走。
  ///
  /// 使用者 2026-10-26 把口径改回来了：暂停就是暂停（那时独立事项页那一行的勾选框
  /// 变黄，与设计稿一致），「停止」才是收尾——它结算流水、把事项标成完成。
  Future<void> pause() async {
    final id = state.taskId;
    if (id == null) return;
    final service = ref.read(timerServiceProvider);
    final running = service.running;
    if (running == null || running.taskId != id || running.paused) return;
    service.pause();
    state = state.copyWith(paused: true, elapsedMs: service.elapsedMs());
  }

  /// 继续计时：接着这件事已经攒下的时长往下走，时钟不从 00:00 重来。
  Future<void> continueFromSpent() => start(baseMs: state.elapsedMs);

  /// 重置计时：累计与流水一起清零，时钟回到 00:00。
  Future<void> resetSpent() async {
    final id = state.taskId;
    if (id == null) return;
    if (ref.read(timerServiceProvider).running?.taskId == id) return;
    try {
      await ref.read(taskRepositoryProvider).resetSpent(id);
    } on Object {
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(elapsedMs: 0);
  }

  /// 继续：从暂停点接着走，已走的时长不丢。
  void resume() {
    final id = state.taskId;
    if (id == null) return;
    final service = ref.read(timerServiceProvider);
    if (service.running?.taskId != id) return;
    service.resume();
    state = state.copyWith(paused: false, elapsedMs: service.elapsedMs());
  }

  /// 停止：这一轮落成流水，事项标为完成，面板不再挂着它。
  ///
  /// 使用者 2026-10-26 定的收尾口径：停止＝做完了。项目事项停完接同一项目的下一条
  /// 未完成待办，独立事项停完回空态（原话是「恢复为无事项状态」）。
  ///
  /// 净时长小于一秒不写库——手抖点两下不该在记录页留一条 0 秒的流水。
  Future<void> stop() async {
    final id = state.taskId;
    if (id == null) return;
    final service = ref.read(timerServiceProvider);
    final walked = service.running?.taskId == id ? service.stop() : 0;
    state = state.copyWith(running: false, paused: false, elapsedMs: 0);
    if (walked > 0) await _settle(id, walked);
    await commitScratch();
    try {
      await ref.read(finishTaskProvider)(taskId: id, nowMs: _now);
    } on Object {
      // 用例自己用返回类型表达失败，这里只为库异常兜底。
    }
    final item = await ref.read(taskRepositoryProvider).byId(id);
    if (!ref.mounted) return;
    final projectId = item?.projectId;
    if (projectId != null && await _advanceTo(projectId)) return;
    if (projectId == null && await _advanceSolo(id)) return;
    _preferredTaskId = null;
    if (ref.mounted) state = _withoutTask();
  }

  /// 停表并结算这一轮，但不标记完成。
  ///
  /// 事项页勾完成、删事项之前走这条：完成与否由调用方决定，面板不抢着写一次完成。
  Future<void> settleRunning() async {
    final id = state.taskId;
    if (id == null) return;
    final service = ref.read(timerServiceProvider);
    if (service.running?.taskId != id) return;
    final walked = service.stop();
    state = state.copyWith(running: false, paused: false, elapsedMs: 0);
    await _settle(id, walked);
    final task = await ref.read(taskRepositoryProvider).byId(id);
    if (!ref.mounted) return;
    // 停完把累计摆出来：「重置」「继续」从这里接着走。
    state = state.copyWith(elapsedMs: (task?.spentSec ?? 0) * 1000);
  }

  /// 勾完成：写进度史、随手记跟过去。
  ///
  /// 独立事项停在完成态——原型 `renderAction` 里完成之后是 `.donenote`
  /// 「这件事已标记为完成」。项目事项不一样：使用者 2026-10-26 要求「项目事项完成后
  /// 显示下一步的项目事项，直到所有项目事项完成」，所以项目这条走 [_advanceTo]。
  Future<void> finish() async {
    final id = state.taskId;
    if (id == null) return;
    await commitScratch();
    // 跑着的时候先结算这一段再标记完成。原型 markItemDone 只清了计时、
    // 没落流水，是漏写；不补的话这一次就白计了。
    final service = ref.read(timerServiceProvider);
    if (service.running?.taskId == id) {
      final walked = service.stop();
      state = state.copyWith(running: false, paused: false, elapsedMs: 0);
      await _settle(id, walked);
    }
    try {
      await ref.read(finishTaskProvider)(taskId: id, nowMs: _now);
    } on Object {
      // 用例自己用返回类型表达失败，这里只为库异常兜底。
    }
    final item = await ref.read(taskRepositoryProvider).byId(id);
    if (!ref.mounted) return;
    final projectId = item?.projectId;
    if (projectId != null && await _advanceTo(projectId)) return;
    if (projectId == null && await _advanceSolo(id)) return;
    _preferredTaskId = null;
    if (ref.mounted) state = _withoutTask();
  }

  /// 换到下一条未完成的独立事项；没有就返回 false。
  ///
  /// 《页面操作流程》第 4 节类型 2 的收尾：「若有下一个独立事项则切换，否则恢复无事项
  /// 状态」。上一版把独立事项停在「已完成」的原地，新版不再停。
  Future<bool> _advanceSolo(String currentId) async {
    final items = await ref.read(taskRepositoryProvider).solo();
    final next = _firstOpen(items.where((item) => item.id != currentId).toList());
    if (next == null) return false;
    _preferredTaskId = next.id;
    await refresh();
    return ref.mounted && !state.isEmpty;
  }

  /// 换到同一项目里下一条未完成的待办；没有就返回 false，由调用方决定停在哪。
  Future<bool> _advanceTo(String projectId) async {
    final items = await ref.read(taskRepositoryProvider).byProject(projectId);
    final next = _firstOpen(items);
    if (next == null) return false;
    _preferredTaskId = next.id;
    await refresh();
    return ref.mounted && !state.isEmpty;
  }

  /// 问一句。AI 没接通时什么都不做——界面那一层已经把输入框设成只读了。
  ///
  /// 先把空答案推进列表让气泡立刻出现，回来再填字：等模型那几秒里界面不能
  /// 没有任何动静，否则人会以为按钮没生效、连点三次。
  void ask(String text) {
    final question = text.trim();
    if (!_aiReady || question.isEmpty) return;
    final pending = PanelAnswer(question: question, text: '');
    state = state.copyWith(answers: [...state.answers, pending]);
    unawaited(_answer(question, pending));
  }

  /// 真去问，回来把那条空答案换掉。
  ///
  /// 列表里找不到那一条（期间勾了完成、换了项目）就不写——按问题文字找会
  /// 误伤同一个问题的第二次提问，所以认对象本身。
  Future<void> _answer(String question, PanelAnswer pending) async {
    final outcome = await ref
        .read(chatClientProvider)
        .complete(system: askSystemPrompt, user: question);
    if (!ref.mounted) return;
    final text = switch (outcome) {
      ChatReply(:final text) => text.trim(),
      ChatNoKey() => '还没配 API key，去设置页填一个',
      ChatError(:final reason) => reason,
    };
    final answers = [...state.answers];
    final index = answers.indexWhere((item) => identical(item, pending));
    if (index < 0) return;
    answers[index] = PanelAnswer(question: question, text: text);
    state = state.copyWith(answers: answers);
  }

  Future<void> _apply(TaskItem item, List<ProjectDigest> digests) async {
    final scratch = await _readScratch(item.id);
    if (!ref.mounted) return;
    // 问答记录跟着面板走，不跟着事务走：读库回来晚一点时（面板刚打开就问了一句），
    // 这里若整块换新状态会把刚推上去的空气泡抹掉，答案回来也就无处可填。
    final answers = state.answers;
    // 计时状态从服务里回填：面板重开时若这一件正在跑，直接显示计时条。
    final service = ref.read(timerServiceProvider);
    final current = service.running;
    final mine = current != null && current.taskId == item.id;
    final isPaused = mine && current.paused;
    // 没在跑时把这一件已经攒下的时长摆出来：时钟停在累计值上，「重置」「继续」
    // 才有意义。收起面板再打开也一样——读的是库里的 `spentSec`。
    final walked = mine ? service.elapsedMs() : item.spentSec * 1000;
    final projectId = item.projectId;
    if (projectId == null) {
      state = PanelState(
        kind: PanelKind.solo,
        taskId: item.id,
        title: item.name,
        isDone: item.done,
        running: mine,
        paused: isPaused,
        elapsedMs: walked,
        scratch: scratch,
        savedScratch: scratch,
        answers: answers,
        aiReady: _aiReady,
      );
      return;
    }
    // 流程轴要知道「第几步」这个 0 起索引，`ProjectDigest` 只给步名，
    // 所以这里再读一次项目本身；项目数据很小，比给摘要加字段更省事。
    final bundle = await ref.read(projectRepositoryProvider).load(projectId);
    final project = bundle.project;
    if (project == null) {
      state = PanelState(
        kind: PanelKind.solo,
        taskId: item.id,
        title: item.name,
        isDone: item.done,
        running: mine,
        paused: isPaused,
        elapsedMs: walked,
        scratch: scratch,
        savedScratch: scratch,
        answers: answers,
        aiReady: _aiReady,
      );
      return;
    }
    final ordered = [...bundle.steps]..sort((a, b) => a.index.compareTo(b.index));
    state = PanelState(
      kind: PanelKind.project,
      taskId: item.id,
      projectId: project.id,
      title: project.name,
      stepIndex: project.currentStep,
      totalSteps: ordered.length,
      stepName: _stepNameAt(ordered, project.currentStep),
      stepNames: [for (final step in ordered) step.name],
      dueLabel: _dueLabelOf(project.dueAt),
      isDone: item.done,
      running: mine,
      paused: isPaused,
      elapsedMs: walked,
      scratch: scratch,
      savedScratch: scratch,
      answers: answers,
      aiReady: _aiReady,
    );
  }

  /// 空态：没有摆着的事务，但问答记录留着。
  PanelState _withoutTask() => PanelState(answers: state.answers);

  /// 把服务里的净时长搬进状态。tick 每秒一次，只动内存，不碰库。
  ///
  /// 跑的不是这一件时不动 [PanelState.elapsedMs]：那一格这时摆的是这一件
  /// 已经攒下的时长，「重置」「继续」都靠它，清成 0 会让按钮凭空消失。
  void _syncTimer() {
    final service = ref.read(timerServiceProvider);
    final current = service.running;
    final mine = current != null && current.taskId == state.taskId;
    state = state.copyWith(
      running: mine,
      paused: mine && current.paused,
      elapsedMs: mine ? service.elapsedMs() : state.elapsedMs,
    );
  }

  /// 把这一轮落成流水并累加到事项上。
  ///
  /// `StopTask` 用 `endedAt - startedAt` 算秒数，所以起点传 `now - 净毫秒`：
  /// 暂停那段就不会混进去，也不必改用例。
  Future<void> _settle(String taskId, int walkedMs) async {
    if (walkedMs < 1000) return;
    try {
      await ref.read(stopTaskProvider)(taskId: taskId, startedAt: _now - walkedMs, endedAt: _now);
    } on Object {
      // 用例用返回类型表达失败；这里只为库异常兜底，界面照常复位。
    }
  }

  String? _stepNameAt(List<Step> steps, int index) {
    if (index < 0) return null;
    for (final step in steps) {
      if (step.index == index) return step.name;
    }
    return null;
  }

  Future<String> _readScratch(String taskId) async {
    try {
      return await ref.read(noteRepositoryProvider).textOf(NoteOwner.task, taskId);
    } on Object {
      return '';
    }
  }

  /// 最近推进过的排前面，从没推进过的排最后。
  List<ProjectDigest> _sortedDigests(List<ProjectDigest> digests) {
    final sorted = [...digests];
    sorted.sort((a, b) {
      final left = a.lastAdvancedAt;
      final right = b.lastAdvancedAt;
      if (left == right) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return sorted;
  }

  /// 截止日期写成《页面操作流程》第 4 节的样式：「2026年10月31日 截止」。
  static String? _dueLabelOf(int? dueAt) {
    if (dueAt == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(dueAt);
    return '${at.year}年${at.month}月${at.day}日 截止';
  }

  TaskItem? _firstOpen(List<TaskItem> items) {
    for (final item in items) {
      if (!item.done) return item;
    }
    return null;
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;
}

/// 悬停小面板唯一的状态入口。
final panelNotifierProvider = NotifierProvider<PanelNotifier, PanelState>(PanelNotifier.new);
