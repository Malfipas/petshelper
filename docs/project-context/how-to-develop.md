# 如何开发

## 一块功能的开工顺序

1. **先量原型**。打开 `prototype/整体原型.html`，把这一块涉及的尺寸、间距、字号、颜色记下来。单页原型与整体原型冲突时以整体为准；原型与 PRD 冲突时以原型为准。
2. **定分层**。数据要加表或加列 → `data/`；只是规则 → `domain/usecase/`；只是摆放 → `features/`。
3. **写规格**（较复杂时）：`docs/specs/<功能名>/requirements.md`、`design.md`、`tasks.md`。
4. **先实现领域与数据**，再写界面。用例测试用假端口，不连数据库。
5. **测试断言照原型数值写**，不照实现回读：`expect(padding, EdgeInsets.fromLTRB(18, 16, 18, 18))`，不写 `expect(box.padding, myConst)`。
6. **收尾**：`dart analyze` 零问题、`flutter test` 全过、写 `docs/测试结果/<块号>-<名字>.md` 并在 `总记录.md` 追加一行。

## 加一层数据的顺序

```text
data/db/tables/xxx.dart        建表（列名 snake_case，时间列以 At 结尾）
data/db/app_db.dart            登记表与 schemaVersion
data/db/migrations/            迁移只加不改不删，每步幂等
data/dao/xxx_dao.dart          只做 CRUD
data/mapping/row_mappers.dart  行到实体的转换
domain/model/xxx.dart          实体（纯 Dart）
data/repository/xxx_repository.dart
```

## 加一个用例的顺序

```text
domain/port/xxx_gateway.dart   只声明这个用例要用的方法
domain/usecase/xxx.dart        一个类一个 call，结果用 sealed class
app/providers.dart             装配
test/domain/usecase/           正常路径 + 边界各一条
```

## 界面开发要点

- 界面里不写 `'/main/xxx'` 字符串，跳转用 `context.go(AppRoutes...)`。
- 不 `new AppDb()`、不 `new Repository()`。
- 文案与数值的来源是原型与 PRD；实现里新增常量要注明出自哪一条。

## 提交前

```powershell
cd app
dart analyze
flutter test
flutter build windows --debug
```

---
*返回索引: [../project-context.md](../project-context.md)*
