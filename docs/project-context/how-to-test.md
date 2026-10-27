# 如何编写测试

## 放哪

测试在 `app/test/`，目录结构与 `lib/` 对齐，文件名 `*_test.dart`。

```text
app/test/
├── app/            theme_test、router_test、main_shell_test、providers_test
├── data/           db/app_db_test、repository/repositories_test
├── domain/         usecase/usecases_test、模型测试
├── features/       pet/、panel/ 等页面与 Notifier
├── platform/       window/、tray/、autostart
└── support/        假端口与测试工具
```

## 用什么

| 测什么 | 怎么测 |
|--------|--------|
| 用例 | 假端口（实现 `domain/port/` 的接口），不连数据库 |
| Repository | 真 `AppDb.memory()`，但只调 Repository 方法，不 import drift |
| 界面 | `UncontrolledProviderScope` + `AppDb.memory()` + 覆盖端口 |
| 窗口规则 | 纯函数与假 driver，不开真窗 |

## 断言怎么写

- **照原型取值**：原型的数值直接写进断言，不引用实现里的常量。实现改错了测试才会响。
- **不照实现回读**：不写 `expect(rect.center.dx, ...)` 这种跟着实现走的断言，写 `area.left + area.width / 2`。
- 颜色比大小用 `computeLuminance()`，不要比单个通道的 `r/g/b`。
- 定时器类行为用 `fakeAsync` 或注入 `Duration?`，别留挂着的定时器。

## 跑什么

```powershell
cd app
dart analyze                 # 必须 No issues found!
flutter test                 # 必须 All tests passed!
flutter test test/features/panel/   # 单跑一块
```

本机 `flutter analyze` 会崩，统一用 `dart analyze`。

## 留档

每块完工写 `docs/测试结果/<块号>-<名字>.md`：一行一条用例，标通过 / 失败；再往 `docs/测试结果/总记录.md` 追加一行（日期、块、重跑范围、通过数、失败数、备注）。

测试挂过不许改判定，只能改代码。

---
*返回索引: [../project-context.md](../project-context.md)*
