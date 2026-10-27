# 交接：工程阶段（截至 2026-10-23）

给下一个接手的 agent 看。原型阶段已收尾（八页原型合并进 `prototype/整体原型.html`，产品定义见 `docs/05-定义-PRD.md`），现在进入写代码。**先读这份，再读 `docs/开发任务拆解.md` 和 `docs/07-开发.md`。**

## 一句话现状

工程骨架（B01）和数据库层（B02）已完工，测试 17 条全过，应用能开机建库。技术栈定了：Flutter Windows 首发 + Riverpod + drift/SQLite + 直连 AI。下一步做 B03 Repository 与 DAO。falcon MCP 因缺凭证还没用上；仓库已 `git init` 但没提交。

## 文件地图

| 路径 | 是什么 |
| --- | --- |
| `app/` | Flutter 工程（只含 Windows 平台），包名 `ai_pet_assistant`，organization `com.aipet` |
| `app/lib/main.dart` | 入口：启动 `AppDb.open()` 再 `runApp`，目前只挂空壳 `AiPetApp` |
| `app/lib/app/theme.dart` | 设计令牌：主色 `#2563EB`、浅底 `#EEF3FE`、墨色三档、圆角四档 18/14/12/10、字号五档 18/15/13/12/11 |
| `app/lib/data/db/app_db.dart` | `AppDb` 数据库类，`schemaVersion = 1`，`open()` 落盘到文档目录下的 `app.db` |
| `app/lib/data/db/tables/` | 十二张表的 Table 定义（projects、steps、task_items、notes、time_logs、daily_records、ideas、categories、chat_messages、progress_entries、revisions、settings） |
| `app/lib/data/db/migrations/migrations.dart` | 迁移规矩：只加不改不删、每步幂等，留了 v1→v2 样板 |
| `app/lib/` 其余 | 六层目录骨架（app/domain/model/domain/usecase/data/dao/data/repository/platform/ai/features/*），空目录用 `.gitkeep` 占位 |
| `app/test/` | 测试（B01 的 theme_test/structure_test/smoke_test + B02 的 data/db/app_db_test） |
| `app/pubspec.yaml` | 依赖：drift、sqlite3_flutter_libs、path_provider、path；dev：drift_dev、build_runner、flutter_lints |
| `docs/07-开发.md` | 技术选型与类设计的最终结论 |
| `docs/开发任务拆解.md` | 24 个任务块 B01–B24 + 覆盖矩阵 + 测试留档规矩 |
| `docs/测试结果/` | `B01-建工程与目录骨架.md`、`B02-数据库建表与迁移.md`、`总记录.md` |
| `产品生命周期过程记录.md` | 过程档案，最新版本 v48.0 |
| `state/AI桌宠日常助手-产品规划.md` | 恢复入口，每次接手先读这个 |
| `handoff-原型阶段.md` | 原型阶段的交接，含视觉既定项；动到原型时要读 |
| `.mcp-probe-kit/plans/feature-b01-project-skeleton-steady-3f5ec7f914.json` | mcp-probe-kit 的 Plan 检查点 |

## 环境（接手先确认）

| 项 | 状态 |
| --- | --- |
| Flutter 3.47.7（Dart 3.13.5） | 装在 `D:\flutter`，已写进**用户** PATH（`D:\flutter\bin`）；当前 shell 若 PATH 没刷新，调用时用全路径 `D:\flutter\bin\flutter.bat` |
| Visual Studio 2022 Build Tools 17.14.42 | 装在 `D:\VS`，含「使用 C++ 的桌面开发」工作负载；`flutter build/run windows` 依赖它 |
| 数据库文件 | 落在 `D:\我的文档\app.db`（这台机器「文档」目录被重定向到 `D:\我的文档`，不是 `C:\Users\…\Documents`） |
| Git | 已 `git init`，写了 `.gitignore`（忽略 build/、.dart_tool/、docs/history-session/、.mcp-probe-kit/plans/、原型 pycache）；**尚未首次提交** |
| falcon MCP | 未用，等用户给 policyID / authToken；`docs/` 里可能有课程要求待整合 |
| mcp-probe-kit | 可用，Plan 检查点已建（feature-b01-project-skeleton-steady-3f5ec7f914） |

实测坑：
- `flutter analyze` 这个环境会崩（分析服务器读中文路径报 JSON 解析错），改用 `D:\flutter\bin\dart.bat analyze` 正常。`flutter test` / `flutter build` 正常。
- `path_provider` 解析到的文档目录是 `D:\我的文档`，搜数据库文件要按这个路径。

## 已定的东西（别推翻）

- **技术栈**：Flutter（Windows 首发，不写其他平台）、Riverpod（状态）、drift + SQLite（数据，drift 包在 SQLite 上）、AI 直连（阶段 4 前临时用浏览器抓页面，阶段 4 起直连）、窗口贴边/托盘/开机自启（Windows 原生）。
- **架构分层**（见 `docs/07-开发.md`）：界面只认 Repository，Repository 在 B03 起才出现，换存储不动界面。目录已按这个建好，别打乱。
- **不破坏既有原型的功能约定**：圆角一档（壳18/页14/卡12/钮10）、尺寸比例、浮层以宠图本身为基准、标签顺序（独立事项/我的记录/我的项目/想法盒/设置）、AI 未配 key 时入口只读禁用——这些在 `handoff-原型阶段.md` 的「已定的东西」里，改界面前先读。
- **B02 数据库字段语义**：独立事项与项目待办合成 `task_items` 一张表（scope 区分）；`notes` 按 ownerType+ownerId 挂；`ideas.classifiedAt` 为空才送 AI 归类（每条只分一次）；`daily_records.summaryEditedAt` 有值表示用户改过、AI 不再覆盖；`settings` 只有一行 id=`app`，只记 key 配没配，API key 本身存系统安全存储不在表里。
- **列名陷阱**：drift 的 `Table.text()` 是方法，表列不能叫 `text`，`chat_messages`/`progress_entries` 已改名为 `content`。
- **迁移 SQL 必须写全 `ADD COLUMN`**，`ADD COL` 会被 SQLite 误解析成列名 `COL`。

## 没解决的问题（接手先看这两条）

1. **falcon MCP 未接入**：用户要求用它读课程要求整合进 B01，但一直没给凭证。拿到 policyID/authToken 后调用 `getPolicy` / `getSubmission`，把课程约束落到 `docs/` 或 ADR。
2. **主界面标签与页面重复**：`handoff-原型阶段.md` 提的遗留项——「我的记录/想法盒/设置」既是标签又是独立页（第 5/7/8 页）。B11、B17–B19、B20、B21 动手前要先定是收进标签还是标签只做入口。
3. **Git 没提交**：目前工作区脏着，接手若要做首次提交先跟用户确认（按规矩 commit 需显式授权）。

## 下一步

**B03 Repository 与 DAO**：基于 B02 十二张表写 Repository 层（每张表一个 DAO + 一个 Repository，封装 CRUD），让后续功能块只认 Repository。完成后写测试（覆盖 CRUD 与各表语义，如 task_items 的 scope 区分、notes 的 owner 挂接），并把 B01、B02 的测试重跑一遍，结果逐行留档到 `docs/测试结果/B03-Repository与DAO.md`。具体产出与完成判定见 `docs/开发任务拆解.md` 的 B03。

越往后块重跑面越大（B24 要重跑 B01–B23 全部），测试要尽早稳定。

## 干活规矩（用户反复强调过）

- **测试留档规矩**：每完成一个任务块，①跑本块测试全过；②把编号更小的所有块测试全部重跑；③逐行（一行一个结果）写进 `docs/测试结果/Bxx-*.md`；④汇总一行进 `docs/测试结果/总记录.md`。三样齐才算完成。
- **每轮回复开头写明是否调用了 skill**（用的哪个），末尾报版本记录（记了的话报记录名）。
- **每条改动在 `产品生命周期过程记录.md` 追加版本号**（当前最新 v48.0），并同步 `state/AI桌宠日常助手-产品规划.md` 的「下一步」。
- **`state/` 与旧 `handoff-*.md` 是历史快照，只读**；这份 `handoff-工程阶段.md` 是给下一个 agent 的，更新它没问题。
- 文案写完过一遍 `lieflat-less-ai-tone` 去 AI 味；用户对被糊弄、自造术语、无数字指标容忍度极低。
- 注意 `.agents/skills` 下有 `flutter-apply-architecture-best-practices`、`dart-run-static-analysis`、`dart-add-unit-test`、`mcp-probe-kit`、`huashu-design` 等，写 Flutter/Dart 前先读对应的。
- `flutter analyze` 在本机会崩，改用 `dart analyze`（全路径 `D:\flutter\bin\dart.bat analyze`）。

## 建议下一轮调用的 skill

| skill | 什么时候用 |
| --- | --- |
| `flutter-apply-architecture-best-practices` | 写 Flutter 工程结构、分层、状态管理前读 |
| `dart-run-static-analysis` | 改完跑 `dart analyze` 前读 |
| `dart-add-unit-test` | 给某个块加测试前读 |
| `mcp-probe-kit` | 要跑完整交付编排（Plan→check_spec→实现→测试→review→converge）时调 |
| `huashu-design` | 改/补原型页面时读 |
| `lieflat-less-ai-tone` | 写进文档的段落，过一遍去 AI 味 |
| `adhd-friendly-output` | 每轮回复都要，结论先行、能直接看效果 |

## 用户背景

软件工程大四，自述 ADHD，产品自用兼简历项目。定位「你的外置大脑，让你在该做的事上轻松迈出第一步」。要能真用起来、能直接看效果，不接受只有文字描述；被糊弄过几次，对空泛表述很敏感，要用数字和证据说话。
