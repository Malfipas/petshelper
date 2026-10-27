# B09 悬停小面板 · 设计

## 概述

在 `PetFrame.panel` 这块已经摆好的区域里，用 `PanelPage` 画三种形态，用 `PanelNotifier` 管当前事务与随手记草稿。不加表、不改迁移、不加定时器：当前事务是运行期概念，随手记借现成的 `notes` 表。

## 技术方案

### 分层落点

```text
features/pet/pet_page.dart          _PanelSurface 换成 PanelPage（B08 已留好这块）
features/panel/panel_page.dart      画三种形态 + 动作区
features/panel/panel_notifier.dart  PanelNotifier + PanelState
domain/usecase/finish_task.dart     已有，勾完成直接用
data/repository/*                   只读，不加方法
```

面板不 import drift，不写路由字符串；数据经三个 Repository，动作经 `FinishTask`。

### 状态形状

```dart
enum PanelKind { empty, project, solo }

class PanelState {
  final PanelKind kind;
  final String? taskId;        // 当前事务；空态为 null
  final String title;          // 项目名 / 事项名
  final int stepIndex;         // 项目 currentStep，0 起；-1 表示还没开始
  final int totalSteps;        // 步骤总数，0 表示没拆步骤
  final String? stepName;      // 当前步名
  final List<String> stepNames;// 按顺序的步名，给流程轴每段做悬停提示
  final bool isDone;           // 这一件是否已完成，完成后动作区换成提示条
  final String scratch;        // 随手记草稿（可能没落盘）
  final String savedScratch;   // 上次落盘的值，相等就不写库
  final List<PanelAnswer> answers;
  final bool aiReady;          // 是否已接模型
}
```

- `currentStep = stepIndex + 1`（封顶到 `totalSteps`）；流程轴亮前 `currentStep` 段，与原型 `for(i=0;i<t.current;i++)` 一致。
- 步数与索引不取 `ProjectDigest`：摘要只给步名，要 0 起索引得再读一次 `projectRepository.load()`。项目数据很小，比给摘要加字段省事。
- 元信息 `第 N 步 / 共 M 步`；原型尾部「约 N 分钟」暂不显示，理由见「偏差」。

### 选事务

```text
显式指定过的那件（存在就用，完成了也留着——完成态要显示提示条）
否则 digests = projectRepository.digests()      // 按 lastAdvancedAt 降序
    for digest in digests:
        第一件未完成 → 形态 A（title 取项目名，步数取 load() 的结果）
    没有 → solo() 第一件未完成 → 形态 B
    没有 → 空态
```

选中 id 存在 Notifier 字段里，`setCurrentTask` 可覆盖。不给 `taskRepository` 加新方法：`byProject` 与 `solo` 够用。

### 动作与落盘

| 动作 | 走哪 |
| --- | --- |
| 改随手记草稿 | `draftScratch(text)`，只改内存 |
| 失焦 / 切事务 | `commitScratch()` → `NoteRepository.save(NoteOwner.task, taskId, ...)` |
| 标记完成 | `finishTaskProvider.call(taskId, nowMs, done: true)`，然后把 `isDone` 置真，**不刷新、不换任务** |
| 问一问 | `ask(text)`：`aiReady == false` 时直接返回，不落库 |

切事务顺序固定为「先落盘旧的、再读新的」：否则切回来读不到刚才写的。

完成之后停在原任务上，照原型 `renderAction`：完成任务后动作区换成 `.donenote`「这件事已标记为完成」，`task` 变量不动；要换任务得去第 4、6 页挑。面板重开（新 Notifier 实例）时按「未完成」重新挑，自然会跳掉已完成的那件。

### 界面结构

```text
Padding(16)
└─ SingleChildScrollView          // 原型 max-height:40vh + overflow-y:auto
   ├─ 形态块（project / solo / empty 三选一）
   ├─ 随手记块
   ├─ 问一问块
   ├─ 问答记录（answers 非空才出现，最高 150 可滚）
   └─ 动作区（未完成：开始禁用 + 标记完成；已完成：一句提示条）
```

## 文件结构

