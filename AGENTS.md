<!-- mcp-probe:context begin — auto-generated; re-run init_project_context updates this block only -->
<!-- mcp-probe:context-version: 4.1.1 -->
## MCP（必须先调）
需已配置 mcp-probe-kit。写代码前先读 Skill：@.agents/skills/mcp-probe-kit/SKILL.md（或 [MCP 调用时机](.agents/skills/mcp-probe-kit/SKILL.md)）（首次 MCP 调用自动创建 Skill 文件）。

- 用户只说“继续 / 开始 / 往下做” → **先调用 `resume_plan`**；已知 `plan_id` 则传入，未知则只传 `project_root` 自动恢复最近的 active/blocked Plan；未确认无可恢复 Plan 前，禁止先用 Bash 探索、调用 `workflow` 或重新调用 `start_*`；恢复成功且 `mustContinue=true` 后禁止只汇报“已恢复”，必须立即执行 `nextStep/nextTool`，每步后调用 `plan_heartbeat`，直到阻断、取消或收敛
- 不确定用哪个 MCP → `workflow`（只返回工具选择指南；由 Agent 自己判断，必要时再澄清）
- 当前会话看不到 MCP 工具 → 读取 Skill 的“执行通道与自动降级”，通过 `.mcp-probe-kit/bin/probe.*` 调用同版本 CLI；不要要求用户安装
- 新功能 → `start_feature`（会先搜记忆）
- Bug → `start_bugfix`（会先搜记忆）
- UI → `start_ui`（会先搜记忆）
- 不熟代码 / 影响面 → `code_insight`（context / impact / auto）
- 缺上下文 → `init_project_context`
- 提交 → `gencommit`

上下文：写代码前先读 [project-context](./docs/project-context.md)（链到 `docs/project-context/` 各文档）
图谱：大改前读 [latest](./docs/graph-insights/latest.md)；过期 `code_insight` mode=auto save_to_docs=true
会话历史（默认开启；`MCP_HISTORY_SESSION=0|false|off` 关闭；详见 Skill「History Session 读写规则」）：
- **写**：新对话先 `history_session_bootstrap`（无宿主 key 时服务器铸 `hs_<uuid>` 开新档，禁止写入共享 `project-active`）；每轮最终回复前 `history_session_checkpoint`（必须回传上次 `session_key`/`expected_path` + `raw_user_input`/`user_intent`）
- **检查点最低清单**：`findings`/`decisions`/`files_changed`/`tests`/`runtime_state`/`next_actions` 须写满（无内容用明确占位句，禁止空数组交差）
- **读**：先用 bootstrap 有界 state；精确旧上下文再 `history_session_search` → `history_session_read`；不要全量灌历史
- 档案在 `docs/history-session/`（应 `.gitignore`，勿提交）；超行数/字节软轮转；与 Memory/Qdrant 分离；“继续”有 Plan → 仍先 `resume_plan`
记忆（需 MEMORY_QDRANT_URL 等已配置）：
- 检索：`start_*` 命中后**自动注入**历史经验全文；中途补查可用 `search_memory`；单条精读仍可用 `read_memory_asset`
- 沉淀：跨仓库共享**勿填** source_project/source_path；路径写进 content；summary 写检索关键词
- 修正：已有资产可用 `update_memory_asset` 按 asset_id 原地更新（保留 ID）
- 清理：过时/错误/重复沉淀可用 `delete_memory_asset`（删除前建议 `read_memory_asset` 确认）
- Bug 每轮验证后先准备成功/失败/证伪/回归候选并写入 `plan_heartbeat`；`converge` 通过后再 `memorize_asset`
- 功能/UI 验证后先准备候选并写入 `plan_heartbeat`；`converge` 通过后再 `memorize_asset` type=`pattern`/`component`
<!-- mcp-probe:context end -->

<!-- 以下为人工维护的代码规则，mcp-probe 只改上面那个块，不要动这里 -->

## 代码规则（改代码前先看这一节）

### 分层与依赖方向

六层，依赖只能自上而下：

```text
app/        壳、路由、主题、ProviderScope、依赖注入
features/   按八页切：pet、panel、tasks、records、projects、ideas、settings
domain/     实体、用例、端口（纯 Dart）
data/       drift 数据库、DAO、Repository 实现、迁移、行映射
platform/   窗口、托盘、自启、安全存储、通知
ai/         客户端、提示词、结构化解析、降级
```

- `domain/` 不 import Flutter，不 import drift，不 import `data/`、`features/`、`app/`。用例要读写数据时，在 `domain/port/` 定义窄接口，由 `data/repository/` 实现。
- `features/` 只经 Repository 或 Notifier 取数，不 import drift，不直接 `select`/`insert`。
- 只有 `data/` 能 import `package:drift` 与 `data/db/`。drift 的行类型（`db.Project` 这类）不出 data 层，出层前一律经 `data/mapping/row_mappers.dart` 转成 `domain/model/` 的实体。
- `platform/` 只做系统能力，不写业务判断；`ai/` 只做模型调用与解析，不认识表结构。
- 换平台时只该动 `platform/`；换存储时只该动 `data/`。动到别处说明分层错了。

