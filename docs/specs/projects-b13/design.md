# B13 我的项目页 · 设计

## 概述

把主界面第 2 标签的 `ComingSoon` 占位换成可用的项目列表与详情外壳：列表态给出一列项目卡片（名与百分比、细进度条、下一步、最近推进）、空态、新建内联表单；点卡片进详情外壳（返回、标题、说明与截止、进度行、删除项目），删除走二次确认。本块覆盖 FR-01 到 FR-12；流程条、待办卡片、进度史与 AI 帮助块不在本块（分别归 B14、B15、B16、B22/B23），但详情区的位置与宽度按原型留好，后续块直接往下接。

## 技术方案

### 数值对照（原型 → 实现）

| 位置 | 原型值 | 来源 | 实现 |
| --- | --- | --- | --- |
| 页头 | `gap 12 / margin-bottom 14`；标题 `16/600`；件数 `12 ink3 / margin-top 4` | 278–280 | `SizedBox(width:12)` + 下留 14；`TextStyle(fontSize:16, fontWeight:600)`；件数 `12 / AppTheme.ink3` |
| 新建键 | `min-height 34 / padding 0 14 / 13 / accent 字 / 白底 / 1px line2 / 圆角 10`；悬停 `accent 边 + accent-soft 底` | 281–283 | `ConstrainedBox(minHeight:34)` + 左右 14 |
| 表单壳 | `margin-bottom 12 / padding 14 16 / #f7f9fd / 1px line / 圆角 12` | 285–286 | 同值 |
| 表单输入 | 高 `38 / padding 0 12 / 14 / 圆角 10`；日期 `高 32 / padding 0 8 / 13 / 圆角 8` | 288–295 | 同值；日期行标签 `13 / ink2`、上留 12 |
| 重名提示 | `12 / #d94a3d / margin-top 6` | 291 | `12 / Color(0xFFD94A3D)` |
| 表单按钮 | `34 高 / padding 0 14 / 13 / 圆角 10 / 间距 8 / margin-top 14`；确定禁用 `opacity .45` | 296–300 | 同值 |
| 卡片 | `margin-bottom 8 / padding 14 18 / 白底 / 1px line / 圆角 12`；悬停 `#b9c8dd` + `0 6 16 rgba(30,50,80,.07)`，`140ms` | 302–304 | `AnimatedContainer` 140ms |
| 卡首行 | 基线对齐 `gap 10`；名 `15/600` 单行截断；百分比 `13 accent tabular-nums` | 305–307 | `Row(crossAxisAlignment: baseline)` |
| 细进度条 | `高 4 / 圆角 2 / 底 #eef1f6 / margin 9 0 8`；填充 `accent` | 308–309 | 同值 |
| 卡末行 | 基线对齐 `gap 12`；下一步 `12 ink2`，事名 `600 + ink`；最近推进 `12 ink3` | 310–313 | 同值 |
| 箭头 | `right 14 / 垂直居中 / #c3ccda / 18 号` | 314 | `Positioned(right:14)` |
| 空态 | `padding 48 0 / 居中 / 13 ink3`；标题 `15 ink2 / 600 / margin-bottom 12` | 315–317 | 同值 |
| 详情头 | `gap 14 / padding 0 2 10` | 319 | 同值 |
| 返回键 | `min-height 32 / padding 0 10 / 13 / ink2 / 白底 / 1px line2 / 圆角 10`；悬停 `accent` | 320–322 | 同值 |
| 详情标题 | `20/600 / line-height 1.3 / max-width 46%` 单行截断 | 325–326 | `ConstrainedBox(maxWidth: 可用宽 × 0.46)` |
| 说明与截止 | `12 ink3 / max-width 210 / 单行截断 / 空则隐藏 / gap 10` | 327–328 | 空串时 `SizedBox.shrink()` |
| 进度行 | `12 ink3 / margin-top 4 / tabular-nums` | 329 | 同值 |
| 删除键 | `32 高 / padding 0 12 / 13 / #d94a3d / 白底 / 1px #f0c9c4 / 圆角 10`；悬停 `#fdf3f2 + #e3a49c` | 330–332 | 同值 |
| 遮罩 | `rgba(24,36,54,.28)` 全屏居中 | 497–499 | `Color(0x47182436)` |
| 弹窗卡 | `宽 360 / padding 20 22 / 白底 / 1px line2 / 圆角 14` | 500–501 | 同值 |
| 弹窗文字 | 标题 `16/600 / 下留 8`；正文 `13 ink2 / line-height 1.7 / 下留 18` | 502–503 | 同值 |
| 弹窗按钮 | `34 高 / padding 0 14 / 13 / 圆角 10 / 间距 8`；确认 `#d94a3d` 实底，悬停 `#c8402f` | 504–508 | 同值 |

### 状态与数据流

