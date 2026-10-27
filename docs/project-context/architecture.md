# 架构设计

> 本文档描述 AI桌宠日常助手的目录结构与分层规则。

## 项目结构

```text
AI桌宠日常助手/
├── app/                    Flutter 工程
│   ├── lib/
│   │   ├── main.dart       入口：开库、建窗、挂托盘
│   │   ├── app/            壳、路由、主题、ProviderScope、依赖装配
│   │   ├── features/       按页切：pet、panel、tasks、records、projects、ideas、settings
│   │   ├── domain/         实体、用例、端口（纯 Dart）
│   │   ├── data/           drift 表、DAO、Repository、迁移、行映射
│   │   ├── platform/       窗口、托盘、自启、安全存储、通知
│   │   └── ai/             客户端、提示词、结构化解析、降级
│   └── test/               目录结构与 lib/ 对齐
├── prototype/              原型：整体原型 + 单页原型
├── docs/                   PRD、开发文档、任务拆解、测试结果、规格
└── state/                  各阶段产出与规划
```

## 主要目录说明

| 目录 | 用途 |
|------|------|
| `app/lib/app/` | 只有一个窗口壳：主题令牌、路由表、Provider 装配、主界面壳 |
| `app/lib/features/pet/` | 常驻态：宠物形象、气泡、悬停面板插槽、`PetNotifier` |
| `app/lib/features/panel/` | 悬停小面板的实体内容（B09 起） |
| `app/lib/domain/model/` | 十二个实体与几个读模型（`ProjectBundle`、`ProjectDigest`） |
| `app/lib/domain/usecase/` | 六个用例，一个类一个 `call` |
| `app/lib/domain/port/` | 用例需要的最小接口，由 `data/repository/` 实现 |
| `app/lib/data/db/` | drift 表定义、`app_db.dart`、迁移 |
| `app/lib/data/dao/` | 十二张表各一个 DAO，只做 CRUD |
| `app/lib/data/repository/` | 七个 Repository，做行到实体的转换与跨表编排 |
| `app/lib/platform/` | 窗口三档与拖动规则、托盘、自启 |

## 依赖方向

```text
app → features → domain ← data
                   ↑
              platform（只有 features/app 用它）
```

- `domain/` 不 import Flutter、不 import drift、不 import `data/`、`features/`、`app/`。
- `features/` 只经 Repository 或 Notifier 取数，不 import drift。
- 只有 `data/` 能 import `package:drift`；drift 行类型不出 data 层。
- 换平台只动 `platform/`，换存储只动 `data/`。

## 窗口三档

| 档 | 尺寸 | 内容 |
|----|------|------|
| collapsed | 宠物宽高 | 只画宠物 |
| panel | 宠物 + 面板 | 面板宽 30%、高 40%，与宠物同锚点 |
| main | 工作区 70%×70%，最小 880×560，居中 | 主界面壳 + 五标签 |

档位由 `PetNotifier` 决定，界面把它翻给窗口层（`PetStagePort`），窗口层按 `pet_layout.dart` 算矩形。

## 状态管理

- 一个页面一个 `Notifier`；`ref.watch` 读、`ref.read` 调。
- 依赖在 `app/providers.dart` 一处装配。
- 界面内部一次性小状态（悬停、动画、展开）用 `StatefulWidget` 本地状态。

---
*返回索引: [../project-context.md](../project-context.md)*
