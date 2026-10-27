# AI桌宠日常助手 - 项目上下文

> 本文档是项目上下文的索引文件，提供项目概览和文档导航。

## 📊 项目概览

| 属性 | 值 |
|------|-----|
| 项目名称 | AI桌宠日常助手（`ai_pet_assistant`） |
| 版本 | 1.0.0+1 |
| 语言 | Dart 3.13 |
| 框架 | Flutter（Windows 桌面） |
| 类型 | 本地优先的单机桌面应用 |
| 描述 | 一个常驻桌面的宠物，负责把今天那一件事摆出来、启动、记下做完的痕迹 |

## 📚 文档导航

### [技术栈](./project-context/tech-stack.md)
语言、框架、依赖与各自的职责边界

### [架构设计](./project-context/architecture.md)
六层目录、依赖方向、窗口三档与状态管理

### [如何开发](./project-context/how-to-develop.md)
新增一块功能时的顺序与自检项

### [如何编写测试](./project-context/how-to-test.md)
测试放在哪、断言怎么写、跑什么命令

### [代码图谱洞察](./graph-insights/latest.md)
模块依赖与调用链摘要

## 🚀 快速开始

```powershell
cd app
flutter pub get
dart analyze
flutter test
flutter run -d windows
```

## 💡 开发时查看对应文档

- 改数据结构 → [架构设计](./project-context/architecture.md) 的「数据层」
- 改界面数值 → `prototype/整体原型.html`（唯一验收标准）
- 写测试 → [如何编写测试](./project-context/how-to-test.md)
- 不确定模块归属 → [代码图谱洞察](./graph-insights/latest.md)

---
*生成时间: 2026-10-23*
*生成工具: MCP Probe Kit - init_project_context v2.1 + Agent 落盘*
