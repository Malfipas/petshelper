import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/model/note.dart';
import '../../domain/model/task_item.dart';
import '../panel/panel_notifier.dart';

/// 独立事项页的状态。
///
/// 只放「列表长什么样」与「哪条展开着」。走秒数字不在这里：它每秒都变，
/// 由面板 Notifier 统一发，页面直接 watch 那边就够，省一套定时器。
class SoloListState {
  const SoloListState({
    this.items = const [],
    this.openId,
    this.flash,
    this.loading = true,
  });

  /// 未完成在前、已完成在后，已完成只留当天做完的。
  final List<TaskItem> items;

  /// 展开着的那条；都在收起时为 null。
  final String? openId;

  /// 「已保存 · 名字」这类一行提示，一两秒后自己消失。
  final String? flash;

  /// 首次取数还没回来。空态要等它变 false 才敢说「还没有独立的事」。
  final bool loading;

  static const Object _keep = Object();

  SoloListState copyWith({
    List<TaskItem>? items,
    Object? openId = _keep,
    Object? flash = _keep,
    bool? loading,
  }) => SoloListState(
    items: items ?? this.items,
    openId: identical(openId, _keep) ? this.openId : openId as String?,
    flash: identical(flash, _keep) ? this.flash : flash as String?,
    loading: loading ?? this.loading,
  );
}

