# B12 独立事项页 · 任务

状态：已完成（2026-10-24，286 条通过，`dart analyze` 干净）

## 交付物清单

- `app/lib/features/tasks/solo_notifier.dart`：列表状态、排序与次日移出、增删改、自动保存、保存提示、开始/完成/移动命令。
- `app/lib/features/tasks/solo_page.dart`：标题排、新建表单、列表与空态，页面内滚动。
- `app/lib/features/tasks/solo_row.dart`：行头、18 像素三态多选框、开始/走秒/已完成三种右侧按钮、当前角标。
- `app/lib/features/tasks/solo_detail.dart`：虚线、计时行、名称/说明/随手记、保存/删除/移到项目、已完成提示。
- `app/lib/features/pet/pet_notifier.dart`：加 `openPanel()`。
- `app/lib/app/main_shell.dart`：Esc 先收详情再收壳。
- `app/lib/app/theme.dart`：加暖色两档。
- `app/test/features/tasks/solo_notifier_test.dart`、`solo_page_test.dart`，壳的 Esc 测试补在 `main_shell_test.dart`。
- `docs/测试结果/B12-独立事项页.md`、总记录一行。
- 文档同步：`docs/07-开发.md`、`docs/开发任务拆解.md` B12 段、产品规划、生命周期记录。

## 任务列表

- [x] T1 写三份规格（requirements / design / tasks），`check_spec` 通过
- [x] T2 `AppTheme` 补 `warm`、`warmSoft`；`PetNotifier.openPanel()`
- [x] T3 `SoloListNotifier`：取数与排序、当日完成过滤、相对时间与分钟规则、新建、完成/退回、删除、移动、自动保存与保存、flash、展开收起
- [x] T4 `solo_row.dart`：18 三态框、42% 名称列、说明占位、当前角标与竖条、32/88 按钮三态、140ms 换色
- [x] T5 `solo_detail.dart`：虚线、计时行、三个输入与 600ms 防抖、保存/删除/移到项目、已完成提示
- [x] T6 `solo_page.dart`：标题 16/600 + 新建键 + 新建表单（名称必填、40 上限）、空态、列表滚动、点开始收壳进面板
- [x] T7 `main_shell.dart`：Esc 先问详情
- [x] T8 Notifier 测试 12 条（固定时钟 + 内存库，含排序、相对日期、分钟数三条纯函数）
- [x] T9 页面测试 11 条（页头与空态、新建、42% 列宽与行高、三态、展开互斥、自动存与保存、删除、移动、走秒与暂停、点开始进面板）
- [x] T10 壳测试 1 条（Esc 先收详情再收壳，写在 `solo_page_test.dart` 里与页面共用整壳装配）
- [x] T11 `dart analyze` 干净、`flutter test` 全量重跑（286 条）
- [x] T12 写结果留档与五处文档同步

## 需求覆盖矩阵

| 需求 | 实现位置 | 测试 |
| --- | --- | --- |
| FR-01 页面骨架 | `solo_page.dart` 标题排 + `Expanded(ListView)` | 8 |
| FR-02 新建 | `solo_page.dart` `_NewForm`；`notifier.create` | 9 |
| FR-03 行的结构 | `solo_row.dart` | 10 |
| FR-04 多选框三态 | `solo_row.dart` `_CheckBox`；`notifier.toggleDone` | 2、10 |
| FR-05 名称与元信息 | `solo_row.dart` + `notifier` 的 `relativeDay` / `minutesLabel` | 1、10 |
| FR-06 当前与按钮 | `solo_row.dart` 读 `panelNotifierProvider` | 10、12 |
| FR-07 点开始 | `notifier.start` → `panel.setCurrentTask/start` → `pet.openPanel` → `go('/pet')` | 12 |
| FR-08 展开详情 | `solo_notifier.openId` + `solo_detail.dart` | 7、11 |
| FR-09 编辑与保存 | `solo_detail.dart` 防抖 + `notifier.autoSave/saveNow` | 4、5、11 |
| FR-10 删除、移动、完成 | `notifier.remove/move/toggleDone`；`MoveTask`、`FinishTask` | 2、3、6 |
| FR-11 Esc 先收详情 | `main_shell.dart` | 13 |
| NFR-01 不新增表 | 只用既有 Repository 与用例 | 全部 |
| NFR-03 不自己算当前事务 | 读 `panelNotifierProvider` | 12 |

## 文件变更清单

| 文件 | 动作 |
| --- | --- |
| `app/lib/features/tasks/solo_notifier.dart` | 新建 |
| `app/lib/features/tasks/solo_page.dart` | 重写（原为 ComingSoon） |
| `app/lib/features/tasks/solo_row.dart` | 新建 |
| `app/lib/features/tasks/solo_detail.dart` | 新建 |
| `app/lib/features/pet/pet_notifier.dart` | 改：加 `openPanel()` |
| `app/lib/app/main_shell.dart` | 改：Esc 先问详情 |
| `app/lib/app/theme.dart` | 改：加 `warm`、`warmSoft` |
| `app/test/features/tasks/solo_notifier_test.dart` | 新建 |
| `app/test/features/tasks/solo_page_test.dart` | 新建 |
| `app/test/features/tasks/solo_page_test.dart` | 含壳的 Esc 两条（与页面共用整壳装配） |
| `docs/测试结果/B12-独立事项页.md` | 新建 |
| `docs/测试结果/总记录.md` | 追加一行 |
| `docs/07-开发.md` | 改：五页实现状态与文件树 |
| `docs/开发任务拆解.md` | 改：B12 段补校准结论 |
| `state/AI桌宠日常助手-产品规划.md` | 改：下一步 |
| `产品生命周期过程记录.md` | 增：v61.0 |
