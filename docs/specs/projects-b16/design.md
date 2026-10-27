# B16 我的项目页 · 进度史与时间轴 · 设计

依据：[requirements.md](requirements.md)；整体原型第 6 页进度史区（HTML 878–905、CSS 452–500、渲染 `pjRenderHist` 2197–2230、编辑 2290–2340 行）、单页原型 `prototype/第六页-我的项目.html`、PRD `docs/05-定义-PRD.md` 604–652 行。

## 概述

详情最后一块：把 `progress_entries` 按流程顺序排成一列，每条能看时刻、改正文（留痕）、写随手记，区块头右侧可把同一批数据切成按天分组的时间轴。数据全部来自既有三张表（`progress_entries` / `revisions` / `notes`），本块只新增读写路径与界面，不动表结构、不加迁移。

## 技术方案

### 数值对照（原型 → 实现）

| 项 | 原型 | 实现 |
| --- | --- | --- |
| 区块头标题 | 13/600 `ink2`，上下留 2/8 | 同 |
| 切换键 | 最小高 26、左右 8、12 号主色；「时间轴」/「进度史」 | 同 |
| 行 | 上下 14、下边 1px `line`、间距 14；末行无底边 | 同 |
| 时间戳列 | 宽 88、12 号 `ink3`、等宽数字、上留 2 | 同 |
| 正文 | 14 号、行高 1.6 | 同 |
| meta 行 | 上留 6、gap 10 | 同 |
| 步骤标签 | 11 号、内边距 1/7、底 `#f4f7fc`、边 `line`、圆角 6 | `AppColors.histTag` |
| 改过 N 次 / 编辑 | 11 号主色 | 同 |
| 修订链块 | 上留 8、内边距 9/11、12 号 `ink2`、底 `#f8fafd`、边 `line`、圆角 8、行高 1.7 | `AppColors.histRev` |
| 正文编辑框 | 最小高 62、内边距 8/10、13 号、主色边、圆角 8 | 同 |
| 正文保存 / 取消 | 28 高、12 号、圆角 8 | 同 |
| 随手记行 | 上留 6；「还没记」12 号 `ink3` / 正文 12 号 `ink2` | 同 |
| 随手记编辑框 | 最小高 48、内边距 6/8、12 号、主色边、圆角 8 | 同 |
| 随手记保存 / 取消 | 26 高、12 号、圆角 8 | 同 |
| 时间轴缩进 | 左 22；竖线 2px `#e6ecf5`（上下 6） | `AppColors.histLine` |
| 节点圆点 | 10×10、白底、2px 主色边、左 -21、上 14 | 同 |
| 天标题 | 12 号 `ink3`；上 16 下 6；首组无上边距 | 同 |

### 状态与数据流

```text
展开详情 ─ ProjectRepository.bundle(projectId)
            ├─ bundle.progress  → sortProgress(...)   → state.detailProgress
            ├─ NoteRepository.textsOf(history)        → state.historyNotes
            └─ （点开修订链才读）revisionsOf(progressEntry, id) → state.revisions[id]

写正文 ─ ProjectRepository.reviseProgress(entryId, after, nowMs)
            ├─ revisions 追加一条（before → after）
            ├─ progress.revisionCount + 1
            └─ _refreshProgress()：重读 bundle.progress 再 reload

写随手记 ─ NoteRepository.save(NoteOwner.history, entryId, body, nowMs)
            └─ 只改 state.historyNotes 的该条，不重读整个 bundle
```

`_applyBundle` 一次把 `detailSteps` / `detailTasks` / `movedTasks` / `detailProgress` / `historyNotes` 写全；`_refreshTasks` 只刷待办，`_refreshProgress` 只刷进度史与随手记，避免每写一次就把整个详情重算。

排序与文案：

```dart
/// 进度史只按流程顺序：先 stepIndex 升序，同一步内再 at 升序；无归属步排最后。
List<ProgressEntry> sortProgress(List<ProgressEntry> entries);

/// 刚刚 / 今天 HH:mm / 昨天 HH:mm / N 天前 HH:mm / M 月 D 日 HH:mm，按本地日历日算差。
String historyWhen(int atMs, int nowMs);

/// 时间轴天标题：把 historyWhen 的「 HH:mm」去掉。
String historyDay(int atMs, int nowMs);
```

日差用 `DateTime(y, m, d)` 相减取 `.inDays`，不用毫秒整除——23:59 与次日 00:01 整除会算成 0 天。

### 交互时序

