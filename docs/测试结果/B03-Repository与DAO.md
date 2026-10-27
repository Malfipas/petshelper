# B03 Repository 与 DAO · 测试结果

任务块定义见 [开发任务拆解](../开发任务拆解.md)。本块前置：B02。重跑范围：B01、B02。

## 自动化测试（`flutter test`，43 条全过）

```text
2026-10-23 B03 首跑（含 B01、B02 重跑）
依赖方向：features 与 domain 不 import drift，通过
依赖方向：platform 与 ai 不 import drift，通过
依赖方向：domain 不 import Flutter，通过
ProjectRepository：建项目、放步骤与进度史，能整包取回，通过
ProjectRepository：项目不存在时返回空包不抛错，通过
ProjectRepository：删项目把它下面的待办、流水、随手记、进度史一起清掉，通过
ProjectRepository：改进度史留一条修订，原文进 revisions，通过
TaskRepository：独立事项与项目待办按 scope 分开，通过
TaskRepository：勾完成记下完成时间、取消勾选清掉，通过
TaskRepository：投入秒数逐次累加、流水按事项汇总，通过
TaskRepository：一天的投入按事项聚合并按秒数降序，通过
TaskRepository：事项删掉后那天的投入不再算它也不抛错，通过
TaskRepository：一天里做完的事项按完成时间倒序，通过
RecordRepository：用户改总结留一条修订并打上已改标记，通过
RecordRepository：按月取日总结只取这个月，通过
RecordRepository：一个月的投入按项目拆、独立事项归到 solo，通过
IdeaRepository：每条想法只归类一次，归类后不再出现在待归类里，通过
IdeaRepository：想法可以搬到别的分类、搬动不再触发重新归类，通过
IdeaRepository：同名分类不重复建、配色按已有的往下轮，通过
NoteRepository：同一个 owner 只留一条、空文本等于删掉，通过
NoteRepository：不同 owner 各存各的，通过
NoteRepository：事项换 id 时随手记跟着搬，通过
ChatRepository：问过没有问过能查出来、线程按 owner 隔离，通过
ChatRepository：同一毫秒里一问一答不会撞主键，通过
SettingsRepository：没有设置行时给一行的默认值，通过
SettingsRepository：各项设置存得进读得出，通过
B01 重跑：主题令牌与原型一致 5 条，通过
B01 重跑：lib 目录树符合类设计 6 条，通过
B01 重跑：空壳能构建并显示产品名 1 条，通过
B02 重跑：建库与读写往返 5 条，通过
```

## 手动清单

```text
2026-10-23 B03 首跑（含 B01、B02 重跑）
dart analyze 报告 No issues found
flutter test 输出 All tests passed，43 条
七个 Repository 的公开方法不出现 drift 的 Companion、Value、Table 类型，写入只收普通值
repository 单测文件不 import drift，仅靠 Repository 方法完成建、改、删、查
B01、B02 的手动项（应用能开、库文件在）本轮未复跑——B03 没碰启动路径与建表逻辑，留到 B04 一起验
```

## 排错记录

**代码质量检查未跑成。** 按用户要求在测试前执行 `npx falcon@latest review`，报 `npm error could not determine executable to run`。查 npm registry：公开的 `falcon` 包是 2013 年的 Kohana 风格 Web 框架（版本 `0.0.0-2`），没有 bin，因此这个命令不可能执行成功；环境里配置的 falcon MCP 是 `falcon-mcp-server`（Honeycomb Falcon 保险 API 集成），只有 `getPolicy` / `getSubmission` 两个工具，也不提供代码评审。要跑这项检查，需要用户给出真正的包名或 CLI 入口。

**自查改掉五处**：①`TaskRepository` 与 `RecordRepository` 里流水指向已删事项时 `firstWhere(orElse: throw)` 会把整页打挂，改成跳过孤儿流水；②`monthMinutesByProject` 名字写分钟、实际返回秒，改名 `monthSecondsByProject`；③同一方法用「月份里最早/最晚一条记录」倒推时间范围，依赖排序方向，改成从 `yearMonth` 直接算；④`ChatRepository` 的一问一答主键都用毫秒，同一毫秒会撞，改成 `newId('c')` 带随机尾数；⑤Repository 把 DAO 作为公开字段暴露，调用方写数据必须 import drift 的 Companion，改成私有 DAO + 只收普通值的方法，这条正是 B03 完成判定的关键。

## 测试脚本位置

```text
app/test/data/repository/repositories_test.dart   # 七个 Repository，23 条
app/test/architecture_test.dart                   # 分层边界，3 条
app/test/data/db/app_db_test.dart                 # B02
app/test/app/theme_test.dart                      # B01
app/test/structure_test.dart                      # B01
app/test/smoke_test.dart                          # B01
```
