# 技术栈

> 本文档描述 AI桌宠日常助手的技术栈信息。

## 基本信息

| 属性 | 值 |
|------|-----|
| 项目名称 | ai_pet_assistant |
| 版本 | 1.0.0+1 |
| 语言 | Dart 3.13（SDK 约束 `^3.13.5`） |
| 框架 | Flutter |
| 目标平台 | Windows 桌面（其余平台未适配） |

## 核心技术

| 类别 | 技术 | 版本 | 用途 |
|------|------|------|------|
| 框架 | Flutter | 随 SDK | 界面、动画、布局 |
| 状态管理 | flutter_riverpod | ^3.4.3 | `Notifier` 管页面状态，`Provider` 装配依赖 |
| 路由 | go_router | ^18.1.1 | 常驻态、悬停面板、主界面五页 |
| 数据库 | drift | ^2.28.0 | 十二张表的 SQLite 访问 |
| SQLite 运行时 | sqlite3_flutter_libs | ^0.5.40 | 桌面端带库 |
| 路径 | path_provider / path | ^2.1.5 / ^1.9.1 | 库文件落在文档目录 |

## 桌面能力

| 包 | 版本 | 用途 |
|----|------|------|
| window_manager | ^0.5.2 | 无边框置顶窗、移动、改尺寸 |
| screen_retriever | ^0.2.2 | 取屏幕工作区，算贴边位置 |
| tray_manager | ^0.8.0 | 托盘图标与两项菜单 |
| launch_at_startup | ^0.5.1 | 开机自启开关 |

## 开发工具

| 类别 | 工具 | 用途 |
|------|------|------|
| 代码生成 | build_runner / drift_dev | 生成 `app_db.g.dart` |
| 静态检查 | flutter_lints ^6.0.0 | `analysis_options.yaml` 从严 |
| 测试 | flutter_test | 单元与 widget 测试 |
| 分析 | `dart analyze` | 本机 `flutter analyze` 会崩，统一用这个 |

## 约定

- 不引第二套状态管理（Bloc、Provider、GetX 都不加）与第二套路由。
- 不引第三方图表、日历、富文本库：现有页面用原生 widget 足够。
- AI 调用一律经 `domain/port/` 的接口，不把 HTTP 客户端散落到界面里。

---
*返回索引: [../project-context.md](../project-context.md)*
