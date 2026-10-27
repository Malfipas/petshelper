# B21 修正：key 存了之后各页状态不同步

- 日期：2026-10-27
- 范围：设置页存 key 之后，第 2、5、7 页的 AI 入口是否当场跟着变
- 结论：`flutter test` 597 条全过（本次新增 7 条），`dart analyze lib test` 无问题

## 现象

设置页填 key 点保存，退出到想法盒、我的记录，两页的「API key 未配置」提醒都撤掉了；但悬停小面板里「问一问」还是写着未配置、输入框仍然只读。

## 原因

两处各记一份状态，必然对不上：

1. `PanelNotifier` 里 `aiReady` 是写死的 `false`（B09 时 AI 还没接，留的常量），面板从来没读过设置页那份状态。存了 key 之后，别的页读库读到了新值，面板还是老常量。
2. `PanelState.aiReady` 只在 `_apply` 时按那个常量填，页面层也没有 `watch` 全站开关，所以连重进面板都不会变。

## 改法

| 位置 | 改动 |
| --- | --- |
| `features/panel/panel_notifier.dart` | `bool get _aiReady => ref.read(keyConfiguredProvider);`——面板不再自己记，读全站开关 |
| `features/panel/panel_page.dart` | 「问一问」的可用性改成 `ref.watch(keyConfiguredProvider)`，设置页存完当场可写，不必重进面板 |
| `app/key_configured.dart` | `load()` 加 try/catch，并加 `_settled`：用户点过保存（`set(true/false)`）之后，晚到的读库结果不再回写，避免把刚存的状态盖回未配置 |

第三处是关键：`load()` 是异步读库，设置页 `set(true)` 与它可能前后脚落地；谁后到谁说了算的话，会出现「按了保存但几秒后又变回未配置」。现在明确「用户动作优先，读库只填没人表过态的空白」。

## 用例

| 文件 | 条数 | 覆盖 |
| --- | --- | --- |
| `test/features/settings/settings_page_test.dart` | 3（新增） | 没配 key 时按钮区提示未配置、配了 key 时提示消失、在页内保存后提示当场变 |
| `test/features/panel/panel_page_test.dart` | 1（新增） | 配了 key 之后「问一问」输入框当场可写 |
| `test/features/panel/panel_notifier_test.dart` | 3（新增） | 没配 key 时问一句什么都不改也不发请求、配了 key 先出空气泡回来回填、请求失败把原因写进气泡 |

- `flutter test`：**597 条全过**
- `dart analyze lib test`：`No issues found!`

## 附带修掉的一处

写这三条面板用例时撞出另一个真 bug：面板刚打开时会异步重挑事务，若在这几毫秒里问了一句，重挑回来的 `_apply` 整块换新状态，会把刚推上去的空气泡抹掉，答案回来就无处可填。改成重挑事务与回空态时**保留问答记录**（`_withoutTask()` 与 `_apply` 里带上 `answers`），并把这条口径写进 `07-开发.md` 的 `PanelNotifier` 一行。

## 实机

应用要重启才带新代码。核对步骤：设置页存一个 key → 直接悬停唤出面板（不进设置页以外任何页）→「问一问」输入框可写，无「未配置」字样；清除 key → 面板当场回到只读。
