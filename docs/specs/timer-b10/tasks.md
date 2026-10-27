# B10 计时服务与计时条 · 任务

> 状态：已完成（2026-10-24）。

## 交付物清单

| 交付物 | 位置 |
| --- | --- |
| 计时服务 | `app/lib/platform/timer/timer_service.dart` |
| 服务注入 | `app/lib/app/providers.dart` |
| 面板状态 | `app/lib/features/panel/panel_notifier.dart` |
| 面板界面 | `app/lib/features/panel/panel_page.dart` |
| 服务测试 | `app/test/platform/timer/timer_service_test.dart` |
| 状态测试 | `app/test/features/panel/panel_notifier_test.dart` |
| 界面测试 | `app/test/features/panel/panel_page_test.dart` |
| 结果留档 | `docs/测试结果/B10-计时与计时条.md` |

## 任务列表

### T0 校准

- [x] T0-1 回原型第 2 页量 `.timerbar` / `.clock` / 按钮 / paused 与 `renderAction` 的交互
- [x] T0-2 核对 PRD 第 2 页动作区与 F4 的措辞
- [x] T0-3 确认 `StartTask` / `StopTask` 与 `TaskRepository.logSession`/`accumulateSpent` 已在 B03 就绪
- [x] T0-4 改写 `docs/开发任务拆解.md` B10 段的产出、完成判定与顺延项
- [x] T0-5 写 `requirements.md` / `design.md` / 本文件

### T1 计时服务

- [x] T1-1 `RunningTimer` 与 `TimerService`：`start` / `pause` / `resume` / `stop` / `elapsedMs`
- [x] T1-2 `ticks` 每秒一次；状态变化立刻推一次
- [x] T1-3 `dispose()` 关定时器与流
- [x] T1-4 `start` 时已有别的在跑则抛 `StateError`
- [x] T1-5 `timerServiceProvider`：挂 `ref.onDispose`

### T2 面板状态

- [x] T2-1 `PanelState` 增 `running` / `paused` / `elapsedMs` 与 `clockLabel`
- [x] T2-2 `start()` 走 `StartTask`，`Busy`/`Done`/`NotFound` 一律不动界面
- [x] T2-3 `pause()` / `resume()`
- [x] T2-4 `stop()`：净毫秒 ≥ 1000 才落流水，最后复位
- [x] T2-5 `finish()`：跑着时先结算
- [x] T2-6 `build()` 订阅 `ticks`，`onDispose` 取消
- [x] T2-7 `_apply` 按 `running.taskId` 回填 `running`/`paused`/`elapsedMs`

### T3 界面

- [x] T3-1 动作区三态（已完成 → 计时条 → 开始 + 标记完成）
- [x] T3-2 计时条：时钟、暂停/继续、停止，数值照对照表
- [x] T3-3 暂停时时钟转 `ink2`、图标换三角形

### T4 测试与留档

- [x] T4-1 `timer_service_test.dart`：走秒、暂停冻结、继续、停止返回值、ticks 频率、dispose
- [x] T4-2 `panel_notifier_test.dart`：开始、走秒不落库、停止落库、跑着完成先结算、忙时拒绝
- [x] T4-3 `panel_page_test.dart`：计时条与两个图标键、暂停态、已完成无计时条
- [x] T4-4 `dart analyze` 零问题
- [x] T4-5 `flutter test` 全过（含 B01–B09 重跑）
- [x] T4-6 写 `docs/测试结果/B10-计时与计时条.md`，`总记录.md` 追加一行
- [x] T4-7 更新 `docs/07-开发.md`、`产品生命周期过程记录.md`、`state/…产品规划.md`

## 需求覆盖矩阵

| 需求 | 实现 | 验证 |
| --- | --- | --- |
| FR-01 开始 | `PanelNotifier.start()` + `StartTask` | `panel_notifier_test`：开始后 running；忙时拒绝 |
| FR-02 走秒 | `TimerService.ticks` + `clockLabel` | `timer_service_test`：3 秒后 3000；`panel_notifier_test`：走秒不落库 |
| FR-03 暂停继续 | `pause`/`resume` + `accumulatedMs` | `timer_service_test`：暂停冻结、继续接上 |
| FR-04 停止 | `stop()` + `StopTask` | `panel_notifier_test`：`TimeLog` 与 `spentSec` 各多一条 |
| FR-05 完成先结算 | `finish()` 里先 `stop()` | `panel_notifier_test`：跑着完成落流水 |
| FR-06 视觉 | `panel_page.dart` 常量 | `panel_page_test`：尺寸、字号、颜色断言 |
| NFR-01 分层 | `platform/timer/` 纯 Dart | `architecture_test` 已有；新文件不引 Flutter |
| NFR-02 可测 | 注入 `now` + `FakeAsync` | `timer_service_test` |
| NFR-03 不新增表 | 只用既有 `TimeLog` / `spentSec` | 迁移文件未改 |
| NFR-05 无悬挂定时器 | `dispose()` | `timer_service_test` 结束时无 pending timer |

## 文件变更清单

| 文件 | 变更 |
| --- | --- |
| `app/lib/platform/timer/timer_service.dart` | 新增 |
| `app/lib/app/providers.dart` | 新增 `timerServiceProvider` |
| `app/lib/features/panel/panel_notifier.dart` | 加运行态字段与四个动作 |
| `app/lib/features/panel/panel_page.dart` | 动作区三态与计时条 |
| `app/test/platform/timer/timer_service_test.dart` | 新增 |
| `app/test/features/panel/panel_notifier_test.dart` | 追加用例 |
| `app/test/features/panel/panel_page_test.dart` | 追加用例 |
| `docs/开发任务拆解.md` | B10 段校准 |
| `docs/测试结果/B10-计时与计时条.md` | 新增 |
| `docs/测试结果/总记录.md` | 追加一行 |
