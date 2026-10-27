# 交接：第二轮实机回填（截至 2026-10-26）

给下一个接手的 agent。**先读这份，再读 `docs/07-开发.md`（语义源头）、`docs/开发任务拆解.md`（块划分）。`handoff-工程阶段.md` 里的环境与坑仍然有效，不重复。**

## 一句话现状

用户在第二轮实机手动测试后一次性提了 15 条，**代码全部改完**：`dart analyze lib test` 为 `No issues found!`，`flutter test` 398 条全过（本轮新增 1 条字体断言，其余为按新语义重写）。**但收尾没做完**：本块测试留档、总记录行、过程记录 `05-3`、`state/` 下一步、PRD 正文的桌宠左右缘口径都还差，构建与实机复测也没跑。接手第一件事就是把这五件补齐，不要先动新功能。

## 本轮 15 条落在哪

| # | 要求 | 关键落点 |
| --- | --- | --- |
| 1 | 桌宠只做右缘、默认右收起 | `lib/platform/window/window_geometry.dart`（`settlePlacement` 删掉，换纯纵向 `settleAnchorY`）、`pet_window.dart` 只贴右、`lib/app/pet_window_launcher.dart` 不再读写 `PetSide` |
| 2 | 全应用宋体 | `lib/app/theme.dart`：`fontFamily = 'SimSun'`、`fontFamilyFallback = ['宋体','SimSun','NSimSun']`、`textTheme` 走 `Typography.blackMountainView.apply` |
| 3 | 主界面拖动与桌宠拖动拆开 | `PetWindow.beginMainDrag/dragMainBy/endMainDrag`、`PetLayout.withWindow`、`lib/app/main_shell.dart` 的 `_ShellDragBar` 自己收 onPointerMove/Up |
| 4 | 随手记提示改「在此处记录你的成果」 | `lib/features/panel/panel_page.dart` |
| 5 | 独立事项删除加二次确认 | `lib/features/tasks/solo_page.dart` + 新文件 `lib/app/confirm_overlay.dart`（键 `confirm-overlay/ok/cancel`，确认键红底，提示「相关数据将不会被保留」） |
| 6 | 面板中正在显示的独立事项被删后回无事项 | `lib/features/tasks/solo_notifier.dart` 的 `remove()` 里刷新面板 |
| 7 | 累计精确到秒 | `solo_notifier.dart:292` 顶层 `durationText(int seconds)`，`solo_detail.dart` 与面板共用 |
| 8 | 暂停只停表、停止＝停表+完成+回无事项 | `lib/features/panel/panel_notifier.dart:286 pause()`、`:329 stop()`、`:353 settleRunning()`；项目事项停下走 `_advanceTo(projectId)` 摆下一步 |
| 9 | 其他窗口能被点到主界面上层 | `WindowDriver.setAlwaysOnTop`，`pet_window.dart` 在 `setStage` 时 `stage != main` 就置顶 |
| 10 | 项目页不出现「这个项目已经删掉了」、删空态按钮 | `lib/features/projects/projects_notifier.dart` 的 `open()` 缺项目时静默回列表；`projects_page.dart` 去掉 `proj-empty-new` |
| 11 | 项目事项复用独立事项编辑页 | `projects_page.dart` 的 `_taskDetail()` + `ProjectTodoSection(expandedTaskId/onToggleDetail/detailOf)`，同一块 `SoloDetail`，靠 `showDoneHint: false` 关掉完成逻辑 |
| 12 | 撤掉「移到项目」 | 删 `lib/domain/usecase/move_task.dart`，摘 `moveTaskProvider`、`TaskGateway.reassignLogs`、`NoteGateway.moveOwner` 及实现 |
| 13 | 新建项目自带步骤 1 | `lib/data/repository/project_repository.dart:126` `currentStep: const Value(0)` |
| 14 | 截止日期用中文日历 | `main_shell.dart` 挂 `flutter_localizations`（测试断言 `datePickerHelpText == '选择日期'`） |
| 15 | 进度史与时间轴能触发 | `projects_notifier` 勾完成后当场刷新进度史；时间轴与进度史可互切 |

## 已验证 / 未验证

- 已验证：`dart analyze lib test` 干净；`flutter test` **398 passed**（2026-10-26 跑）。
- 未验证：`flutter build windows --debug`、实机起应用、15 条的肉眼验收。

## 下一步（按顺序，别跳）

