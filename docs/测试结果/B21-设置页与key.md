# B21 设置页与 key

- 日期：2026-10-27
- 范围：第 8 页「设置」——模型 API key 的存与清、两条只读地址的复制（PRD 第 8 页 699–738 行，原型 `第八页-设置.html`）
- 结论：`flutter test` 553 条全过（本块新增 22 条），`dart analyze lib test` 无问题

## 先校准的部分

B21 只做这一页的界面与 key 的存取。AI 客户端、提示词、三处 AI 入口仍是 B22/B23 的事；这一页只负责把 key 存进系统凭据，并把 `settings.keyConfigured` 翻过来，让第 2、5、6、7 页的入口跟着变。

PRD 731 把这一页的范围钉死了：快捷键、气泡开关、梳理排序、数据导出、主题、账号一概不做，所以页面上只有两块卡。

阅读 PRD 与原型后确定的口径：

1. **页头只有标题**。「设置」两个字，不放副标题（PRD 705、v2.8.3）。
2. **卡片里不放说明文字、不放配置状态行**。保存与清除的结果只由按钮文字反映，1.5 秒后复原（PRD 713、714、723、724，v2.8.2）。
3. **输入为空点保存按清除处理**，按钮同样显示「已清除」（PRD 715）。
4. **不在页面上回显 key**（PRD 733）。进页输入框是空的，不是末四位——v2.8.1 曾有「状态行回显末四位」，v2.8.2 删掉了，执行按后来那版。
5. **剪贴板不可用就退回选中文本**，并提示手动复制（PRD 717、727）。
6. **地址只读**，不提供编辑；真实链接定了再替换占位（PRD 734）。

## 实现

| 层次 | 内容 |
| --- | --- |
| 端口 | 新 `domain/port/secure_key_gateway.dart`：`read`/`write`/`clear` 三个动作，只说「存 key」，不说怎么存 |
| 平台 | 新 `platform/secure_store.dart`：`SystemSecureKeyGateway` 用 Windows DPAPI 加密后落 `api_key.bin` |
| 装配 | `app/providers.dart` 加 `secureKeyGatewayProvider` |
| 数据 | `SettingsRepository` 补两条占位地址常量；表没动，`keyConfigured` 早就有了 |
| 状态 | 新 `settings_state.dart`：两条地址、是否明文、按钮闪光、提醒行、选中请求（`selectTick` 与 `selectTarget`），以及三个按钮文案的判定 |
| 动作 | 新 `settings_notifier.dart`：`refresh`、`toggleReveal`、`save`、`clear`、`copyDemo`、`copyRepo` |
| 界面 | `settings_page.dart` 整篇重写：页头、两张卡、只读地址行、38 高按钮 |
| 样式 | `theme.dart` 补 `readonlyFieldBg`（原型 `.st-linkrow input{background:#f6f8fb}`） |

几处判断：

- **key 的值与「配没配」分两处存**。值进 DPAPI 文件，`settings.keyConfigured` 只记真假；别的页只读后者。所以 `save`/`clear` 必须两处一起改——漏一处就是「key 存进去了但各页仍然只读」这种自相矛盾。
- **不用 `flutter_secure_storage`**。它的 Windows 实现要编译器带 ATL，本机 `atlstr.h` 找不到，`flutter build windows` 直接失败。改成用 `win32` 的 `CryptProtectData`/`CryptUnprotectData` 自己加密落盘：密文只有当前用户、当前机器解得开，文件被拷走也读不出明文；换机器解不开时 `read` 返回 null，当作没存过，不把坏数据交给 AI 客户端。
- **按钮文字用轮次计数防串台**。连点两次保存，前一次的 1.5 秒计时回来不该把后一次的字擦掉；3 秒的提醒同理。
- **剪贴板写不进去不算失败**。改成选中那一行并提示按 Ctrl+C，`selectTick` 自增让界面知道「又来一次」——同一个地址连点两下也能重新选中。
- **进页再刷一次**。`build` 里那次与页面 `initState` 里那次各管一头，地址可能在别处被改过。

## 与原型不一致的地方

1. **「事件台」换成页内一行提醒**。原型把剪贴板失败写进底部事件台；本应用没有常驻事件台（B19 已把这类提示并成页内一行），所以提示出现在卡片区上方，3 秒后自己收掉。
2. **占位地址是真地址形态**。原型写的是空占位，这里给了 `https://example.com/...` 两条，复制出来能看出是占位，不会误以为是可用链接。真实链接定了一改常量就换掉。

