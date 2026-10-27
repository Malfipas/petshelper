# B15 我的项目页 · 本项目待办与「新增事项」 · 设计

## 概述

详情页在流程编辑器之后再挂三块：待办卡片列表、未分配事项的移入块、以及流程编辑器每行行内的「新增事项」输入行。数据只经 `TaskRepository` / `NoteRepository` / `FinishTask` 用例，界面不做乐观更新（勾选那一秒的「变蓝」是界面本地状态，落库仍是 600 毫秒后一次写入）。

## 技术方案

### 数值对照（原型 → 实现）

| 项 | 原型（`第六页` 215–255 / 150–158 行） | 实现 |
| --- | --- | --- |
| 卡片 | `.ti`：最小高 72、内边距 0/16、下间距 8、圆角 12、一像素 `line` 边、白底 | 同 |
| 卡内间距 | `gap:14` | 同 |
| 勾选框 | `18×18`、2 像素边、圆角 6；完成态主色实底 + 白勾 | 同 |
| 名称 | `15/600`，行高 1.4，单行省略；完成态删除线 + `ink3` | 同 |
| 名称列 | `flex:0 0 42%`、上下内边距 13 | 同 |
| 元信息 | 12 号 `ink3`，上与名称距 3 | 同 |
| 随手记行 | 上与元信息距 5、元素间 6；输入高 24、12 号、内边距 0/8、圆角 6、边 `line2`、聚焦主色 | 同 |
| 随手记提示 | 11 号 `ink3`，写「已记」/「还没记」 | 同 |
| 中间说明 | `flex:1`、左缩进 20、13 号 `ink2` | 同 |
| 「下一步」角标 | `.src`：左距 8、内边距 1/6、11 号主色、`#eef3fe` 底、圆角 6 | 同 |
| ↑↓ 小键 | 24×24、12 号 `ink3`、圆角 8、间距 4、右距 6 | 同 |
| 开始 | `.ti-go` 最小宽 88、高 32、内边距 0/14、13 号主色字、白底、圆角 10；悬停主色边 + `accentSoft` | 同 |
| 移入块头 | 上留 14、标题 13/600、右侧件数 12 号 `ink3` | 同 |
| 选择步骤 | 88×32 白底主色字，点开下方 `.ti-stepsel`：内边距 0/16/10、上距 -8 下 8、元素间 8；下拉高 30、12 号、圆角 8；取消 28 高 | 同 |
| 闪一下 | `.ti.flash`：`accentSoft` 底 + `#cfdcfb` 边，1.2 秒后消失 | 同 |
| 编辑器第四枚键 | `.fe-mini` 28 高、最小宽 28、左右 8、12 号 | 文案「＋」 |
| 行内输入行 | `.fe-addrow`：上 2 下 8、左缩进 30、间距 8；输入高 30、13 号、内边距 0/10、圆角 8、上限 40；添加 28 高主色实底白字（空则 `opacity .45` 禁用）；取消 28 高白底一像素边 | 同 |

### 状态与数据流

```text
ProjectListState（B14 已有）
  detailSteps / filterStep / flowEditing
  + detailTasks     已挂步骤的未完成任务（按 orderIndex 昇序，筛选时只留该步）
  + movedTasks      stepId == null 的未完成任务
  + pendingDone     刚点完成、还在 600 毫秒等待里的任务 id
  + flashTaskId     新增后要闪一下的任务 id
  + addTaskFor      正在行内输入新增事项的步骤 id
  + assigningTaskId 正在选步骤的未分配任务 id
  + detailDoneOfStep 每步完成数（给元信息与件数用）

写路径（一律先落库再 reloadDetail）
  勾选完成 → 本地 pendingDone → 600ms → FinishTask（done + 进度史 + 随手记）
  ↑↓      → TaskRepository.moveOrder(id, ±1) → false 就不动
  随手记  → NoteRepository.save(task) → 只改本地 note 文本
  开始    → PanelNotifier.setCurrentTask + 收起主界面 + 跳面板
  选步骤  → TaskRepository.setStep(id, stepId) + orderIndex 末尾 → 筛选切到该步
  新增事项 → TaskRepository.addToStep(projectId, stepId, name) → 筛选切到该步 + flash
```

### 交互时序

- 勾选：`onChanged` → 本地 `pendingDone` 加 id（行立刻变蓝加删除线）→ `Future.delayed(600ms)` → `finishTask` → `reload` 重读待办与每步完成数。600 毫秒内重复点不叠加定时器。
- 随手记：`onChanged` 起 400 毫秒防抖；`focus` 丢失立刻写。写库失败保持输入内容，不清空。
- ↑↓：点一次调一次 `moveOrder`，返回 `false` 时什么都不做（不刷新、不提示）。
- 新增事项：点「＋」→ 该行下方出现输入行并 `autofocus`；回车或「添加」提交；Esc 或「取消」收起。提交成功把 `filterStep` 切到该步，页面 `Scrollable.ensureVisible` 滚到该条。
- 选步骤：点「选择步骤」展开 `DropdownButton<String>` + 取消；选中即落库、筛选切到该步。

