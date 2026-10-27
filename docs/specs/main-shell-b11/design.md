# B11 主界面壳与五标签 · 设计（校准记录）

## 概述

壳与五标签在 B05 铺路由时已经按原型落地，B06 补了窗口档位。本轮先逐项量数、再补差别：一处视觉（标签换态硬跳）、三条行为没测试。设计只动 `_TabButton` 的换态方式，壳结构与路由语义不碰。

对应需求：FR-04、FR-05 是本轮改动；FR-01 到 FR-03、FR-06 到 FR-09 是核对通过、补测试留档。

## 逐项核对（原型 216–235 行 / PRD 399–438 行）

| 项 | 原型 | PRD | 现状 | 结论 |
| --- | --- | --- | --- | --- |
| 壳尺寸 | `.main{width:70vw;height:70vh;min-width:880px;min-height:560px}` | 401 居中占七成 | 窗口层 `mainBounds` 负责，壳 `Positioned.fill` 铺满 | 对（FR-01） |
| 壳底色 / 边 / 圆角 | `#f2f6fc`、`1px var(--line)`、`18px` | 405 | `AppTheme.shellBg`、`Border.all(AppTheme.line)`、`radiusShell` | 对（FR-02） |
| 壳内边距 | `16px 18px 18px` | 405 | `EdgeInsets.fromLTRB(18,16,18,18)` | 对（FR-02） |
| 标签排 | `gap:8;padding-left:4;margin-bottom:8` | 407 | `left:4` + 每键 `right:8` + `SizedBox(8)` | 对（FR-03） |
| 标签顺序 | 独立事项 / 我的项目 / 我的记录 / 想法盒 / 设置 | 407 | `MainTab` 枚举同序 | 对（FR-03） |
| 标签尺寸 | `min-height:38;padding:0 20px;radius:12;font-size:14` | 407 | `minHeight:38`、`horizontal:20`、`radiusCard`、`_labelSize=14` | 对（FR-06） |
| 默认态 | 透明底、`--ink2`、400 | 407 | `Colors.transparent`、`AppTheme.ink2`、`w400` | 对（FR-04） |
| 悬停 | `.tab:hover{color:var(--ink)}` | 未写 | 只改字色 | 对（FR-04） |
| 选中态 | 白底、`--line` 边、`--ink`、600、`0 2 8 rgba(30,50,80,.08)` | 407 | 同，阴影 `0x141E3250` | 对（FR-04） |
| 换态过渡 | `transition:color/background/border-color/box-shadow .15s`（228 行） | 未写 | 没有，硬跳 | **本轮补（FR-05）** |
| 页面纸 | 白、`1px` 边、`14px`、`26px 30px` | 407 | `radiusPage`、`horizontal:30,vertical:26` | 对（FR-07） |
| 顶部标题行 | 没有 | 407 | 没有 | 对（FR-03） |
| 关闭入口 | 无叉 | 418 | 无叉；Esc 与点桌宠两条 | 对（FR-08） |
| 重开落点 | — | 419 回独立事项 | `onOpenMain` 固定 `go(solo)` | 对，缺测试（FR-08） |
| 深链 / 兜底 | — | 409–412 | `MainTab.byPath` + 路由重定向 | 对，已有测试（FR-09） |

## 技术方案

`_TabButton` 的白底与边框目前分在两层：`Material` 画白底，最内层 `Container` 画边与影。颜色一变就是硬跳。改成：

1. 白底挪进 `AnimatedContainer` 的 `decoration.color`，与边、影同层。
2. `Material` 改成 `MaterialType.transparency`，只负责接手势与水波。
3. 文字包一层 `AnimatedDefaultTextStyle`，字色跟着动画走。
4. 两处都用 `Duration(milliseconds:150)` + `Curves.ease`，对齐 CSS `.15s` 的默认缓动。
5. `InkWell` 关水波与 hover 遮罩（`NoSplash`、透明 `hoverColor`/`highlightColor`）：原型没有这层遮罩，留着会在选中白底上盖一块灰。
6. `constraints` 与 `padding` 放在 `AnimatedContainer` 上但不参与补间（只动画 `decoration` 与文字样式），过渡期间不重排，满足 FR-05 后半句。

字重 400→600 不做补间：CSS 的 `transition` 列表里没有 `font-weight`，原型也是到点直切。

## 文件结构

```text
app/lib/app/main_shell.dart          壳、五标签、页面纸、Esc、桌宠叠放（改 _TabButton）
app/lib/app/routes.dart              路由地址常量（不动）
app/lib/app/router.dart              路由表与兜底（不动）
app/lib/app/theme.dart               壳与页面纸用到的令牌（不动）
app/test/app/main_shell_test.dart    壳与标签像素、悬停、桌宠收起（改 + 增）
app/test/app/router_test.dart        深链、兜底、重开落点（增）
docs/specs/main-shell-b11/           本规格
docs/测试结果/B11-主界面壳与五标签.md  结果留档
```

## 偏差表

| 项 | 原型 / PRD | 实现 | 为什么 |
| --- | --- | --- | --- |
| 打开动效 | `.main{transition:transform .34s,opacity .34s}` 从右滑入（401、426） | 不做，直接出现在正中 | 窗口位置由 `platform/window` 逐帧改，与 B06 的档位切换共用一条链路，塞进来会和贴边吸附打架；留 B24 与动效一起做 |
| 页面纸滚动 | `.sheet{overflow:auto}`（233 行） | 页面纸不滚，交给各页自管 | 壳里放滚动容器会给子页面无界高度，记录页那种左右分栏、列表带固定页脚的布局摆不出来；日期头也不该跟着滚走 |
| 外壳阴影 / 桌面遮罩 | `box-shadow:0 28px 70px`、背后半透明遮罩 | 不做 | 窗口是矩形，影子画到窗口外会被裁；遮罩要全屏窗口，会挡桌面操作，与 PRD 316 冲突。`main_shell.dart` 注释已留档，B24 处理 |

## 测试

- 既有 4 条像素断言（壳、标签尺寸、选中、未选中）改成读 `AnimatedContainer` 的 `decoration`，数值一条不改；顺手断言两个动画时长是 150ms（AC-4）。
- 新增：标签悬停只提字色、不动底与边（AC-3）。
- 新增：点展开态桌宠后主界面收起（AC-5 前半），注入 `petFrameProvider` 矩形后点 `PetOnMain`。
- 新增：停在「我的记录」→ Esc → 点桌宠再打开，落在「独立事项」（AC-5 后半）。
- 全量重跑，条数从 260 起往上加。
