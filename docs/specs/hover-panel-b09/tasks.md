# B09 悬停小面板 · 任务

> 状态：已完成（2026-10-24）。结果见 [B09-悬停小面板.md](../../测试结果/B09-悬停小面板.md)。

## 交付物清单

| 交付物 | 位置 |
| --- | --- |
| 面板状态 | `app/lib/features/panel/panel_notifier.dart` |
| 面板界面 | `app/lib/features/panel/panel_page.dart` |
| 接入常驻页 | `app/lib/features/pet/pet_page.dart`（`_PanelSurface` 换成 `PanelPage`） |
| 状态测试 | `app/test/features/panel/panel_notifier_test.dart` |
| 界面测试 | `app/test/features/panel/panel_page_test.dart` |
| 结果留档 | `docs/测试结果/B09-悬停小面板.md` |

## 任务列表

### T1 状态与选事务

- [x] T1-1 `PanelKind` / `PanelState` / `PanelAnswer` / `PanelNotifier` 骨架
- [x] T1-2 `refresh()`：digests → 项目待办 → 独立事项 → 空态
- [x] T1-3 `setCurrentTask(id)`：切事务，切前落盘上一件
- [x] T1-4 `draftScratch` / `commitScratch`
- [x] T1-5 `finish()` 走 `FinishTask` 并刷新
- [x] T1-6 `ask()` 在 `aiReady == false` 时不动状态

### T2 界面

- [x] T2-1 `PanelPage` 三种形态
- [x] T2-2 流程轴：等分段、亮段数 = 当前步
- [x] T2-3 随手记块：标签 + 单行输入，失焦落盘
- [x] T2-4 问一问块：只读态 + 禁用发送键 + 说明文字
- [x] T2-5 动作区：`开始`（禁用）与 `标记完成`
- [x] T2-6 数值照 `design.md` 的对照表

### T3 接入与测试

- [x] T3-1 `pet_page.dart` 换用 `PanelPage`
- [x] T3-2 `panel_notifier_test.dart`：空态、形态 A、形态 B、切事务带草稿、完成换下一件、`ask` 不改状态
- [x] T3-3 `panel_page_test.dart`：文案、段数与亮段、字号与内边距、禁用态
- [x] T3-4 `pet_page_test.dart` 补一条：悬停出面板后能看到项目名与当前步

### T4 收尾

- [x] T4-1 `dart analyze` 零问题
- [x] T4-2 `flutter test` 全过（含 B01–B08 重跑，共 240 条）
- [x] T4-3 `docs/测试结果/B09-悬停小面板.md` + `总记录.md` 追加一行
- [x] T4-4 更新 `docs/开发任务拆解.md`、`docs/07-开发.md`

## 需求覆盖矩阵

| 需求 | 实现 | 验证 |
| --- | --- | --- |
| FR-01 三种形态 | `panel_page.dart` 的三种形态分支 | `panel_page_test`：形态 A / 形态 B / 空态各一条 |
| FR-02 流程轴 | `_Track` 组件 | `panel_page_test`：段数 7、亮段 3 |
| FR-03 随手记 | `draftScratch`/`commitScratch` + 输入框 | `panel_notifier_test`：切事务带草稿；`panel_page_test`：失焦落盘 |
| FR-04 问一问 | 输入框只读 + 禁用键 | `panel_page_test`：只读与禁用断言 |
| FR-05 勾完成 | `finish()` → `FinishTask` | `panel_notifier_test`：完成换下一件、空态 |
| FR-06 选事务 | `refresh()` / `setCurrentTask` | `panel_notifier_test`：三种来源各一条 |
| FR-07 悬停不打断 | 沿用 B08 作用域，`AbsorbPointer` 不开 | `pet_page_test`：悬停后仍在面板档 |
| FR-08 Esc 收起 | 沿用 `pet_page` 已有键盘处理 | `router_test` 已有；`pet_page_test` 补一条 |
| FR-09 视觉 | `panel_page.dart` 常量 | `panel_page_test`：内边距、字号、段高、圆角 |
| FR-10 分层 | import 约束 | `architecture_test` 已有分层断言；本块新增文件按规则不引 drift |
| NFR-01 无阻塞 | `refresh()` 异步、失败保空态 | `panel_notifier_test`：库抛错仍为空态 |
| NFR-02 可测 | 端口注入 | 全部测试用假端口 |
| NFR-03 无定时器 | 不引入 Timer | 代码审查 |
| NFR-04 注释 | 中文 `///` | 代码审查 |

## 文件变更清单

| 文件 | 变更 |
| --- | --- |
| `app/lib/features/panel/panel_notifier.dart` | 新增 |
| `app/lib/features/panel/panel_page.dart` | 重写（原先是占位） |
| `app/lib/features/pet/pet_page.dart` | 改 `_PanelSurface` |
| `app/lib/app/router.dart` | `AppRoutes.panel` 的 builder 包 `KeyedSubtree`，地址直达也有 `page-panel` 键 |
| `app/test/features/panel/panel_notifier_test.dart` | 新增 |
| `app/test/features/panel/panel_page_test.dart` | 新增 |
| `app/test/features/pet/pet_page_test.dart` | 追加用例 |
| `docs/测试结果/B09-悬停小面板.md` | 新增 |
| `docs/测试结果/总记录.md` | 追加一行 |
