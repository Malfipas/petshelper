# B23 项目 AI 帮助（第 6 页拆解）

- 日期：2026-10-27
- 范围：F5 拆解落地——第 6 页项目详情里的「AI 帮助」块：填目标、拆步骤、看预览、应用到项目
- 结论：`flutter test` 597 条全过（本块新增 26 条：状态与动作 7 + 界面 6 + 页面回归若干），`dart analyze lib test` 无问题

## 为什么补这一块

原型与任务拆解里 F5 一直写着「项目拆解」，实现里只有一句占位：详情页没有入口，`Project` 也不会自己长出步骤。使用者 2026-10-27 指出这是核心功能，不能缺。这一块只做拆解这一处；第 7 页归类与第 5 页日总结的端口已定、实现仍是离线占位。

## 口径

1. **预览不落库**。拆出来的步骤先摆在卡片里，点「应用到项目」才写。模型给的东西不一定对，先让人看一眼再收。
2. **空流程整体替换**。新建项目默认有一个占位步骤；这时应用拆解＝把占位换成真的。已经有内容就追加到末尾，不覆盖用户自己写的步骤。
3. **目标空着不发请求**。就地给一句「先写一句目标」，省一次几秒的等待。
4. **拆的那几秒要有动静**。按钮转「拆分中…」，期间不能重复点。等模型 3 到 10 秒而界面毫无反应，人会以为没点上。
5. **回话先上、步骤后列**。模型那句 `reply` 放在步骤之上，作为「我这样理解的」；失败时这一行位置换成原因。
6. **没 key 整块只读**，指路设置页，与第 2、5、6、7 页的入口口径一致，读的是同一个 `keyConfiguredProvider`。

## 实现

| 层次 | 内容 |
| --- | --- |
| 状态 | 新 `features/projects/project_ai_state.dart`：`AiHelp`（开合、目标、`AiPlanPhase` 四态 idle/thinking/ready/failed、回话、`List<PlannedStep>`、错误、是否已应用），派生 `busy`、`canApply` |
| 页面状态 | `ProjectListState` 加 `aiHelp` 字段与 `copyWith`，`clearDetail` 时一并重置 |
| 动作 | `ProjectsNotifier` 加 `toggleAiHelp`、`setAiGoal`、`askAi`、`applyAi`；`askAi` 按 `PlanReady`/`PlanNotConfigured`/`PlanFailed` 落态，`applyAi` 先置已应用再写库，成功后 `flash: '已加入 N 个步骤'` 并刷待办 |
| 界面 | 新 `features/projects/project_ai_help.dart`：收起一行「AI 帮助」，展开后是目标输入框、拆步骤按钮、回话行、步骤列表（序号圆点 + 步名 + 那件事）、应用按钮；`projects_page.dart` 插在流程区之后、本项目待办之前 |
| 端口 | 复用 B22 的 `ProjectPlanner` 与 `ProjectPlanWriter`，界面不认识 http |

几处判断：

- **四态用枚举而不是几个 bool**。`idle`（还没拆）、`thinking`（等模型）、`ready`（有步骤可应用）、`failed`（有原因要显示）互斥，摆两个 bool 迟早出现「又在转圈又报错」。
- **`applied` 单独记**。应用之后步骤仍在眼前，但按钮要变成「已应用」且不可再点，否则同一份拆解会被点进库两次。
- **拆完不动 `applied`**。重新填目标再拆是一次新的拆解，`askAi` 里把 `applied` 复位。

## 用例

| 文件 | 条数 | 覆盖 |
| --- | --- | --- |
| `test/features/projects/projects_notifier_test.dart` | 7（新增） | 展开与收起、写目标、目标空着不发请求、正常拆解落 `ready` 并带步骤与回话、没 key 落 `failed` 并指路设置页、模型失败落 `failed` 带原因、应用后写库并提示条数且按钮变已应用 |
| `test/features/projects/project_ai_help_test.dart` | 6 | 收起态只有一行、展开后有目标输入与拆步骤键、`thinking` 时按钮文案与禁用、`ready` 时列出步骤与那件事并可应用、`failed` 时显示原因不显示步骤、已应用时按钮文案变化 |
| `test/features/projects/projects_page_test.dart` | 回归 | 插入这块之后页面变长，原先两条点「保存」「删除」的用例在视口外，改成点前 `ensureVisible` |

- `flutter test`：**597 条全过**
- `dart analyze lib test`：`No issues found!`

## 实机

应用要重启才带新代码（上一版 exe 构建于 0:18:31）。重启后按 B22 那份清单走一遍即可：填目标、拆步骤、看预览、应用、清除 key 后只读。