/// 独立事项页的 Notifier。
///
/// 读写都经 Repository 与既有用例，页面只跟它打交道。刷新靠「动手之后拉一次」
/// 加「面板那边计时有变化拉一次」，不做轮询：列表只在有人改它的时候才变。
class SoloListNotifier extends Notifier<SoloListState> {
  SoloListNotifier({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// 相对日期与「当天完成」都按本地日历日算，测试里可注入固定时钟。
  final DateTime Function() _now;

  Timer? _flashTimer;

  @override
  SoloListState build() {
    ref.onDispose(() => _flashTimer?.cancel());
    // 面板里按停止、按完成、换事务，本页都要跟着变：
    // 秒数在停止那一刻才落库，不刷新就还停在旧数字上。
    ref.listen(panelNotifierProvider, (prev, next) {
      final stopped = (prev?.running ?? false) && !next.running;
      final switched = prev?.taskId != next.taskId;
      if (stopped || switched) unawaited(reload());
    });
    // 首次进页面自己拉一遍：列表不在别处预热，这里不发起就一直是空白。
    unawaited(reload());
    return const SoloListState();
  }

  /// 从库里重新拉一遍，排好序放进状态。
  Future<void> reload() async {
    final repo = ref.read(taskRepositoryProvider);
    final rows = await repo.solo();
    // 页面已经退出（容器销毁）时这次读库还会回来，别再碰 ref。
    if (!ref.mounted) return;
    final today = _startOfDay(_now());
    final visible = rows
        .where((task) => !task.done || _sameDay(task.doneAt, today))
        .toList(growable: false);
    final current = ref.read(panelNotifierProvider).taskId;
    final sorted = sortItems(visible, currentId: current);

    // 展开的那条被删了或被完成到别的日期，就顺手收起。
    final openId = state.openId;
    final keepOpen = openId != null && sorted.any((task) => task.id == openId);
    state = state.copyWith(items: sorted, loading: false, openId: keepOpen ? openId : null);
  }

  /// 未完成在前（当前事务最前，其余按创建倒序），已完成按完成时间倒序在后。
  static List<TaskItem> sortItems(List<TaskItem> rows, {String? currentId}) {
    final todo = rows.where((task) => !task.done).toList()
      ..sort((a, b) {
        final aCurrent = a.id == currentId ? 1 : 0;
        final bCurrent = b.id == currentId ? 1 : 0;
        if (aCurrent != bCurrent) return bCurrent - aCurrent;
        return b.createdAt.compareTo(a.createdAt);
      });
    final done = rows.where((task) => task.done).toList()
      ..sort((a, b) => (b.doneAt ?? 0).compareTo(a.doneAt ?? 0));
    return [...todo, ...done];
  }

  /// 新建一条独立事项。名称空白时什么都不做——按钮本来也不该可点。
  Future<void> create({required String name, String description = ''}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await ref
        .read(taskRepositoryProvider)
        .createSolo(
          name: trimmed,
          description: description.trim(),
          nowMs: _now().millisecondsSinceEpoch,
        );
    await reload();
  }

  /// 展开或收起某条详情，同一时刻只留一条。
  Future<void> toggleDetail(String id) async {
    if (state.openId == id) {
      state = state.copyWith(openId: null);
      return;
    }
    state = state.copyWith(openId: id);
  }

  /// 壳里按 Esc 先问这一句：有展开的就收起来，返回 true 表示「这一下吃掉了」。
  bool collapseDetail() {
    if (state.openId == null) return false;
    state = state.copyWith(openId: null);
    return true;
  }

  /// 读完随手记，给详情输入框灌初值。
  Future<String> noteOf(String id) => ref.read(noteRepositoryProvider).textOf(NoteOwner.task, id);

  /// 勾上或退回完成。正在跑的这条先结算，秒数不能丢。
  ///
  /// 退回来时还要叫面板重读一遍：面板停在完成态就不会自己变，不刷新的话
  /// 小任务窗口还在说「这件事已标记为完成」，也摆不出累计时长与「重置」「继续」。
  Future<void> toggleDone(String id) async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.byId(id);
    if (task == null) return;
    await _stopIfRunning(id);
    await ref
        .read(finishTaskProvider)
        .call(taskId: id, nowMs: _now().millisecondsSinceEpoch, done: !task.done);
    if (ref.read(panelNotifierProvider).taskId == id) {
      await ref.read(panelNotifierProvider.notifier).refresh();
    }
    await reload();
  }

  /// 点「开始」：这一件成为面板的当前事务并立刻开表。
  ///
  /// 返回 false 表示没开成（已经完成了、库里没了、或另一条正在跑）。
  /// 导航不在这里做——页面拿到 true 之后自己收主界面。
  Future<bool> start(String id) async {
    final task = await ref.read(taskRepositoryProvider).byId(id);
    if (task == null || task.done) return false;
    final panel = ref.read(panelNotifierProvider.notifier);
    await panel.setCurrentTask(id);
    await panel.start();
    return ref.read(panelNotifierProvider).running && ref.read(panelNotifierProvider).taskId == id;
  }

  /// 删掉一条：流水由 Repository 一并清，随手记另删。
  ///
  /// 小任务窗口正挂着这一条时，删完要让它换一件或回到空态——不然面板还在显示
  /// 一件已经不存在的待办（使用者 2026-10-26 的第 6 条）。
  Future<void> remove(String id) async {
    await _stopIfRunning(id);
    await ref.read(taskRepositoryProvider).delete(id);
    await ref.read(noteRepositoryProvider).deleteFor(NoteOwner.task, id);
    if (state.openId == id) state = state.copyWith(openId: null);
    await reload();
    final panel = ref.read(panelNotifierProvider.notifier);
    if (ref.read(panelNotifierProvider).taskId == id || ref.read(panelNotifierProvider).isEmpty) {
      await panel.refresh();
    }
  }

  /// 输入停下 600 毫秒后的兜底保存：只写名称与说明，不收起详情，也不弹提示。
  ///
  /// 随手记故意不在这里写——使用者 2026-10-25 要求编辑页的随手记只在点「保存」
  /// 时落盘，免得边想边写就被存进去半截话。小任务窗口那一格仍是失焦即存。
  Future<void> autoSave({
    required String id,
    required String name,
    required String description,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.byId(id);
    if (task == null) return;
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && trimmed != task.name) {
      await repo.rename(id, trimmed);
    }
    if (description.trim() != task.description) {
      await repo.setDescription(id, description.trim());
    }
  }

  /// 点「保存」：立刻写回，名称留空回退原名，写完收起详情并给一句提示。
  Future<void> saveNow({
    required String id,
    required String name,
    required String description,
    required String note,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.byId(id);
    if (task == null) return;
    final trimmed = name.trim();
    final finalName = trimmed.isEmpty ? task.name : trimmed;
    await repo.rename(id, finalName);
    await repo.setDescription(id, description.trim());
    await ref
        .read(noteRepositoryProvider)
        .save(NoteOwner.task, id, note, _now().millisecondsSinceEpoch);
    state = state.copyWith(openId: null);
    _flash('已保存 · $finalName');
    await reload();
  }

  void _flash(String text) {
    state = state.copyWith(flash: text);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (state.flash == text) state = state.copyWith(flash: null);
    });
  }

