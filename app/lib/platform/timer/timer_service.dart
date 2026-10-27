import 'dart:async';

/// 一次正在进行的计时。
///
/// 暂停的那一刻把已走的并进 [accumulatedMs]、段起点归零，这样「继续」时
/// 只要把起点重新设成当下即可，暂停那段自然不进来。
class RunningTimer {
  const RunningTimer({
    required this.taskId,
    required this.paused,
    required this.accumulatedMs,
    required this.segmentStartedAt,
    this.baseMs = 0,
  });

  /// 起表之前这件事已经攒下的毫秒数。
  ///
  /// 「继续」要接着历史的累计走，时钟得从那一截开始数；但 [TimerService.stop]
  /// 只能把这一轮真正新走的秒数交给调用方，否则库里的秒数会被重复累加。
  final int baseMs;

  /// 正在计时的是哪一件事。
  final String taskId;

  /// 是否处在暂停。
  final bool paused;

  /// 暂停前已累计的毫秒数。
  final int accumulatedMs;

  /// 这一段的起点；暂停时是 0。
  final int segmentStartedAt;
}

/// 走秒、暂停、继续、停止的纯逻辑。
///
/// 只算时间，不碰数据库、不认识 Flutter：写流水与累加秒数由调用方拿
/// [stop] 的返回值去走 `StopTask`。第 4、6 页在 B12、B15 接同一个实例，
/// 所以它挂在全局 Provider 上，面板收起也不停表。
///
/// [now] 可注入，测试里换假时钟推进，不必真等。
class TimerService {
  TimerService({int Function()? now}) : _now = now ?? _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final int Function() _now;
  final StreamController<void> _ticks = StreamController<void>.broadcast();
  Timer? _ticker;
  RunningTimer? _running;

  /// 当前在跑的那一条；没在跑时为 null。
  RunningTimer? get running => _running;

  /// 每秒一次，界面据此重画时钟。开始、暂停、继续时也会立刻推一次。
  Stream<void> get ticks => _ticks.stream;

  bool get isRunning => _running != null;

  /// 这一轮已经走了多少毫秒（不含暂停，但含「继续」时带进来的历史累计）。没在跑时是 0。
  int elapsedMs() {
    final current = _running;
    if (current == null) return 0;
    if (current.paused) return current.accumulatedMs;
    return current.accumulatedMs + (_now() - current.segmentStartedAt);
  }

  /// 开始计时。
  ///
  /// 已经有别的在跑就抛 [StateError]——正常路径上 `StartTask` 会先挡，
  /// 这里再挡一层，让「同一时刻只一条」在用例与服务两处都成立。
  void start(String taskId, {int baseMs = 0}) {
    final current = _running;
    if (current != null) {
      throw StateError('已经在计时：${current.taskId}，不能同时开 $taskId');
    }
    _running = RunningTimer(
      taskId: taskId,
      paused: false,
      accumulatedMs: baseMs,
      segmentStartedAt: _now(),
      baseMs: baseMs,
    );
    _startTicker();
    _notify();
  }

  /// 暂停：把已走的并进累计，停掉走秒。
  void pause() {
    final current = _running;
    if (current == null || current.paused) return;
    // 先取净时长再换状态，否则会把刚清零的段起点算进去。
    final walked = elapsedMs();
    _running = RunningTimer(
      taskId: current.taskId,
      paused: true,
      accumulatedMs: walked,
      segmentStartedAt: 0,
      baseMs: current.baseMs,
    );
    _stopTicker();
    _notify();
  }

  /// 继续：从当下重新起一段，累计照旧带着。
  void resume() {
    final current = _running;
    if (current == null || !current.paused) return;
    _running = RunningTimer(
      taskId: current.taskId,
      paused: false,
      accumulatedMs: current.accumulatedMs,
      segmentStartedAt: _now(),
      baseMs: current.baseMs,
    );
    _startTicker();
    _notify();
  }

  /// 停止并返回这一轮**新走**的净毫秒数，状态清空。没在跑时返回 0。
  ///
  /// 用 base 起来的那一轮，时钟从历史累计开始数，可交回去的只能是新走的那一截，
  /// 否则调用方把这段并进库里，同一段秒数会被算两遍。
  int stop() {
    final current = _running;
    if (current == null) return 0;
    final walked = elapsedMs() - current.baseMs;
    _running = null;
    _stopTicker();
    _notify();
    return walked < 0 ? 0 : walked;
  }

  /// 关掉走秒与流。测试里也要调，否则会留一个悬挂的定时器。
  void dispose() {
    _stopTicker();
    _running = null;
    unawaited(_ticks.close());
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _notify() {
    if (_ticks.isClosed) return;
    _ticks.add(null);
  }
}