### 状态管理

- 统一用 **flutter_riverpod**：`Notifier`/`NotifierProvider` 管页面状态，`Provider` 注入 Repository 与用例，`ref.watch` 读、`ref.read` 调。
- 一个页面一个 Notifier，命名 `<页>Notifier`（`PetNotifier`、`PanelNotifier`、`SoloListNotifier`、`RecordCalendarNotifier`、`ProjectListNotifier`、`IdeaBoxNotifier`、`SettingsNotifier`）。
- 不引第二套状态管理（Bloc、Provider、GetX 都不加）。界面内部的一次性小状态（悬停、动画、展开）用 `StatefulWidget` 本地状态，不进全局。
- 依赖在 `app/providers.dart` 一处装配，界面里不 `new AppDb()`、不 `new Repository()`。
- 路由统一 **go_router**：地址只写在 `app/router.dart` 的 `AppRoutes` 与 `app/main_shell.dart` 的 `MainTab.path`，界面里不手写 `'/main/xxx'` 字符串，跳转用 `context.go(...)`。
- 注：`flutter_riverpod`、`go_router` 已在 `app/pubspec.yaml`，不许再引别的状态管理或路由包顶上。

### 命名

- 文件：`snake_case.dart`；目录按层与页面切，不用大驼峰。
- 类：`PascalCase`。实体不带后缀（`Project`、`TaskItem`），用例是动词短语（`StartTask`、`MoveTask`），Repository 与 DAO 带后缀（`TaskRepository`、`TaskItemsDao`），端口是名词加 `Gateway`/`Service`。
- 方法：`camelCase`，读用名词（`solo()`、`byDate()`），写用动词（`setDone()`、`markClassified()`），流用 `watch` 前缀（`watchSolo()`）。
- 表名复数、列名 `snake_case`；一个 owner 只有一个的用 `xxxId`，时间一律 `xxxAt` 结尾。
- 布尔用 `is`/`has`/`can` 起头（`needsClassification`、`editedByUser`），不写 `flag`、`status2` 这类含糊名。
- 常量集中放在所属类上（`RecordRepository.soloKey`、`SettingsRepository.sideLeft`），不散落魔法字符串。

### 数据与时间

- 时间统一存 `int` 毫秒时间戳，字段名以 `At` 结尾；日期用 `yyyy-MM-dd`，月份用 `yyyy-MM`，只有 `daily_records.date` 用日期字符串（唯一键）。
- 主键用 `data/id.dart` 的 `newId(前缀)`：`p` 项目、`s` 步骤、`t` 事项、`n` 随手记、`l` 流水、`d` 日记录、`i` 想法、`c` 分类与对话、`h` 进度史、`r` 修订。
- 数据库迁移只加不改不删，每步幂等，`schemaVersion` 加一；见 `data/db/migrations/migrations.dart`。
- 列名不能叫 `text`（撞 drift 的 `Table.text()`），SQL 里写全 `ADD COLUMN`。
- 数据库文件在 `getApplicationDocumentsDirectory()/app.db`（本机是 `D:\我的文档\app.db`）。API key 不进数据库、不进日志，走系统安全存储。

### 用例与错误处理

- 用例是单个动作，一个类一个 `call(...)`，构造注入端口，不持有可变状态。
- 结果用 `sealed class` 表达（`Started`/`AlreadyRunning`/`TaskNotFound`），不用异常做正常分支，也不返回 `bool` 让调用方猜原因。
- 查不到行返回 `null` 或空集合，不抛 `StateError`；孤儿数据（流水指向已删事项）跳过，不让一条脏数据打挂整页。
- 用例不 import Flutter、不弹提示、不读 `BuildContext`；提示文字由界面层决定。

### 注释与文档

- 每个公开类、每个 Repository/用例方法写一句 `///` 中文注释，说清它替调用方做了什么；不复述代码字面。
- 注释解释「为什么」，不写「这里是赋值」这类废话；临时排查代码不许留在提交里。
- 需求与字段语义的源头是 `docs/07-开发.md`，改动语义要回去同步，不在代码里另立一套说法。

### 测试与留档

- 测试放 `app/test/`，目录结构与 `lib/` 对齐；文件名 `*_test.dart`。
- 每块新增测试 + 编号更小的块全部重跑；`dart analyze` 必须 `No issues found!`（本机 `flutter analyze` 会崩，用 `dart analyze`）。
- Repository 测试不 import drift：建、改、删、查全走 Repository 方法，这条本身就是分层边界的证据。
- 用例测试用假端口（实现 `domain/port/` 里的接口），不连数据库；正常路径与边界各一条。
- 每块完工写 `docs/测试结果/<块号>-<名字>.md`，一个结果一行，再往 `docs/测试结果/总记录.md` 追加一行；测试挂过不许改判定，只能改代码。
