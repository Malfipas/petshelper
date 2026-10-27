# B15 我的项目页 · 本项目待办与「新增事项」 · 任务拆解

状态：已完成

依据：[requirements.md](requirements.md)、[design.md](design.md)；单页原型 `prototype/第六页-我的项目.html` 215–255、150–158、1008–1045、1195–1258 行；PRD `docs/05-定义-PRD.md` 581–652 行。

## 任务列表

- [x] T1 写三份规格，`check_spec` 通过
- [x] T2 `data/repository/task_repository.dart`：`moveOrder(id, delta)`（同一步相邻交换 `orderIndex`，到头返 false）、`addToStep(projectId, stepId, name)`（`orderIndex` 取该步末尾）
- [x] T3 `projects_notifier.dart`：`detailTasks`、`movedTasks`、`pendingDone`、`flashTaskId`、`addTaskFor`、`assigningTaskId`、`doneOfStep`；`toggleTaskDone`、`moveTask`、`startTask`、`assignStep`、`addTask`、`openAddTask`、`closeAddTask`、`saveNote`；`_applyBundle` 重算待办
- [x] T4 `features/projects/project_todo.dart`：`ProjectTodoRow`（72 高、勾选框 18、名称 15/600、元信息 12、随手记 24、「下一步」角标、↑↓ 24×24、开始 88×32）与 `ProjectMovedSection`（块头件数、来源角标、选择步骤下拉）
- [x] T5 `project_flow.dart`：每行第四枚「＋」（28 高最小宽 28），行内输入行（左缩进 30、输入高 30、添加 28、取消 28、上限 40、回车提交、Esc 收起）
- [x] T6 `projects_page.dart`：详情里在流程编辑器之后挂待办区与移入块，新增后滚到该条
- [x] T7 `test/features/projects/projects_todo_test.dart`：数据与状态机
- [x] T8 `test/features/projects/projects_page_test.dart` 追加待办区界面用例
- [x] T9 `dart analyze` 干净、`flutter test` 全量重跑
- [x] T10 写 `docs/测试结果/B15-项目待办卡片.md` 与总记录一行，同步四处文档

## 交付物清单

- 代码：`project_todo.dart`（新）、`project_flow.dart`、`projects_page.dart`、`projects_notifier.dart`、`task_repository.dart`
- 测试：`projects_todo_test.dart`（新）、`projects_page_test.dart`
- 文档：`docs/测试结果/B15-项目待办卡片.md`、`docs/测试结果/总记录.md`、`docs/开发任务拆解.md`、`docs/07-开发.md`、`state/AI桌宠日常助手-产品规划.md`、`产品生命周期过程记录.md`

## 文件变更清单

| 文件 | 动作 |
| --- | --- |
| `app/lib/features/projects/project_todo.dart` | 新增 |
| `app/lib/features/projects/project_flow.dart` | 修改（第四枚键 + 行内输入） |
| `app/lib/features/projects/projects_page.dart` | 修改（挂待办区与移入块） |
| `app/lib/features/projects/projects_notifier.dart` | 修改（状态与八个动作） |
| `app/lib/data/repository/task_repository.dart` | 修改（`moveOrder`、`addToStep`） |
| `app/test/features/projects/projects_todo_test.dart` | 新增 |
| `app/test/features/projects/projects_page_test.dart` | 修改 |
| `docs/测试结果/B15-项目待办卡片.md` | 新增 |
| `docs/测试结果/总记录.md` | 修改 |
| `docs/开发任务拆解.md` | 修改 |
| `docs/07-开发.md` | 修改 |
| `state/AI桌宠日常助手-产品规划.md` | 修改 |
| `产品生命周期过程记录.md` | 修改 |

## 需求覆盖矩阵

| 需求 | 任务 | 测试 |
| --- | --- | --- |
| FR-01 | T3、T6 | 状态机「筛选取待办」、界面「待办区随筛选变」 |
| FR-02 | T6 | 界面「没有待办时整块不渲染」 |
| FR-03 | T4 | 界面「卡片 72 高、圆角 12、勾选框 18」 |
| FR-04 | T4、T3 | 界面「勾选后变蓝加删除线」 |
| FR-05 | T4 | 界面「元信息第 N 步 · 名字 · 已做 X 分钟」 |
| FR-06 | T4 | 界面「下一步角标只在下个待做步的卡片上」 |
| FR-07 | T4、T3 | 数据层「随手记读写」、界面「已记/还没记」 |
| FR-08 | T3 | 状态机「600 毫秒后移出」、数据层「写进度史且不重复」 |
| FR-09 | T2、T3 | 数据层「中间/到头/跨步」 |
| FR-10 | T4、T3 | 界面「开始 88×32」、状态机「开表并跳面板」 |
| FR-11 | T4 | 界面「来源角标与件数」 |
| FR-12 | T3、T4 | 状态机「assignStep 后从移入块消失」 |
| FR-13 | T5、T3 | 界面「＋ 28 高、输入行 30 高、添加 28 高」 |
| FR-14 | T3、T6 | 状态机「新增切筛选并 flash」 |
| FR-15 | T4 | 界面「移入块头件数」 |
