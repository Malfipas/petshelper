# B10 计时服务与计时条 · 设计

## 概述

计时拆成两层：`platform/timer/timer_service.dart` 只算时间——走秒、暂停、继续、停止、每秒发一次 tick，不碰数据库也不认识 Flutter；`PanelNotifier` 拿它的净时长去调既有的 `StartTask` / `StopTask`，再把运行态并进 `PanelState` 供界面画。这样第 4、6 页在 B12、B15 接同样的服务就行，不必各自数一遍秒。

服务挂在 `ProviderScope`（`timerServiceProvider`），不在 `PanelPage` 里创建：面板收起、Esc、展开主界面都不该停表。

## 技术方案

### 计时服务

```dart
/// 一次正在进行的计时。暂停的那一刻把已走的并进 accumulatedMs，段起点归零。
class RunningTimer {
  const RunningTimer({
    required this.taskId,
    required this.paused,
    required this.accumulatedMs,
    required this.segmentStartedAt,
  });

  final String taskId;
  final bool paused;
  final int accumulatedMs;
  final int segmentStartedAt;
}

class TimerService {
  TimerService({int Function()? now});

  RunningTimer? get running;
  Stream<void> get ticks;          // 每秒一次，界面据此重建时钟
  int elapsedMs();                 // 净已走毫秒，没有在跑时是 0
  void start(String taskId);       // 已有别的在跑就抛 StateError
  void pause();
  void resume();
  int stop();                      // 返回净毫秒并清空状态
  void dispose();
}
```

- `elapsedMs = accumulatedMs + (paused ? 0 : now - segmentStartedAt)`，与原型 `elapsedMs(s)` 同式。
- tick 用 `Timer.periodic(1s)`，只在开始与继续时开，暂停与停止时关；每次状态变化（开始、暂停、继续）立刻往 `ticks` 推一次，界面不用等下一秒。
- `stop()` 返回净毫秒。落库由调用方做：`StopTask` 需要 `startedAt`/`endedAt`，传 `startedAt = now - netMs`、`endedAt = now`，`endedAt - startedAt` 正好是净时长，暂停那段不会混进去，也不必改用例。
- `start` 时若已有别的在跑，抛 `StateError`——正常路径上 `StartTask(runningTaskId:)` 已经挡住，这里是防呆，让「同一时刻只一条」在用例与服务两层都成立。

### 面板状态

`PanelState` 增三个字段：

```dart
final bool running;    // 这一件正在计时
final bool paused;     // 计时中但按了暂停
final int elapsedMs;   // 已走毫秒，用于画时钟
```

- `clockLabel`：`mm:ss`，分钟不封顶（`padLeft(2,'0')`），与原型 `fmt` 一致。
- `_apply` 里按 `service.running?.taskId == item.id` 回填 `running`/`paused`/`elapsedMs`，所以重开面板时若这件正在跑就直接显示计时条（AC-7）。

### 动作链

```text
开始   → StartTask(taskId, runningTaskId: service.running?.taskId, nowMs)
          Started           → service.start(id)，state.running = true
          Busy/Done/Missing → 什么都不做
暂停   → service.pause()，state.paused = true
继续   → service.resume()，state.paused = false
停止   → ms = service.stop()
          ms >= 1000 → StopTask(taskId, startedAt: now-ms, endedAt: now)
          复位 running / paused / elapsedMs
完成   → 若在跑：先按上面「停止」结算，再 FinishTask，最后 state.isDone = true
```

`PanelNotifier.build()` 里订阅 `service.ticks`，每次把 `elapsedMs` 写进状态；`ref.onDispose` 取消订阅（服务本身由 provider 关）。

### 界面

```text
动作区（未完成、未计时）
├─ 开始（100% × 44，主色）
└─ 标记完成（12 号二档墨）

动作区（计时中）  ← 原型 .timerbar
└─ Row(space-between, gap 10, 上边距 12)
   ├─ 时钟 mm:ss（21 / 行高 1 / 字距 .5 / tabularFigures；暂停时 ink2）
   └─ Row(gap 8)
      ├─ 暂停/继续（44 × min38，白底，边 line，圆角 10，图标 15）
      └─ 停止（44 × min38，底 #d94a3d，白字，图标 14）

动作区（已完成）
└─ 「这件事已标记为完成」（.donenote）
```

图标用 Material 的 `pause_rounded` / `play_arrow_rounded` / `stop_rounded`：原型是内联 SVG（两条竖杠、三角形、圆角方块），形状一致；为三个图标引 SVG 依赖不划算，记偏差。

### 数值对照