```text
app/lib/features/panel/
├── panel_notifier.dart   PanelKind、PanelState、PanelAnswer、PanelNotifier
└── panel_page.dart       PanelPage（ConsumerWidget）
app/test/features/panel/
├── panel_notifier_test.dart
└── panel_page_test.dart
```

## 对应需求

覆盖 FR-01 ~ FR-10，逐条落点见 `tasks.md` 的「需求覆盖矩阵」。

## 数值对照（2026-10-24 按整体原型第 2 页复核）

| 项 | 原型 | 实现 |
| --- | --- | --- |
| 面板内边距 | `.panel{padding:16px}` | 16 |
| 面板圆角 | `border-radius:var(--r)` = 10 | `AppTheme.radiusControl` = 10 |
| 面板阴影 | `--shadow:0 12px 32px rgba(30,50,80,.16)` | blur 32、offset (0,12)、alpha .16 |
| 面板背景 | `--glass: rgba(255,255,255,.86)` + blur 14 | 白 96%（见偏差） |
| 流程轴外边距 | `.track{margin:11px 0 12px}` | 上 11、下 12 |
| 段高 / 段距 / 段圆角 | 5 / 5 / 3 | 5 / 5 / 3 |
| 段悬停提示 | 每段挂 `tip` 显示步名 | 每段 `Tooltip(message: 步名)` |
| 项目名 / 当前步 / 元信息 | 15·600 / 14·1.6 / 12 二档墨 | 同 |
| 随手记 | `margin:10px 0 8px`，标签 11 三档墨 mb4，框高 30、内边距 5/8、字 12·1.5、圆角 8、边二档 | 同 |
| 问一问 | 框最小高 36、最大高 104、内边距 8/10、字 13·20、圆角 8、边一档 | 同 |
| 问一问只读 | 底 `#f4f7fb`、字二档墨、占位「请前往设置页配置 API key」 | 同 |
| 发送键 | 42×min 36、圆角 8、禁用 `opacity:.4` | 42×36、圆角 8、0.4 |
| 问答卡片 | `.answers` 顶 10、条间 8、最高 150；卡片内边距 10/12、圆角 8、底 accent-soft、边 `#cfdcfb`；问题 12 `#4b6591`、回答 13·1.65 `#1f3a6e` | 同 |
| 开始键 | `.go` 100% 宽、min 44、圆角 10、字 15、主色 | 同（禁用） |
| 完成提示 | `.donenote` 顶 12、内边距 11/12、圆角 10、底 `#f1f5ec`、边 `#d9e4cc`、字 13 `#4d5c3c` | 同 |
| 空态 | `.pe{padding:4px 2px 8px}`，标题 14·600，副行 12·三档墨 mt6 | 同 |

## 偏差与理由

| 项 | 原型 | 实现 | 为什么 |
| --- | --- | --- | --- |
| 元信息时长 | 「第 N 步 / 共 M 步 · 约 N 分钟」 | 不含时长 | 事项没有预计时长字段；硬造数字比不写更糟，B10 有真实投入时长后再补 |
| 开始按钮 | `.go` 可点 | 画出来但禁用（0.45） | 计时服务在 B10，没有它按下去只能假装在计时 |
| 项目名徽标 | `.chip`「已标记」 | 不画 | 数据层没有「手动标记当前事务」的字段；选事务由 B04 的规则推出来，B11 之后再评估要不要加 |
| 玻璃背景 | `.86` + `backdrop-filter:blur(14px)` | 白 96% | 桌面端实时模糊要额外窗口通道；无模糊时 .86 会透到看不清字，先加不透明度保住可读性，B24 再评估 |

## 测试策略

- `PanelNotifier`：假 Repository（实现端口）测选事务、切事务带草稿、完成停在完成态、重开跳过已完成、空态、`ask` 不改状态。
- `PanelPage`：`UncontrolledProviderScope` + 内存库测三种形态文案、流程轴段数与亮段与每段提示、各尺寸字号与圆角（照原型数值断言）、禁用态、完成提示条、问答卡片。
- 手势：点「标记完成」后动作区换成提示条；输入框失焦触发落盘。