```text
ProjectRepository.digests() ─┐
TaskRepository.byProject(id) ─┴→ ProjectListNotifier.reload() → ProjectListState.rows
                                                                 ├─ openId → ProjectRepository.load(openId) → detail
                                                                 └─ confirming → 删除确认弹窗
```

`ProjectRow`（页面只读的视图模型）：

```dart
class ProjectRow {
  final String id;
  final String name;
  final int percent;         // round(doneSteps / totalSteps × 100)，无步骤为 0
  final String nextStep;     // 未完成待办里 orderIndex 最小的一条名；没有为空串
  final int? lastAdvancedAt; // 最近推进；null 表示从没推进
  final int createdAt;
}
```

`ProjectListState`：`rows`、`loading`、`openId`、`detail`（`Project`）、`detailPercent`、`formOpen`、`name`、`description`、`dueAt`、`nameTaken`、`flash`、`confirming`。

| 方法 | 行为 |
| --- | --- |
| `reload()` | 先 `digests()`，再对每个项目 `byProject` 取未完成待办；按创建时间倒序；异步返回时判 `ref.mounted` |
| `open(id)` | `load(id)`，空 bundle 视为项目已消失 → 回列表；成功则 `openId = id` 并记百分比 |
| `back()` | 清 `openId` 与 `detail` |
| `toggleForm(open)` | 开表单时清草稿与重名标记；关时清草稿 |
| `setName/setDescription/setDue` | 只改草稿；`setName` 顺手算 `nameTaken` |
| `create()` | 名称去空格后为空或重名则返回；`ProjectRepository.create(...)`；成功后 `reload()`、`open(新 id)`、清草稿 |
| `askDelete()/cancelDelete()` | 开关确认弹窗 |
| `confirmDelete()` | `ProjectRepository.delete(openId)` → `back()` → `reload()` |
| `collapse()` | Esc 顺序：弹窗开着 → 关弹窗返回 true；详情开着 → 回列表返回 true；否则 false |

百分比在 notifier 里按 `(doneSteps * 100 / totalSteps).round()` 自己算，**不用** `ProjectDigest.percent`——那个是往下取整（`~/`），原型是 `Math.round`：3 步做完 2 步时原型显示 67、它显示 66。

「下一步」取 `byProject` 结果里 `done == false` 且 `orderIndex` 最小的那条；同一次 `byProject` 同时喂给详情用，避免开详情再读一遍。

### 交互时序

- **新建**：点「新建项目」→ `formOpen = true`（表单插在页头与列表之间，列表整体下移，不做浮层）。名称空 → 「确定」置灰；重名 → 置灰并显示红字。点「确定」→ 落库 → 列表刷新 → `openId = 新 id`（自动进空详情）。
- **展开**：点卡片 → `open(id)` → 列表隐去、详情出现在同一位置（不做转场，B24 再谈动效）。
- **返回**：点「← 全部项目」→ `back()`。
- **删除**：点「删除项目」→ `confirming = true` → 遮罩浮层（`Stack` 覆盖整页，点遮罩空白处关闭）→ 「确认删除」→ `delete` + 回列表 + 刷新；「取消」/遮罩/Esc → 只清 `confirming`。
- **Esc**：`MainShell` 在项目页按下时先问 `ProjectListNotifier.collapse()`；返回 true 说明被本页吃掉，false 才收主界面。
- **?id=**：页面初始化读到 `projectId` 非空就 `open(id)`；load 为空则停在列表、不报错。

### 日期与文案

`relativeSince(int? ms, DateTime now)`（顶层纯函数，可单测）：

| 天数差 | 文案 |
| --- | --- |
| ≤ 0 | 今天 |
| 1 | 昨天 |
| 2–6 | N 天前 |
| 7–13 | 一周前 |
| 14–29 | N 周前（7 除） |
| 30–59 | 一个月前 |
| ≥ 60 | N 个月前（30 除） |

与 B12 的 `relativeDay` 同族但去掉「建的」后缀：项目卡片读的是「最近推进：昨天」，不是「昨天建的」。两份函数不合并——一个服务创建时间、一个服务推进时间，混用会在两处同时改口径。

截止文案等价于原型的 `pjFmtDue`：`dueLabel(int ms)` → 「截止 M 月 D 日」，去前导零；`null` 返回空串。

### 边界与错误

- 项目被别处删掉后再点进来：`load` 返回空 bundle → `back()` + 一行 flash「这个项目已经删掉了」。
- 重名判断在 `create()` 前用当前 `rows` 的名字集合比，不做数据库唯一约束（原表没有唯一键，也不为本块加）。
- 删除失败（库异常）：保留详情与弹窗，flash 一行「删除没成功」，不假装删掉。
- 列表为空但表单开着：空态与表单同时出现，空态的新建按钮与页头的新建按钮共用 `toggleForm`。
- 卡片文字超长：项目名与下一步都单行截断，最近推进不缩（`flex: 0 0 auto` 的等价处理）。
- 详情标题 46% 按详情区可用宽算，800 宽窗口下约 340，够放 20 号中文 8 个字；超了截断不换行。

