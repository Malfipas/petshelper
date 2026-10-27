# B16 我的项目页 · 进度史与时间轴 · 任务拆解

状态：已完成

依据：[requirements.md](requirements.md)、[design.md](design.md)；整体原型第 6 页进度史区（HTML 878–905、CSS 452–500、渲染 2197–2230、编辑 2290–2340 行）、单页原型 `prototype/第六页-我的项目.html`、PRD `docs/05-定义-PRD.md` 604–652 行。

## 任务列表

- [x] T1 写三份规格，`check_spec` 通过
- [x] T2 `data/dao/notes_dao.dart` 加 `byOwnerType`，`NoteRepository` 加 `textsOf(NoteOwner)`（一次读回该类型全部随手记，按 `ownerId` 建表）
- [x] T3 `app/theme.dart` 加 `histTag` / `histRev` / `histLine`（`#f4f7fc` / `#f8fafd` / `#e6ecf5`）
- [x] T4 `project_list_state.dart`：`detailProgress`、`historyTimeline`、`editingEntryId`、`historyNoteEditingId`、`openRevisions`、`revisions`、`historyNotes` 七个字段；`clearEditingEntry` / `clearHistoryNoteEditing` 两个清除位与集合更新；`clearDetail` 一并清空
- [x] T5 `project_list_state.dart`：`sortProgress` / `historyWhen` / `historyDay` 三个顶层函数（与行模型同处，纯函数不进 notifier）
- [x] T6 `projects_notifier.dart`：`open()` 里读进度史与本类随手记，`_applyBundle` 写 `detailProgress` 与 `historyNotes`
- [x] T7 `projects_notifier_history.dart`（新，part 里的 `mixin ProjectHistoryActions`）：八个动作 `toggleHistoryAxis` / `beginEditEntry` / `cancelEditEntry` / `saveEntry` / `toggleRevisions` / `beginHistoryNote` / `cancelHistoryNote` / `saveHistoryNote`，外加私有 `_loadRevisions` / `_refreshProgress`；三条短路按设计
- [x] T8 `projects_notifier.dart`：`collapse()` 在 `confirming` 之后插入 `editingEntryId`、`historyNoteEditingId` 两层
- [x] T9 `features/projects/project_history.dart`（新）：`ProjectHistorySection`（区块头与切换键、列表行 `_HistoryRow`、正文 `_HistoryBody`、修订链块 `_RevisionBox`、步骤标签 `_StepTag`）
- [x] T10 `features/projects/project_history_edit.dart`（新，part）：`_EntryEditor`、`_NoteRow`、`_AxisButton`、`_SolidButton`、`_GhostButton`
- [x] T11 `features/projects/project_history_axis.dart`（新，part）：`_HistoryAxis`（左缩 22、2px 竖线、10×10 圆点、按天分组、天标题）
- [x] T12 `projects_page.dart`：在 `ProjectMovedSection` 之后挂 `ProjectHistorySection`，接上 state 与八个动作
- [x] T13 `test/features/projects/projects_history_test.dart`（新）：排序三条、时间戳五档（含跨午夜）、天标题、读回与 `textsOf` 批量、`FinishTask` 落史、留痕与三条短路、修订链缓存、随手记写入与清空、编辑互斥、视图切换、`collapse` 逐层、退回复位
- [x] T14 `test/features/projects/projects_page_test.dart` 追加七条：空块不渲染、88/14/11 数值与时刻文案、切时间轴后分组与 13 号、编辑保存后正文与「改过 1 次」、时间轴里改正文仍在时间轴、修订链展开收起、随手记空态与写入
- [x] T15 `dart analyze lib test` 干净、`flutter test` 全量重跑
- [x] T16 写 `docs/测试结果/B16-进度史与时间轴.md` 与总记录一行，同步五处文档，本文件勾选

## 交付物清单