  /// 这一条要被动改（勾完成、删除）时先把表停掉。
  ///
  /// 只结算这一轮，不替调用方标记完成——完成与否由这里决定，面板抢着写会把
  /// 「退回未完成」又翻成完成。
  Future<void> _stopIfRunning(String id) async {
    final panel = ref.read(panelNotifierProvider);
    if (panel.running && panel.taskId == id) {
      await ref.read(panelNotifierProvider.notifier).settleRunning();
    }
  }

  static DateTime _startOfDay(DateTime now) => DateTime(now.year, now.month, now.day);

  static bool _sameDay(int? atMs, DateTime day) {
    if (atMs == null) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(atMs);
    return at.year == day.year && at.month == day.month && at.day == day.day;
  }
}

/// 独立事项页的状态入口。
final soloListProvider = NotifierProvider<SoloListNotifier, SoloListState>(SoloListNotifier.new);

/// 元信息里的相对时间：刚刚 / N 分钟前 / N 小时前 / 昨天 / 前天 / N 天前。
///
/// 使用者 2026-10-25 定的口径：一分钟以内说「刚刚」，一小时内按分钟，
/// 当天再往后按小时，跨过今天就按日历日差说「昨天」「前天」「N天前」。
/// 按本地日历日算而不按 24 小时——23:50 建、00:10 看，说「20分钟前」，
/// 再过一小时就成了「昨天」。
String relativeDay(int createdAtMs, DateTime now) {
  final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final diff = now.difference(created);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(created.year, created.month, created.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return '${diff.inHours}小时前';
  if (days == 1) return '昨天';
  if (days == 2) return '前天';
  if (days < 7) return '$days天前';
  if (days < 14) return '一周前';
  if (days < 30) return '${days ~/ 7} 周前';
  final months = days ~/ 30;
  // 跟「一周前」同一个口气：满一个月就说「一个月前」，不说「1 个月前」。
  return months <= 1 ? '一个月前' : '$months 个月前';
}

/// 累计时长的文字，精确到秒：不足一分钟写「N 秒」，够一分钟写「N 分 N 秒」。
///
/// 使用者 2026-10-26 要求编辑页的累计时间精确到秒：只写分钟的话，刚计时几十秒的
/// 条目一直显示 0 分钟，看不出表动过。
String durationText(int seconds) {
  final safe = seconds <= 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final rest = safe % 60;
  return minutes == 0 ? '$rest 秒' : '$minutes 分 $rest 秒';
}

/// 「N 分钟」的 N：四舍五入到分钟，一秒都还没计过就是 0。
///
/// 使用者 2026-10-25 把旧口径的「最少 1 分钟」改成「没计过就是 0 分钟」：
/// 刚建好的事项写着「累计 1 分钟」会让人以为已经计过时了。
int minutesOf(int seconds) {
  if (seconds <= 0) return 0;
  final rounded = (seconds / 60).round();
  return rounded < 1 ? 1 : rounded;
}
