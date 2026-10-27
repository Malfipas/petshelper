# B11 主界面壳与五标签 · 任务

状态：已完成

## 交付物清单

- `app/lib/app/main_shell.dart`：标签换态改成 150ms 过渡（白底、边、影、字色），壳结构与路由不动。
- `app/test/app/main_shell_test.dart`：4 条标签像素断言改读 `AnimatedContainer`；新增悬停、点桌宠收起 2 条。
- `app/test/app/router_test.dart`：新增「重开回独立事项」1 条。
- `docs/测试结果/B11-主界面壳与五标签.md`：结果与数值对照、偏差、排错。
- `docs/测试结果/总记录.md`：追加一行。
- 文档同步：`docs/07-开发.md` 的 `main_shell.dart` 职责、`docs/开发任务拆解.md` B11 段、`state/AI桌宠日常助手-产品规划.md` 下一步、`产品生命周期过程记录.md`。

## 任务列表

- [x] T1 回原型 216–235 行与 PRD 399–438 行逐项量数，结果写进 `design.md` 核对表
- [x] T2 `_TabButton` 换态加 150ms 过渡：白底与边影挪进 `AnimatedContainer`，文字包 `AnimatedDefaultTextStyle`，关水波与 hover 遮罩
- [x] T3 既有 4 条标签像素断言改读 `AnimatedContainer`，数值不变，补时长断言
- [x] T4 新增「悬停只提字色」测试
- [x] T5 新增「点展开态桌宠收起」测试
- [x] T6 新增「重开回独立事项」测试
- [x] T7 `dart analyze` 无问题，`flutter test` 263 条全过
- [x] T8 写 `docs/测试结果/B11-主界面壳与五标签.md`，往总记录追一行

## 需求覆盖矩阵

| 需求 | 实现位置 | 测试 |
| --- | --- | --- |
| FR-01 壳尺寸 | 窗口层 `mainBounds`（既有） | `pet_layout_test` / `pet_window_test`（既有） |
| FR-02 壳外观 | `MainShell` 的 `Container`（既有） | `main_shell_test` 壳像素断言（既有） |
| FR-03 标签排 | `MainShell` 的 `Row` + `MainTab`（既有） | `main_shell_test` 顺序与间距（既有） |
| FR-04 三种态 | `_TabButton`（既有，悬停与选中） | `main_shell_test` 选中/未选中（既有）+ 悬停（新增 T4） |
| FR-05 换态过渡 | `_TabButton`（T2） | `main_shell_test` 时长断言（T3） |
| FR-06 尺寸与命中 | `_TabButton` 的 `constraints` / `padding`（既有） | `main_shell_test` 38/20/12（既有）+ 点整块切页（既有） |
| FR-07 页面纸 | `MainShell` 的 `main-sheet`（既有） | `main_shell_test` 页面纸断言（既有） |
| FR-08 收起与重开 | `MainShell` 的 `Focus` / `PetOnMain` / `onOpenMain`（既有） | Esc（既有）+ 点桌宠收起（T5）+ 重开回独立事项（T6） |
| FR-09 切页与深链 | `MainTab` / `router.dart`（既有） | `router_test` 五页直达与兜底（既有） |

## 文件变更清单

| 文件 | 动作 |
| --- | --- |
| `app/lib/app/main_shell.dart` | 改：`_TabButton` 换态过渡 |
| `app/test/app/main_shell_test.dart` | 改：4 条断言改读 `AnimatedContainer`；增：悬停、桌宠收起 |
| `app/test/app/router_test.dart` | 增：重开回独立事项 |
| `docs/测试结果/B11-主界面壳与五标签.md` | 新建 |
| `docs/测试结果/总记录.md` | 追加一行 |
| `docs/07-开发.md` | 改：`main_shell.dart` 职责补过渡与偏差 |
| `docs/开发任务拆解.md` | 改：B11 段补校准结论 |
| `state/AI桌宠日常助手-产品规划.md` | 改：下一步 |
| `产品生命周期过程记录.md` | 增：v60.0 |