| 项 | 原型 | 实现 |
| --- | --- | --- |
| 计时条 | `.timerbar{display:flex;justify-content:space-between;gap:10px;margin-top:12px}` | Row + spaceBetween + 10 + 上 12 |
| 时钟 | `.clock{font-size:21px;line-height:1;letter-spacing:.5px;font-variant-numeric:tabular-nums}` | 21 / 1 / 0.5 / tabularFigures |
| 按钮组 | `.timerbar .acts{gap:8px}` | 8 |
| 图标按钮 | `width:44px;min-height:38px;padding:0;background:#fff;border:1px solid var(--line);border-radius:10px` | 44 × 38、白底、边线、圆角 10 |
| 停止键 | `.stop{background:#d94a3d;border-color:#d94a3d;color:#fff}` | `AppTheme.danger` + 白字 |
| 暂停时钟 | `.timerbar.paused .clock{color:var(--ink2)}` | `AppTheme.ink2` |
| 暂停图标 / 停止图标 | 15 / 14 | 15 / 14 |
| 按钮悬停 | `.timerbar button:hover{border-color:var(--accent);color:var(--accent)}`、`.stop:hover{background:#c8402f}` | 悬停时边与图标转 `AppTheme.primary`；停止键底色与边压深到 `#c8402f`，图标保持白 |

## 文件结构

```text
app/lib/platform/timer/
└── timer_service.dart      # RunningTimer + TimerService，纯 Dart，注入 now

app/lib/app/providers.dart  # 增 timerServiceProvider（Provider + onDispose）

app/lib/features/panel/
├── panel_notifier.dart     # 加 running/paused/elapsedMs、clockLabel、start/pause/resume/stop、ticks 订阅
└── panel_page.dart         # 动作区三态 + _TimerBar

app/test/platform/timer/
└── timer_service_test.dart # 假时钟 + FakeAsync

app/test/features/panel/
├── panel_notifier_test.dart # 开始、走秒不落库、停止落库、忙时拒绝、跑着完成
└── panel_page_test.dart     # 计时条、暂停态、已完成无计时条
```

## 边界

- **不足一秒**：`stop()` 返回小于 1000 毫秒时不调 `StopTask`，界面照样复位——手抖点两下不该留下 0 秒记录。
- **当前那件被删**：`StopTask` 返回 `NotFound`，界面复位，不弹错。
- **切到别的事务时正在跑**：不自动停表也不自动换计时条，只按 `service.running.taskId` 判断；只有回到那一件才显示计时条。原型每条任务各有一份计时状态，行为一致。
- **标记完成时正在跑**：先结算再进完成态（FR-05）。
- **长时间跑**：分钟超过 99 显示三位（`100:00`）；原型 `slice(-2)` 会截成两位，那是写法漏洞，不照搬。

## 测试策略

- `timer_service_test`：假时钟 + `FakeAsync`。开始后推进 3 秒 → 3000；暂停 5 秒不动；继续再走 2 秒 → 5000；`stop()` 返回 5000 且状态清空；`ticks` 每秒一次；`dispose` 后无悬挂定时器。
- `panel_notifier_test`：开始 → `state.running`；走秒不写库；停止 → `TimeLog` 一条、`spentSec` 增加、`running` 复位；跑着点完成 → 先落流水再 `isDone`；另一条在跑时开始被拒。
- `panel_page_test`：计时中无「开始」、有时钟与两个图标键；暂停时时钟转 `ink2` 且图标变三角形；已完成时无计时条。

## 偏差

| 项 | 原型 | 实现 | 为什么 |
| --- | --- | --- | --- |
| 图标 | 内联 SVG（竖杠 / 三角形 / 方块） | Material 图标 | 形状一致；为三个图标引 SVG 依赖不划算 |
| 完成时结算 | `markItemDone` 只清计时、不写流水（1345） | 先 `StopTask` 再完成 | 原型的漏写；不记这一次就白计时了 |
| 面板「开始」收起主界面 | 第 4、6 页会 `main.classList.remove('on')` | 面板内不做 | 面板里本来就看不到主界面，收起由 B12、B15 的行内「开始」负责 |

## 与 PRD 对不上的两处

| 项 | PRD 怎么写 | 实际按谁做 | 结论 |
| --- | --- | --- | --- |
| 点「标记完成」之后 | 第 2 页「能做的操作」写「面板收起」；同一页的状态表写「显示『这件事已标记为完成』」 | 按原型 `renderAction` 与状态表：停在完成态，面板不自己收 | PRD 那一行是旧文案，与自己的状态表冲突；待回改 PRD，代码不动 |
| 「两件的秒数各算各的」 | 「切到另一件事，原来那件的计时照跑；两件的秒数各算各的」「一件在跑不影响另一件」 | 按 AC-5 与 `07-开发`：同一时刻只一条在跑；切走不停表，累计仍分开记 | 两句话按「时长分账、切走不停」理解，不读成允许两条并行；若真要并行，先回改 PRD 与 `07-开发` 再动服务 |