## 文件结构

```text
app/lib/features/projects/
├── projects_notifier.dart   # ProjectRow / ProjectListState / ProjectListNotifier / relativeSince / percentOf / dueLabel
├── projects_page.dart       # 页头、新建表单、列表、空态、删除确认遮罩（替换原 ComingSoon）
├── project_card.dart        # 一行项目卡片
└── project_detail.dart      # 详情头部（B14 起在下面接流程条、待办、进度史）
app/lib/app/
├── router.dart              # _pageOf 透传 ?id=
└── main_shell.dart          # Esc 先问项目页
app/test/features/projects/
├── projects_notifier_test.dart
└── projects_page_test.dart
```

## 对应需求

| 需求 | 设计落点 |
| --- | --- |
| FR-01 | 数值对照「页头」、交互时序与 `projects_page.dart` |
| FR-02 | 数值对照「卡片 / 卡首行 / 细进度条 / 卡末行 / 箭头」、`project_card.dart` |
| FR-03 | 状态与数据流里的 `percentOf` 与 `nextStep` 取法 |
| FR-04 | 日期与文案的 `relativeSince` 七档 |
| FR-05 | 数值对照「空态」、`projects_page.dart` 空态分支 |
| FR-06 | 数值对照「表单壳 / 表单输入 / 表单按钮」、交互时序「新建」 |
| FR-07 | `create()` 与 `nameTaken`、边界「重名判断」 |
| FR-08 | 数值对照「详情头 / 返回键 / 详情标题 / 说明与截止 / 进度行 / 删除键」、`project_detail.dart` |
| FR-09 | 日期与文案的 `dueLabel` |
| FR-10 | 数值对照「遮罩 / 弹窗卡 / 弹窗文字 / 弹窗按钮」、交互时序「删除」 |
| FR-11 | `confirmDelete()` 与 `ProjectRepository.delete` 的事务清理 |
| FR-12 | 交互时序「?id=」与 `open()` |

## 偏差表

| 项 | 原型 | 本块做法 | 原因 |
| --- | --- | --- | --- |
| 列表数据 | 内存 `PJ` 对象，`pjOrder` 把新建的插到最前 | 按 `createdAt` 倒序 | 数据落了库，重启后顺序要稳定；同毫秒按 id 兜底 |
| 百分比来源 | `Math.round(cur/steps.length*100)` | 同公式，但用 `doneSteps` | `cur` 是「走到第几步」，跳着做会虚高；`doneSteps` 与「已完成 3/7 步」同口径 |
| 下一步 | `p.todos[0]`（数组首条） | 未完成待办里 `orderIndex` 最小 | 原型 todos 是演示数据、顺序即数组序；库里有 `orderIndex`，用它才和 B15 排序一致 |
| 最近推进 | 演示数据写死「今天 / 前天」 | 真实时间按相对日期算，空项目取创建时间 | 新项目必须有值，否则文案空一半 |
| 说明与截止 | 两个 `span` 直接拼，靠 `:empty` 隐藏 | 空则不占位 | 等价行为 |
| 空详情 | 打开时有整条流程与待办 | B13 只有头部，进度条与待办由 B14/B15 接 | 分块交付，避免一块吞掉三块的范围 |
| 日期选择 | `input[type=date]` | 点按钮弹系统日期选择器 | Flutter 无原生 date input；选择器关闭即写回 `dueAt` |
| 标题 46% | CSS `max-width:46%` | 按详情区可用宽 46% | 无 CSS 百分比上下文，需显式算 |

## 测试

单元（`projects_notifier_test.dart`，内存库 + 固定时钟）：

1. `relativeSince` 七档；2. `percentOf` 取整与零步骤；3. `dueLabel` 去前导零与空值；4. `reload` 行数据（名、百分比、下一步取 orderIndex 最小未完成、没待办时为空串、创建倒序）；5. 新建空名/重名被拒、正常建成后在最前并自动展开；6. 展开/返回/`collapse` 三态；7. 删除后行消失且关联待办清掉。

界面（`projects_page_test.dart`，整壳装配）：

8. 页头尺寸与件数文案；9. 空态文案与新建入口；10. 表单必填禁用、重名红字、取消不落库；11. 卡片结构（百分比、进度条宽、下一步文案、最近推进）；12. 点卡片进详情、返回键回列表；13. 详情头部数值；14. 删除弹窗文案与两枚按钮，取消后仍在详情；15. 确认删除后回列表且项目没了；16. Esc 先关弹窗、再回列表、最后收壳；17. `?id=` 直接展开与失效 id 落列表。
