# B14 项目详情 · 流程条与流程编辑 · 任务

状态：已完成（329 条通过，0 失败）

依据：[requirements.md](requirements.md)、[design.md](design.md)；单页原型 `prototype/第六页-我的项目.html` 127–170、457–472、718–778、1176–1280 行；PRD `docs/05-定义-PRD.md` 581–601、618–634 行。

## 任务列表

- [x] T1 写三份规格，`check_spec` 通过
- [x] T2 `data/dao/steps_dao.dart`：补 `byId`、`insertOne`、`updateRow`
- [x] T3 `data/dao/task_items_dao.dart` 补 `clearStep`；`data/dao/progress_entries_dao.dart` 补 `shiftAfter`
- [x] T4 `data/repository/project_repository.dart`：`renameStep`、`addStep`、`moveStep`（交换 index / 待办 / 进度史）、`deleteStep`（单事务）
- [x] T5 `projects_notifier.dart`：`detailSteps`、`filterStep`、`flowEditing` 与 `tapSegment` / `toggleFlowEdit` / `renameStep` / `moveStep` / `deleteStep` / `addStep`；`open` 默认筛选；`collapse` 三层
- [x] T6 `features/projects/project_flow.dart`：分段条（5 高、5 间距、`#d8e0ec` / 主色、150ms、悬停 94%、筛中 2 像素描边）、筛选提示行、流程编辑器（序号 22、输入 32、小键 28、加一步 30 虚线、完成 30）
- [x] T7 `projects_page.dart` 挂流程区（`main_shell.dart` 的 Esc 早已走 `collapse()`，未改；`project_detail.dart` 头部不动，流程区排在它之后）
- [x] T8 `test/features/projects/projects_flow_test.dart`：数据与状态机
- [x] T9 `test/features/projects/projects_page_test.dart` 补流程区界面用例
- [x] T10 `dart analyze` 干净、`flutter test` 全量重跑
- [x] T11 写 `docs/测试结果/B14-流程条与流程编辑.md` 与总记录一行，同步四处文档

## 交付物清单

| 类别 | 路径 |
| --- | --- |
| 分段条与编辑器 | `app/lib/features/projects/project_flow.dart` |
| 状态 | `app/lib/features/projects/projects_notifier.dart` |
| 数据 | `app/lib/data/repository/project_repository.dart`、`app/lib/data/dao/{steps,task_items,progress_entries}_dao.dart` |
| 测试 | `app/test/features/projects/projects_flow_test.dart`、`projects_page_test.dart` |
| 结果留档 | `docs/测试结果/B14-流程条与流程编辑.md` |

## 文件变更清单

| 文件 | 动作 |
| --- | --- |
| `app/lib/features/projects/project_flow.dart` | 新增 |
| `app/lib/features/projects/projects_notifier.dart` | 修改 |
| `app/lib/features/projects/project_detail.dart` | 未改（流程区直接排在头部之后） |
| `app/lib/features/projects/projects_page.dart` | 修改 |
| `app/lib/data/dao/steps_dao.dart` | 修改 |
| `app/lib/data/dao/task_items_dao.dart` | 修改 |
| `app/lib/data/dao/progress_entries_dao.dart` | 修改 |
| `app/lib/data/repository/project_repository.dart` | 修改 |
| `app/lib/app/main_shell.dart` | 未改（Esc 已接 `collapse()`） |
| `app/test/features/projects/projects_flow_test.dart` | 新增 |
| `app/test/features/projects/projects_page_test.dart` | 修改 |

## 需求覆盖矩阵

| 需求 | 任务 | 测试 |
| --- | --- | --- |
| FR-01 | T6 | 界面：段数与颜色 |
| FR-02 | T5、T6 | 界面：点段与提示行；单元：tapSegment |
| FR-03 | T6 | 界面：文案切换 |
| FR-04 | T6 | 界面：提示行数值与 × |
| FR-05 | T6 | 界面：序号、输入、小键尺寸 |
| FR-06 | T6 | 界面：两枚底键 |
| FR-07 | T4、T5 | 单元：改名；界面：改名同步 |
| FR-08 | T4、T5 | 单元：交换三张表；界面：↑↓ |
| FR-09 | T3、T4、T5 | 单元：删除四种收敛；界面：步数减少 |
| FR-10 | T4、T5 | 单元：末尾追加；界面：加一步 |
| FR-11 | T5 | 单元：默认筛选三边界 |
| FR-12 | T5、T7 | 界面：Esc 三层 |