- 代码：`project_history.dart`（新）、`project_history_edit.dart`（新）、`project_history_axis.dart`（新）、`projects_notifier_history.dart`（新）、`project_list_state.dart`、`projects_notifier.dart`、`projects_page.dart`、`notes_dao.dart`、`note_repository.dart`、`theme.dart`
- 测试：`projects_history_test.dart`（新）、`projects_page_test.dart`
- 文档：`docs/测试结果/B16-进度史与时间轴.md`、`docs/测试结果/总记录.md`、`docs/开发任务拆解.md`、`docs/07-开发.md`、`state/AI桌宠日常助手-产品规划.md`、`产品生命周期过程记录.md`

## 文件变更清单

| 文件 | 动作 |
| --- | --- |
| `app/lib/features/projects/project_history.dart` | 新增（区块宿主与行） |
| `app/lib/features/projects/project_history_edit.dart` | 新增（part，正文编辑与随手记行） |
| `app/lib/features/projects/project_history_axis.dart` | 新增（part，时间轴） |
| `app/lib/features/projects/projects_notifier_history.dart` | 新增（part，进度史动作 mixin） |
| `app/lib/features/projects/project_list_state.dart` | 修改（七个字段、清除位、集合更新、三个顶层函数） |
| `app/lib/features/projects/projects_notifier.dart` | 修改（读进度史与随手记、`collapse` 两层、拆出动作） |
| `app/lib/features/projects/projects_page.dart` | 修改（挂进度史区块） |
| `app/lib/data/dao/notes_dao.dart` | 修改（`byOwnerType`） |
| `app/lib/data/repository/note_repository.dart` | 修改（`textsOf`） |
| `app/lib/app/theme.dart` | 修改（三个色常量） |
| `app/test/features/projects/projects_history_test.dart` | 新增 |
| `app/test/features/projects/projects_page_test.dart` | 修改 |
| `docs/测试结果/B16-进度史与时间轴.md` | 新增 |
| `docs/测试结果/总记录.md` | 修改 |
| `docs/开发任务拆解.md` | 修改 |
| `docs/07-开发.md` | 修改 |
| `state/AI桌宠日常助手-产品规划.md` | 修改 |
| `产品生命周期过程记录.md` | 修改 |

## 需求覆盖矩阵

| 需求 | 任务 | 测试 |
| --- | --- | --- |
| FR-01 | T9、T12 | 界面「一条进展都没有时整块连着标题一起不出现」 |
| FR-02 | T9 | 界面「切到时间轴：标题与键互换」 |
| FR-03 | T5 | 数据「按步骤号收拢乱序三条」「不按时间倒序」 |
| FR-04 | T9 | 界面「时刻列 88 宽、正文 14 号行高 1.6」「时刻按时钟落成今天 08:00」 |
| FR-05 | T9 | 界面「步骤标签 11 号、内边距 1/7」 |
| FR-06 | T7、T9 | 数据「展开走库、收起再展开走缓存」、界面「展开与收起修订链」 |
| FR-07 | T6、T7、T9 | 数据「计数加一、空白不写、没改不写」、界面「保存后上屏并出现改过 1 次」 |
| FR-08 | T2、T6、T7、T9 | 数据「写入、清空即删、`textsOf` 批量」、界面「随手记空态与写入」 |
| FR-09 | T11 | 界面「按天分组、天标题、节点数与条数一致」 |
| FR-10 | T5 | 数据「五档文案与跨午夜」 |
| FR-11 | T9、T12 | 界面「时间轴里改完正文仍停在时间轴」 |
| FR-12 | T8 | 数据「Esc 逐层收」「退回列表七个字段复位」 |
| FR-13 | T6 | 数据「完成一件事后那一行进得了进度史」 |

## 完成判定

- FR-01..FR-13 全部有实现与对应测试，数值逐项断言（88、14、13、12、11、1/7、10×10、2px、22）。
- 写正文、写随手记都先落库再重读；编辑正文不产生空白留痕。
- 时间轴与列表读同一份数据，切换不清编辑态。
- `dart analyze` 为 No issues found；`flutter test` 385 条全过，B01–B15 不回归。
- 留档与五处文档同步，本文件全部勾选。