## 用例

新增 22 条，分三个文件：

| 文件 | 条数 | 覆盖 |
| --- | --- | --- |
| `settings_notifier_test.dart` | 10 | 进页读两条地址、库里有值优先、存 key（trim 后写凭据并置为已配、闪「已保存」再复原）、空输入当清除、清除关掉全站开关、凭据写失败给一行提醒、眼睛来回切、复制进剪贴板、剪贴板不可用（提醒 + 请求选中 + 轮次自增）、复制成功收掉上一次的提醒 |
| `settings_page_test.dart` | 7 | 进页看到标题与两卡与占位地址、掩码与眼睛切换、填 key 保存（按钮「已保存」、输入框保留内容）、点清除（清空输入框、按钮「已清除」）、删光再保存按清除走、复制演示视频（「已复制」→「复制」）、剪贴板不可用（提醒 + 仓库那行拿到焦点） |
| `test/platform/secure_store_test.dart` | 5 | DPAPI 真实往返：写进去读得回来且落盘无明文、清除后读不到且文件没了、没存过为 null、文件被改坏当没存过、写入顶掉旧 key（非 Windows 跳过） |

- `flutter test`：**553 条全过**
- `dart analyze lib test`：`No issues found!`

完成判定里的「保存后各页恢复、清除后各页只读」落在数据上：`save` 与 `clear` 的用例各断言了 `keyConfigured` 的写入值，读取侧由第 5、7 页的用例覆盖（`records_page_test` 与 `ideas_page_test` 里「提示随配置出现与消失」两条）。这一块没有另写一条跨页点击流用例，避免把两页的进页时机耦合进同一个测试。

## 实机

```
PID 1284  2026-10-27 0:21:44  Responding=True
```

exe 构建于 0:18:31，晚于 DPAPI 那版 `secure_store.dart`，运行中就是本块代码。本机是 Windows，DPAPI 可用。

界面上手点一遍要核对的：

- 顶栏点「设置」：标题只有「设置」，两张卡纵向排、间距 20 像素，卡片里没有说明句与状态行。
- key 输入框默认是圆点；点眼睛变明文，再点回圆点。
- 填一个假 key 点「保存」：按钮变「已保存」，1.5 秒后回到「保存」；输入框内容留着，方便用户核对没填错。
- 到应用支持目录（`getApplicationSupportDirectory()`，Windows 在 `%APPDATA%` 下）看 `api_key.bin`：文件在，用记事本打开看不到 key 原文。
- 点「清除」：按钮变「已清除」，文件消失；此时第 2、5、6、7 页的 AI 入口应回到只读（`keyConfigured` 为假）。
- 把输入框删空再点「保存」：同样显示「已清除」。
- 一条地址（项目仓库）只读、底色比输入框浅一档；点「复制」按钮变「已复制」，粘到别处是 `https://example.com/ai-pet`。

## 追加：暂时隐藏「演示视频」那一行（2026-10-27）

真实演示视频还没有，占位地址 `https://example.com/ai-pet-demo.mp4` 摆在那里只会让人复制了去打不开，所以这一轮整行先不显示：

- `settings_page.dart` 里 `_UrlRow(label: '演示视频', …)` 与它下面的 12 像素间距一起注释掉，卡里只剩「项目仓库」一行；
- 数据这头一律不动：`SettingsRepository.demoUrl` / `setDemoUrl`、`SettingsNotifier.copyDemo()`、`SettingsState.demoUrl` 与 `copyLabel(demo: true)` 都原样保留，放开时把那几行注释放开就能用；
- 页面测试改成断言这一行不存在：`find.text('演示视频')`、`settings-url-demo`、`settings-copy-demo` 三处都是 `findsNothing`；
- 原来那条「复制演示视频：进剪贴板…」用例随之注释掉；为了不让剪贴板变量悬空、也把现在仅剩这一行的成功路径补上，新增「复制项目仓库：进剪贴板，按钮变「已复制」再复原」。

- `dart analyze lib test`：`No issues found!`
- `flutter test test\features\settings`：**20 条全过**
- `flutter test`：**615 条全过**


`api_key.bin` 落在应用支持目录、与 `app.db` 分开，所以清库不会带走 key，删了 key 文件也不影响数据。