```text
点「时间轴」   → toggleHistoryAxis()           → 标题与键文案互换，列表换成分组轴
点「改过 N 次」→ toggleRevisions(id)            → 首次读 revisionsOf 并缓存 → 就地展开
点「编辑」     → beginEditEntry(id)             → 正文换文本域（多行），收掉别的编辑与随手记编辑
点「保存」     → saveEntry(id, text)            → 空或未变：只退编辑态；否则 reviseProgress + 重读
点「随手记」   → beginHistoryNote(id)           → 文本域（最小 48）
点「保存」     → saveHistoryNote(id, body)      → NoteRepository.save(history, id, body) → 只刷该条
Esc            → 输入框先吃掉；收起后 collapse() 逐层收
```

### 边界与错误

- 空白正文或与原文相同：不写库、不产生 revision，退出编辑态。
- `entryId` 已不在列表（别处删了项目）：只退出编辑态，不报错。
- 修订链读取失败或为空：`revisionCount` 为 0 时不渲染入口；读了空列表也展开一个空块但不崩。
- 时间轴与列表共用 `detailProgress`；切视图不清 `editingEntryId` 与 `historyNoteEditingId`，编辑中的输入不丢。
- 进度史为空：整块（含头与切换键）不渲染。

## 文件结构

```text
app/lib/features/projects/
├── project_history.dart        新：ProjectHistorySection（区块头 + 列表行 + 修订链 + 正文编辑框 + 随手记行）
├── project_history_axis.dart   新（part）：ProjectHistoryAxis（按天分组、竖线、圆点、节点）
├── project_list_state.dart     改：七个字段、三个清除位、两个集合更新
├── projects_notifier.dart      改：三个顶层函数 + 两个读法 + 八个动作 + collapse 两层
└── projects_page.dart          改：移入块之后挂 ProjectHistorySection
app/lib/data/
├── dao/notes_dao.dart          改：byOwnerType
└── repository/note_repository.dart  改：textsOf(NoteOwner)
app/lib/app/theme.dart          改：histTag / histRev / histLine
app/test/features/projects/
├── projects_history_test.dart  新：排序、时间戳、留痕、随手记、textsOf、collapse
└── projects_page_test.dart     改：空态、数值、修订链、编辑保存、时间轴
```

## 对应需求

| 需求 | 设计落点 |
| --- | --- |
| FR-01 | `ProjectHistorySection` 空时 `SizedBox.shrink()`；页面挂在移入块之后 |
| FR-02 | 区块头 `hist-title` 与 `hist-axis`，文案随视图互换 |
| FR-03 | `sortProgress` |
| FR-04 | 行容器、88 宽时间戳列、14/1.6 正文 |
| FR-05 | meta 行与步骤标签（11 号、1/7、圆角 6） |
| FR-06 | `toggleRevisions` + 修订链块，首次读库后缓存 |
| FR-07 | `beginEditEntry` / `saveEntry` + `_HistoryEditor` |
| FR-08 | `beginHistoryNote` / `saveHistoryNote` + 随手记行 |
| FR-09 | `ProjectHistoryAxis` |
| FR-10 | `historyWhen` / `historyDay` |
| FR-11 | 两视图共用 `detailProgress` / `historyNotes` |
| FR-12 | `collapse()` 两层插入 |
| FR-13 | 只读 `bundle.progress`，不新增写入口 |

## 偏差表

| 偏差 | 原因 |
| --- | --- |
| 正文编辑框回车不提交，只走「保存」与失焦 | 正文是多行文本，回车要留给换行 |
| 修订链每条写成「HH:mm 改前 → 改后」 | 原型是一串现成文案，`revisions` 表只有 before/after 与时刻，按字段拼更诚实 |
| 7 天及以上用「M 月 D 日 HH:mm」 | 原型用过「周一 15:20」「上周五」两种说法且不统一；按日历日给绝对日期不会在跨月时歧义 |
| 时间轴也用同一套编辑与随手记 | PRD 只写「同一批数据换种排法」，两种视图各写一遍会让数据分叉 |

## 测试

- 数据与状态机 `test/features/projects/projects_history_test.dart`：排序（含 null 排最后）、时间戳五档（含 23:59 → 次日 00:01）、空文本不留痕、`revisionCount` 加一、随手记写入与清空、`textsOf` 批量、`collapse` 两层顺序。
- 界面 `test/features/projects/projects_page_test.dart` 追加：空态不渲染 `hist-title`、88 宽与 14/11 号字、修订链展开收起、编辑保存后正文与计数、切时间轴后分组与编辑可用。
- 全量 `flutter test` 与 `dart analyze lib test` 必须干净，B01–B15 不回归。
