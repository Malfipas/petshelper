# B22 AI 客户端与降级

- 日期：2026-10-27
- 范围：AI 的公共底座——一次模型调用的客户端、两份提示词、拆解结果的解析、拆解端口与落库端口；不含页面
- 结论：`flutter test` 597 条全过（本块与 B23 第 6 页那处合计新增 44 条），`dart analyze lib test` 无问题

## 口径

1. **一家协议通吃**。选 OpenAI 兼容的 `/chat/completions`：DeepSeek、Moonshot、通义、本地 llama.cpp 都是这个形状，换一家只改 baseUrl 与模型名。默认 `https://api.deepseek.com` + `deepseek-chat`。
2. **没 key 不是错**。结果只三种：`ChatReply` 拿到、`ChatNoKey` 没配、`ChatError` 这次没成（带一句能直接上屏的话）。调用方按自己的口径处理，不接异常。
3. **超时 30 秒，不自动重试**。重试一次等于让用户等 60 秒；不如把失败摆出来让他再点一下。
4. **解析宁可返回 null**。模型会套 ```json 围栏、会在 JSON 前后各说一句，剥掉就好；但抠不出完整 JSON 时返回 null，让界面说「没看懂，再试一次」，不塞半份数据进项目。
5. **提示词限制字数**。步名 6 字内动词开头、事项 15 字内且能立刻动手、回话 30 字内——这些落进流程条与卡片才不会撑破。
6. **降级不另设文件**。`ChatNoKey` 本身就是降级信号：面板给一句「去设置页填一个」，拆解返回 `PlanNotConfigured`，归类与总结返回 null 由用例降级。

## 实现

| 层次 | 内容 |
| --- | --- |
| 端口 | `domain/port/project_planner.dart`（`plan` → `PlanReady`/`PlanNotConfigured`/`PlanFailed`）、`domain/port/project_plan_writer.dart`（`applyPlan` → 写进库的步数） |
| AI | `ai/chat_client.dart`（`ChatClient` 接口 + `HttpChatClient`）、`ai/prompts.dart`、`ai/plan_parser.dart`、`ai/ai_project_planner.dart` |
| 装配 | `app/providers.dart` 加 `chatClientProvider`、`projectPlannerProvider`、`projectPlanWriterProvider`；`HttpChatClient` 从 `secureKeyGatewayProvider` 读 key |
| 数据 | `ProjectRepository` 实现 `ProjectPlanWriter`：空流程整体替换占位步骤 1，已有内容追加到末尾 |

## 用例

| 文件 | 条数 | 覆盖 |
| --- | --- | --- |
| `test/ai/chat_client_test.dart` | 6 | 没 key 不发请求、200 正常取 content、401 提示换 key、500 提示稍后再试、超时提示再试一次、返回体缺字段不装成正常回答 |
| `test/ai/plan_parser_test.dart` | 8 | 裸 JSON、```json 围栏、前后带废话、没有步名的那条丢弃、超过 8 步截断、长文本截断、steps 不是数组返回 null、非 JSON 返回 null |
| `test/ai/ai_project_planner_test.dart` | 6 | 正常拆解回 `PlanReady`、没 key 回 `PlanNotConfigured`（不当作失败）、失败回 `PlanFailed` 并带原因、解析不出来回 `PlanFailed`、目标先 trim 再拼提示词、项目名为空时不写「项目名：」 |
| `test/data/repository/repositories_test.dart` | 4（新增） | `applyPlan` 空流程替换占位步骤、已有步骤追加到末尾、步骤下带事项算有内容不替换、空拆解不动库 |

- `flutter test`：**597 条全过**
- `dart analyze lib test`：`No issues found!`

## 实机

客户端只在有 key 时才会真的发请求，自动化测试里全换成剧本，所以端到端要上手点一次：

- 设置页填一个真 key 保存 → 第 6 页进任一项目详情 → 展开「AI 帮助」→ 填一句目标（例：把这个项目拆成能动手的几步）→ 点「拆步骤」。
- 等 3 到 10 秒：按钮先变「拆分中…」，回来后先有一句回话，下面按序号列出步骤与每步那件事。
- 此时库里的步骤**不应该**变（预览不落库）；点「应用到项目」之后流程区才多出步骤，并提示「已加入 N 个步骤」。
- 到设置页点「清除」，再进详情：「AI 帮助」整块只读，指路设置页。
- 断网再点一次「拆步骤」：气泡里是「连不上模型服务，检查网络后再试」，页面不崩、不阻塞。
