# B14 项目详情 · 流程条与流程编辑 · 设计

## 概述

在 B13 的详情头部下面接一层「流程区」：分段进度条（可点筛选）、筛选提示行、流程编辑器（改名 / 上下移 / 删除 / 加一步 / 完成）。数据侧给 steps 补上单条读写，并让「删一步」在一个事务里把待办归属、编号、进度史、`currentStep` 一起收干净。

筛选状态（`filterStep`）与编辑器开合（`flowEditing`）都放进 `ProjectListNotifier`，因为提示行、分段条、编辑器与 B15 的待办列表要读同一份；步骤本身落在 `ProjectListState.detailSteps`，由 `ProjectRepository.load` 一次读回。

## 技术方案

### 数值对照（原型 → 实现）

| 项 | 原型（第六页 CSS / 结构） | 实现 |
| --- | --- | --- |
| 流程区左留 | `.barrow{margin:2px 2px 6px}` | 左右 2、上 2、下 6 |
| 分段条与按钮间距 | `.barrow{gap:12px}` | 12 |
| 分段条 | `.track{display:flex;gap:5px}` | `Row` + 5 间距，段 `Expanded` 等分 |
| 单段 | `height:5px;border-radius:3px;background:var(--track)` | 高 5、圆角 3、`#d8e0ec` |
| 已完成段 | `.track i.done{background:var(--accent)}` | `#2563eb` |
| 悬停 | `.track i:hover{filter:brightness(.94)}` | `Color.lerp(base, Colors.black, .06)` |
| 过渡 | `transition:background .15s,filter .15s` | `AnimatedContainer` 150ms |
| 筛中段 | `outline:2px solid var(--accent);outline-offset:2px` | 外框 2、`BoxDecoration` 双层 |
| 编辑流程键 | `.flowbtn{min-height:26px;padding:0 8px;font-size:12px;color:var(--accent)}` | 26 / 8 / 12 号主色，悬停下划线 |
| 筛选提示行 | `.filtertip{font-size:12px;background:var(--accent-soft);border:1px solid #cfdcfb;border-radius:8px;padding:5px 10px;margin:8px 2px 2px;width:max-content}` | 12 号主色、底 `#eef3fe`、边 `#cfdcfb`、圆角 8、内边距 5/10、上 8 下 2 左右 2、宽随内容 |
| 提示里的 × | `.filtertip button{font-size:13px}` | 13 号主色 |
| 编辑器容器 | `.flowedit{margin:10px 2px 4px;padding:12px 14px;background:#f7f9fd;border:1px solid var(--line);border-radius:12px}` | 同 |
| 编辑器行 | `.fe-row{gap:8px;padding:5px 0}` | 同 |
| 序号 | `.fe-no{flex:0 0 22px;font-size:12px;color:var(--ink3)}` | 宽 22、12 号 `ink3`、等宽 |
| 名称输入 | `.fe-name{height:32px;padding:0 10px;font-size:13px;border:1px solid var(--line2);border-radius:8px}` | 高 32、13 号、边 `line2`、圆角 8、聚焦主色、`maxLength: 12` |
| 小键 | `.fe-mini{height:28px;min-width:28px;padding:0 8px;font-size:12px;color:var(--ink2);border:1px solid var(--line2);border-radius:8px}` | 同；悬停字与边变主色 |
| 底部 | `.fe-foot{margin-top:8px;justify-content:space-between}` | 同 |
| 加一步 | `.fe-add{height:30px;padding:0 12px;font-size:12px;color:var(--accent);border:1px dashed var(--line2);border-radius:8px}` | 同 |
| 完成 | `.fe-done{height:30px;padding:0 14px;font-size:12px;color:#fff;background:var(--accent);border-radius:8px}` | 同 |

### 状态与数据流

`ProjectListState` 增四个字段：

- `detailSteps: List<Step>`：按 `index` 升序，详情页与编辑器都读它；
- `filterStep: int?`：筛中的步骤下标，null 表示不筛；
- `flowEditing: bool`：编辑器是否展开；
- 既有 `detailDoneSteps` / `detailPercent` 继续由 `detailSteps` 推出。

数据流：`open(id)` → `ProjectRepository.load` → `detailSteps` 排序 → `filterStep` 落 `clamp(currentStep)`。写操作（改名 / 移动 / 删除 / 加一步）一律先落库、再 `reload` 这次的 bundle 并重算筛选，界面不做乐观更新，避免库与界面分叉。

`Step` 是 `domain/model/step.dart` 的实体（`id`、`projectId`、`index`、`name`、`state`），不出 data 层。

### 交互时序

- **点段**：`tapSegment(i)` → `filterStep = filterStep == i ? null : i`，不落库。
- **点 ×／再点同段**：清 `filterStep`。
- **点编辑流程**：`flowEditing = !flowEditing`；收起时不动筛选。
- **改名**：输入框 `onSubmitted` / 失焦 → `renameStep(id, text)`；取 `trim`，空则直接返回；成功后 `reload`，失败保留原值。
- **上下移**：`moveStep(id, ±1)` → Repository 事务里交换两步的 `index`、互换各自待办的 `stepId`、互换进度史的 `stepIndex`；返回 `false` 表示已到头，界面不动；成功后 `filterStep = null`。
- **删除**：`deleteStep(id)` → 事务（详见下）→ `reload` → `filterStep = clamp(currentStep)`。
- **加一步**：`addStep()` → 末尾 `index = max + 1`、名「新步骤 N」→ `reload`，`filterStep` 不动。
- **Esc**：`collapse()` 依次判断 `confirming` → `flowEditing` → `openId`，命中哪个就消费哪个，全不命中返回 `false` 交给壳。

