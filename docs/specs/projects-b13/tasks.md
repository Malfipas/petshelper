# B13 我的项目页 · 任务

状态：已完成（2026-10-24）

依据：[requirements.md](requirements.md) 与 [design.md](design.md)；原型 `prototype/整体原型.html` 第 6 页；PRD 566–652 行。

## 任务列表

- [x] T1 写三份规格（requirements / design / tasks），`check_spec` 通过
- [x] T2 `features/projects/projects_notifier.dart`：`ProjectRow`、`ProjectListState`、`ProjectListNotifier`（reload / open / back / toggleForm / setName / setDescription / setDue / create / askDelete / cancelDelete / confirmDelete / collapse / takeFlash），顶层 `relativeSince`、`percentOf`、`dueLabel`
- [x] T3 `features/projects/projects_page.dart`：页头 16/600 + 件数 + 新建键 34、新建内联表单（名称必填 30、说明 40、截止日期、重名红字、确定禁用）、列表滚动、空态 48、删除遮罩
- [x] T4 `features/projects/project_card.dart`：卡片 14/18 圆角 12 间距 8、名 15/600 与百分比 13、4 像素进度条、下一步与最近推进、右中箭头、悬停 140ms
- [x] T5 `features/projects/project_detail.dart`：返回键 32、标题 20/600 占 46%、说明与截止 210 截断、进度行、删除键 32
- [x] T6 删除确认遮罩：宽 360、圆角 14、遮罩 rgba(24,36,54,.28)、取消 + 确认删除各 34 高
- [x] T7 `app/lib/app/router.dart`：`_pageOf` 透传 `?id=`；`main_shell.dart` 的 Esc 先问项目页；页面 `initState` + `didUpdateWidget` 两处展开
- [x] T8 `projects_notifier_test.dart`：纯函数 3 + 行数据 2 + 新建 2 + 展开与删除 3，共 10 条
- [x] T9 `projects_page_test.dart`：界面 13 条（页头、空态、表单、建成、卡片、详情、详情头、删除弹窗、删除落地、`?id=` 命中、`?id=` 失效、整壳带 id、Esc 三层）
- [x] T10 `dart analyze` 干净、`flutter test` 全量 309 条通过
- [x] T11 写 `docs/测试结果/B13-项目列表与详情框架.md` 与总记录一行，同步四处文档

## 交付物清单

| 交付物 | 路径 | 说明 |
| --- | --- | --- |
| 状态层 | `app/lib/features/projects/projects_notifier.dart` | 行数据组装、新建、展开、删除、Esc 顺序、三个纯函数 |
| 页面 | `app/lib/features/projects/projects_page.dart` | 页头挂载、表单开关、列表、空态、弹窗挂载 |
| 页头与按钮 | `app/lib/features/projects/project_widgets.dart` | 页头（标题、件数、提示、新建键）与页面用的小按钮 |
| 新建表单 | `app/lib/features/projects/project_form.dart` | 名称/说明/截止三行、重名红字、确定禁用 |
| 删除弹窗 | `app/lib/features/projects/project_confirm.dart` | 遮罩、宽 360 弹窗、取消与确认删除 |
| 卡片 | `app/lib/features/projects/project_card.dart` | 一行项目卡片 |
| 详情头 | `app/lib/features/projects/project_detail.dart` | 返回、标题、说明与截止、进度行、删除键 |
| 路由与壳 | `app/lib/app/router.dart`、`app/lib/app/main_shell.dart` | `?id=` 透传、Esc 先问本页 |
| 单元测试 | `app/test/features/projects/projects_notifier_test.dart` | 纯函数 3 条 + 行数据与状态机 7 条 |
| 界面测试 | `app/test/features/projects/projects_page_test.dart` | 13 条 |
| 结果留档 | `docs/测试结果/B13-项目列表与详情框架.md` | 逐条结果、数值对照与偏差 |

## 文件变更清单

| 文件 | 动作 |
| --- | --- |
| `app/lib/features/projects/projects_notifier.dart` | 新增 |
| `app/lib/features/projects/projects_page.dart` | 重写（原为 ComingSoon） |
| `app/lib/features/projects/project_widgets.dart` | 新增 |
| `app/lib/features/projects/project_form.dart` | 新增 |
| `app/lib/features/projects/project_confirm.dart` | 新增 |
| `app/lib/features/projects/project_card.dart` | 新增 |
| `app/lib/features/projects/project_detail.dart` | 新增 |
| `app/lib/app/router.dart` | 改：`_pageOf` 透 `id` |
| `app/lib/app/main_shell.dart` | 改：Esc 先问项目页 |
| `app/test/features/projects/projects_notifier_test.dart` | 新增 |
| `app/test/features/projects/projects_page_test.dart` | 新增 |
| `docs/测试结果/B13-我的项目列表与详情框架.md` | 新增 |
| `docs/测试结果/总记录.md`、`docs/开发任务拆解.md`、`docs/07-开发.md`、`state/AI桌宠日常助手-产品规划.md`、`产品生命周期过程记录.md` | 改：同步 B13 |

## 需求覆盖矩阵

| 需求 | 任务 | 测试 |
| --- | --- | --- |
| FR-01 页头 | T3 | 界面「页头尺寸与件数」 |
| FR-02 项目卡片 | T4 | 界面「卡片结构」 |
| FR-03 百分比与下一步 | T2、T4 | 单元「percentOf」「行数据」 |
| FR-04 最近推进 | T2、T4 | 单元「relativeSince 七档」 |
| FR-05 空态 | T3 | 界面「空态」 |
| FR-06 新建表单 | T3 | 界面「表单三项与取消」 |
| FR-07 校验与建成 | T2、T3 | 单元「新建」、界面「重名红字与禁用」 |
| FR-08 详情头部 | T5 | 界面「详情头部数值」 |
| FR-09 截止日期格式 | T2、T5 | 单元「dueLabel」 |
| FR-10 删除确认 | T6 | 界面「弹窗文案与按钮」 |
| FR-11 删除效果 | T2、T6 | 单元「删除清关联」、界面「确认删除落地」 |
| FR-12 地址带 id | T7 | 界面「`?id=` 命中与失效」 |

## 测试计划

| 用例 | 断言要点 |
| --- | --- |
| 纯函数 | `relativeSince` 七档、`percentOf` 取整与 0 步骤、`dueLabel` 去前导零与空值 |
| 行数据 | 名/百分比/下一步取 orderIndex 最小未完成/无待办为空串/创建倒序 |
| 新建 | 空名拒、重名拒、正常建成在最前且自动展开 |
| 状态机 | open/back、`collapse` 弹窗优先于详情 |
| 删除 | 确认后行消失、关联待办清掉；取消只关弹窗 |
| 界面 | 页头 16/600 与 34 高、空态 48、表单禁用与红字、卡片 4 像素条与文案、详情头部数值、弹窗 360/34、Esc 三层、`?id=` 命中与失效 |
