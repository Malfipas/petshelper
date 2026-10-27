# AI桌宠日常助手 · Flutter 工程

Flutter 3.47.7（Dart 3.13.5），Windows 首发。开发顺序与任务块见仓库里的 `docs/开发任务拆解.md`，类设计见 `docs/07-开发.md` 的「类设计」一节。

## 跑起来

```bash
flutter pub get
flutter run -d windows
```

分析、测试：

```bash
flutter analyze
flutter test
```

## 目录各层放什么

```text
lib/
├── main.dart            # 入口，逐块接入数据库、托盘、自启的初始化
├── app/                 # 壳、路由、主题、依赖注入
├── domain/              # 实体与用例，纯 Dart，不 import Flutter
│   ├── model/
│   └── usecase/
├── data/                # drift 数据库、DAO、Repository 实现、迁移
│   ├── db/
│   ├── dao/
│   └── repository/
├── platform/            # 窗口、托盘、自启、安全存储、通知（Windows 实现都在这里）
│   ├── window/
│   ├── tray/
│   ├── autostart.dart
│   ├── secure_store.dart
│   └── notify.dart
├── ai/                  # AI 客户端、提示词、结构化解析、降级
└── features/            # 按八页切：pet、panel、tasks、records、projects、ideas、settings
```

依赖方向自上而下，`domain` 不依赖任何一层，也不 import Flutter——换平台时这一层不用改。

## 当前进度

B01 建工程与目录骨架已完工。测试结果按块留档在仓库 `docs/测试结果/`。