### 日期与文案

- 提示行：「第 {index+1} 步 · {name}」，`name` 去空格后为空时写「未命名步骤」。
- 分段段悬停提示与提示行同一口径。
- 编辑键：「编辑流程」/「收起编辑」。
- 加一步的默认名：「新步骤 {新步数}」。
- 序号从 1 起，等宽数字。

### 边界与错误

- 无步骤：分段条不画段（占位撑满），编辑器只有底部一行，加一步可用。
- 删掉最后一步：`currentStep` 回 -1，筛选清空，详情头部进度行显示「0% · 已完成 0/0 步」。
- 删掉当前步但后面还有：`currentStep` 保持原下标（等价于落到原下一步），筛选跟着它。
- 删掉当前步之前的步：`currentStep` 减一，筛选跟着新下标。
- 上下移到头：不写库、不报错、不清筛选（原型此时 `moveStep` 直接 return）。
- 改名撞上限：输入框 `maxLength` 截断，不做二次校验。
- 写库失败：`reload` 后按库里真实值渲染，界面不残留半改状态。
- 步骤被外部删掉（例如 B22 AI 重写流程）后再点移动：Repository 查不到行直接返回，界面 `reload` 收敛。

## 文件结构

```text
app/lib/features/projects/
  project_flow.dart          # 新增：分段条 + 筛选提示行 + 流程编辑器
  projects_notifier.dart     # 改：detailSteps/filterStep/flowEditing 与四个写方法
  project_detail.dart        # 改：头部下方留出流程区（不改头部数值）
  projects_page.dart         # 改：详情列挂流程区，Esc 链交给 collapse
app/lib/data/
  dao/steps_dao.dart         # 改：byId、insertOne、updateRow
  dao/task_items_dao.dart    # 改：clearStep
  dao/progress_entries_dao.dart # 改：shiftAfter
  repository/project_repository.dart # 改：renameStep、addStep、moveStep、deleteStep
app/lib/app/main_shell.dart  # 改：Esc 多问一层
app/test/features/projects/
  projects_flow_test.dart    # 新增：数据与状态机
  projects_page_test.dart    # 改：补流程区界面
```

## 对应需求

| 需求 | 落点 |
| --- | --- |
| FR-01 分段进度条 | `project_flow.dart` 的 `ProjectFlowBar`；`detailSteps` 提供段数与完成态 |
| FR-02 段与筛选 | `ProjectFlowBar` 的 `_Segment` 与 `tapSegment` |
| FR-03 编辑流程按钮 | `ProjectFlowBar` 右侧键，文案跟 `flowEditing` |
| FR-04 筛选提示行 | `ProjectFilterTip`，读 `filterStep` 与 `detailSteps` |
| FR-05 流程编辑器 | `ProjectFlowEditor` 每行 `_StepRow` |
| FR-06 编辑器底部 | `ProjectFlowEditor` 的 `_Foot` |
| FR-07 改步骤名 | `ProjectFlowEditor.onRename` → `Notifier.renameStep` → `ProjectRepository.renameStep` |
| FR-08 上下调序 | `Notifier.moveStep` → `ProjectRepository.moveStep`（事务交换） |
| FR-09 删除步骤 | `Notifier.deleteStep` → `ProjectRepository.deleteStep`（事务） |
| FR-10 加一步 | `Notifier.addStep` → `ProjectRepository.addStep` |
| FR-11 默认筛选 | `Notifier.open` 里的 `clamp` |
| FR-12 Esc 分层 | `Notifier.collapse` 与 `main_shell.dart` 既有调用 |

## 偏差表

| 项 | 原型 / PRD | 实现 | 为什么 |
| --- | --- | --- | --- |
| 已完成段的判定 | 原型按「前 `cur` 段」着色 | 按每步自己的 `state` 着色 | 数据里完成状态可以不连续（B15 允许跳步完成），按步态才不会把没做的段刷成完成 |
| 每行的「新增事项」 | 编辑器每行四枚小键（↑ ↓ 删除 新增事项） | 本块只放三枚，第四枚归 B15 | 这颗键要开行内输入并写待办，B14 里点了没有落点，留个死键更糟 |
| 删步骤后的 `currentStep` | 原型 `cur` 不调整 | 大于被删位置减一、越界收到末位、空则 -1 | 原型 `cur` 是「已完成步数」，我们的 `currentStep` 是「正在推进的下标」，不收敛会指到别的步骤上 |
| 历史编号交换 | 原型用 `forEach` 写副作用 | 事务里显式遍历 | 同样的效果，写成显式循环才看得出改的是哪几条 |
| 详情滚动 | 原型整页 `overflow:auto` | 只滚详情区 | B11 已定，壳不提供整页滚动 |

## 测试

- `projects_flow_test.dart`：`renameStep` 落库与空名保护；`addStep` 末尾编号与默认名；`moveStep` 交换两步的 index / 待办归属 / 进度史编号、到头返回 false；`deleteStep` 的待办转未分配、编号前移、进度史前移、`currentStep` 三种收敛；`open` 的默认筛选三种边界；`collapse` 三层顺序。
- `projects_page_test.dart`：分段条段数与颜色、点段出提示行、点 × 清筛选、编辑流程展开与文案切换、编辑器数值（序号 22、输入 32、小键 28、加一步 30 虚线、完成 30）、改名后提示行同步、删除步骤后步数减少、Esc 三层。
- 断言一律照上表数值写；新增测试与 B01–B13 全量重跑，`dart analyze` 必须干净。
