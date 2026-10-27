# 代码图谱洞察 · 最近一次

> 本文件是 `code_insight` 类分析的落盘入口。当前内容由 Agent 按代码实际结构整理（B09 开工时）。
> 结构化副本见 [latest.json](./latest.json)。

## 分层与依赖

```text
main.dart
 ├─ data/db/app_db.dart ──────────────┐
 ├─ platform/window/pet_window.dart   │
 ├─ platform/tray/tray.dart           │
 └─ app/app.dart                      │
     ├─ app/providers.dart ◄──────────┘
     │   ├─ 7 个 Repository ──► data/dao/* ──► app_db
     │   ├─ 6 个用例 ─────────► domain/port/*
     │   └─ platform 端口（window/tray/autostart）
     ├─ app/router.dart ──► features/{pet,panel,tasks,records,projects,ideas,settings}
     └─ app/main_shell.dart
```

## 关键调用链

### 常驻态与档位

```text
features/pet/pet_page.dart
  ├─ PetNotifier.hoverEnter/hoverExit  300ms 开、500ms 收
  ├─ PetFrameNotifier                  窗口内相对矩形
  └─ PetStagePort.showCollapsed/showPanel/showMain
        └─ platform/window/pet_window.dart + pet_layout.dart
```

### 完成一件事

```text
features/* 界面
  └─ FinishTask.call(taskId, nowMs, done)
        ├─ TaskGateway.setDone
        ├─ ProjectGateway.addProgress（勾上时）
        └─ NoteGateway.save（把随手记挂到进度史，勾上时）
```

### 悬停面板（B09 起）

```text
features/pet/pet_page.dart 的 _PanelSurface
  └─ features/panel/panel_page.dart
        └─ PanelNotifier
              ├─ TaskRepository.byId / byProject / solo
              ├─ ProjectRepository.load / digests
              └─ NoteRepository.textOf / save
```

## 影响面提示

| 改动点 | 会牵连 |
|--------|--------|
| `domain/model/task_item.dart` | 12 张表的映射、`tasks` 页面、面板、用例 |
| `app/theme.dart` | 所有界面；改令牌等于改全站，先对 `:root` |
| `platform/window/pet_layout.dart` | 三档尺寸、`PetFrame`、所有常驻态测试 |
| `app/providers.dart` | 应用装配；新增 Repository 必须在这里挂一次 |

## 缺口

- 面板的「当前事务」目前没有持久指针，取「最近推进的项目的第一条未完成待办」；B12/B15 完成后改由页面显式 `setCurrent`。
- AI 相关端口仍是离线实现（`_OfflineClassifier` / `_OfflineSummarizer`），等 B22。

---
*返回索引: [../project-context.md](../project-context.md)*