### 边界与错误

- 待办一条都没有：待办区整块不渲染（不留空行、不写「还没有待办」）。
- 未分配事项为空：移入块整块不渲染。
- 名称超 40 字：输入框截断，不报错。
- 新增内容 trim 后为空：添加键禁用，回车不提交。
- 步骤在这一秒被删掉：`addToStep` 返回 null 时不动界面，只把输入行收起。
- 完成时该事已被删（`FinishTask` 返回 `Missing`）：`reload` 收场，不弹提示。
- 相邻两条 `orderIndex` 相同（历史脏数据）：先按 `orderIndex`、再按 `createdAt` 稳定排序，交换时写的是「两条互换成对方的 orderIndex」，相同就不换（返回 `false`）。
- 勾选后 600 毫秒内切走页面：定时器在 Notifier 里，`ref.mounted` 为假时丢弃。

## 文件结构

```text
app/lib/features/projects/
  project_todo.dart        新增：待办卡片行、未分配移入块、步骤下拉
  project_flow.dart        修改：每行第四枚「＋」与行内新增输入行
  projects_page.dart       修改：详情里挂待办区与移入块
  projects_notifier.dart   修改：状态 + detailTasks 等字段与八个动作
app/lib/data/repository/
  task_repository.dart     修改：moveOrder、addToStep
  note_repository.dart     读：已有 textOf/save
app/test/features/projects/
  projects_todo_test.dart  新增：数据与状态机
  projects_page_test.dart  修改：待办区、移入块、新增事项的界面用例
```

## 对应需求

| 需求 | 落点 |
| --- | --- |
| FR-01 | `_applyBundle` 里从 `taskRepository.byProject` 派 `detailTasks` / `movedTasks`；筛选取 `filterStep` |
| FR-02–04 | `project_todo.dart` 的 `ProjectTodoRow` |
| FR-05 | `ProjectTodoRow` 的 `_NoteField` + `saveNote` |
| FR-06 | `toggleTaskDone` + `_pendingDone` 定时器 + `finishTaskProvider` |
| FR-07 | `moveTask` + `TaskRepository.moveOrder` |
| FR-08 | `ProjectTodoRow` 的「开始」+ `startTask` |
| FR-09 | `ProjectMovedSection` + `assignStep` |
| FR-10–11 | `project_flow.dart` 的 `addTaskFor` 行内输入 + `addTask` |
| FR-12 | 块头件数 |

## 偏差表

| 项 | 原型 / PRD | 计划实现 | 为什么 |
| --- | --- | --- | --- |
| 勾选后移出 | 原型 600 毫秒后 `splice` 掉，不写库 | 600 毫秒后移出并写库（`FinishTask`） | 原型是静态页；写库是 PRD 610 的要求 |
| 待办区标题 | 原型无标题 | 不写标题 | 与原型一致 |
| 项目级开始 | 原型详情没有项目级开始 | 同样不放 | PRD 648 明确 |
| 未分配块 | 原型用 mock 数据 | 读真实 `stepId == null` 的未完成事项 | 真实数据来自 B10 独立事项页 |
| 步骤下拉 | 原型 `<select>` | `DropdownButton` 弹出 | Flutter 没有原生 select，交互等价 |
| 随手记落点 | 原型存在 `t.note` | `Note(task)` 一行 | 时间轴按 Note 取，B16 要用 |
| 闪一下 | `.ti.flash` 1.2 秒 | 同 | — |

## 测试

- 数据层（`projects_todo_test.dart`）：`moveOrder` 中间/到头/跨步、`addToStep` 编号取末尾、勾选完成写进度史且不重复、随手记读写、`setStep` 后 `orderIndex` 接末尾。
- 状态机：`filterStep` 影响 `detailTasks`、600 毫秒后移出、`pendingDone` 去重、`addTask` 切筛选并设 `flashTaskId`、`assignStep` 后从 `movedTasks` 消失、空名不新增。
- 界面（`projects_page_test.dart` 追加）：卡片 72 高与圆角、勾选框 18、名称 15/600、元信息文案、随手记 24 高与「已记」、↑↓ 24×24、开始 88×32、移入块头件数与来源角标、「＋」28 高与输入行 30 高添加键 28、勾选后 600 毫秒消失。