1. **补留档**：写 `docs/测试结果/B16-修正实机反馈15条.md`（一行一个结果），再往 `docs/测试结果/总记录.md` 的汇总表追加一行（照 2026-10-25 那行的格式）。
2. **过程记录**：`产品生命周期过程记录.md` 追加 `### 任务列表 05-3 · 第二轮实机回填的 15 条（v1.0）`（现有最新是 `05-2`，12 条）；同步 `state/AI桌宠日常助手-产品规划.md` 的「下一步」段。
3. **PRD 正文只留右缘**：`docs/05-定义-PRD.md` 第 282、284、286、330、360 行还在写「左缘 / 左右两侧 / 就近吸附」，要改成只做右缘。第 33 行 `v2.1.9` 是历史版本记录，不动。
4. **注释残留**：`lib/domain/model/note.dart:12`、`lib/data/db/tables/notes.dart:4` 仍写「事项移到项目换 id 时跟着搬」，功能已不存在，改掉。（`projects_notifier.dart:463 moveTask` 是步骤内上下移，跟「移到项目」不是一回事，别误删。）
5. **构建 + 实机**：`flutter build windows --debug`，起应用点一遍 15 条，出第三轮实机表给用户。
6. 之后才回主线：B17 想法盒起，按 `docs/开发任务拆解.md` 走。

## 本轮新增/改写的文件

| 路径 | 是什么 |
| --- | --- |
| `app/lib/app/confirm_overlay.dart` | 新增。页面内二次确认浮层（不用 `showDialog`，跟项目删除确认同一套视觉） |
| `app/lib/platform/window/pet_layout.dart` | `withWindow(Rect next)`、`petLayout(..., windowOverride)`，抽出 `_mainStage` |
| `app/lib/platform/window/pet_window.dart` | 重写：只贴右缘；桌宠拖动与主界面拖动两套；`setStage` 联动置顶 |
| `app/lib/platform/window/window_driver.dart`、`window_manager_driver.dart` | `setAlwaysOnTop(bool)` |
| `app/lib/features/panel/panel_notifier.dart` | `pause` / `stop` / `settleRunning` / `_advanceTo` 语义全改 |
| `app/lib/features/projects/projects_notifier.dart` | `askTaskDelete` / `confirmTaskDelete` / `toggleTaskDetail` / `autoSaveTask` / `saveTask` / `readNote` |
| `app/lib/features/projects/projects_page.dart` | 项目待办展开成 `SoloDetail`、删除二次确认、去掉失效提示与空态按钮 |
| `app/lib/features/tasks/solo_page.dart`、`solo_detail.dart`、`solo_notifier.dart` | 删除二次确认、`durationText`、去掉 `onMove`/`projects` |
| `app/lib/app/theme.dart`、`main_shell.dart` | 宋体统一、中文本地化 |
| `app/lib/domain/usecase/move_task.dart` | **已删除** |
| `app/test/**` | 受影响断言按新语义重写；`test/platform/window/pet_window_test.dart` 整份重写；`test/app/theme_test.dart` 补字体断言 |

## 别推翻的定义（本轮定死）

- 桌宠**只有右缘**，默认收起态；左缘不做，设置里的左/右档已无用（`PetSide` 只剩历史含义）。
- 「暂停」= 停表等继续（独立事项页那一格勾选框转黄）；「停止」= 停表 + 标完成 + 面板回无事项。累计到秒，不再「最少 1 分钟」。
- 「移到项目」整条不存在：用例、Provider、两个 Gateway 方法、菜单、测试都删了。
- 新建项目一定自带「步骤 1」；项目事项做完摆下一步，不写「明天自动移出」。
- 项目页任何时候不出现「这个项目已经删掉了」。

## 坑（本轮踩到的）

- `flutter analyze` 在这台机器会崩，一律用 `dart analyze`。
- 删用例文件后忘了摘 `app/providers.dart` 的 import，编译才报错——删用例要连带扫 Provider 与端口。
- 项目事项复用 `SoloDetail` 时必须关 `showDoneHint`，否则会露出只该属于独立事项的完成逻辑。
- 进度史「当场冒出一条」的测试要等落库，`pump(700ms)` 才稳；断言用 `detailProgress.length` 比文本稳。
- PowerShell 读写中文路径：用绝对路径，`[Text.UTF8Encoding]::new($false)` 写回，别用相对路径拼 cwd。

## 建议下一轮调用的 skill

| skill | 什么时候用 |
| --- | --- |
| `flutter-apply-architecture-best-practices` | 动分层、Provider 装配、新页面结构前读 |
| `dart-add-unit-test` / `flutter-add-widget-test` | 补 B17 起的新块测试前读 |
| `dart-run-static-analysis` | 改完跑 `dart analyze` 前读 |
| `dart-use-pattern-matching` | 改 `sealed` 结果类型、解析分支时读 |
| `flutter-fix-layout-issues` | 复现溢出、无界约束时读 |
| `lieflat-less-ai-tone` | 写进文档的段落过一遍去 AI 味 |
| `adhd-friendly-output` | 每轮回复，结论先行、能直接看效果 |
| `mcp-probe-kit` | 要跑完整交付编排（Plan→实现→测试→converge）时调 |

## 用户背景

软件工程大四，自述 ADHD，产品自用兼简历项目。要能真用起来、能直接看效果，不接受只有文字描述；被糊弄过几次，对空泛表述极敏感，要用数字和证据说话。每条反馈都要落到「改了什么、在哪、测了几条」。
