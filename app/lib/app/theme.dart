import 'package:flutter/material.dart';

/// 设计令牌。数值与原型一致，改这里就等于改全站。
///
/// 圆角四档：壳 18、页面 14、卡片与格子 12、按钮与输入 10。
/// 字号五档：页标题 18、卡片标题与事名 15、正文与说明 13、元信息 12、角标 11。
class AppTheme {
  AppTheme._();

  // 颜色：一律取整体原型 `:root` 的值
  static const Color primary = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFE8EFFD);
  static const Color ink = Color(0xFF1F2937);
  static const Color ink2 = Color(0xFF5B6676);
  static const Color ink3 = Color(0xFF9AA5B4);
  static const Color line = Color(0xFFC9D4E3);

  /// 比 [line] 浅一档，用于虚线分隔与输入框内线。
  ///
  /// 原型里 `--line2` 被引用了却没定义（`--line3`、`--ink3` 也是），浏览器直接
  /// 丢掉那条声明，虚线根本不出现。那是原型的漏写，不该照搬，按同一族取浅一档。
  static const Color line2 = Color(0xFFDCE4EE);

  /// 进度条与分段条的底色。整体原型 `--track:#d8e0ec`，PRD 584 也写死了这个值。
  static const Color track = Color(0xFFD8E0EC);
  static const Color danger = Color(0xFFD94A3D);

  /// 原型 `--warm` / `--warm-soft`：正在计时的多选框用它。
  ///
  /// 不拿主色代替——主色在这一族语义里是「已完成」，跑着是另一件事。
  static const Color warm = Color(0xFFF0B429);
  static const Color warmSoft = Color(0xFFFEF3C7);

  /// 原型 `--accent-soft`：当前行的浅蓝底。比 [primarySoft] 浅一档，不合并。
  static const Color accentSoft = Color(0xFFEEF3FE);

  /// 进度史步骤标签的底。原型 `.pj-htag{background:#f4f7fc}`。
  static const Color histTag = Color(0xFFF4F7FC);

  /// 修订链块的底。原型 `.pj-revbox{background:#f8fafd}`。
  static const Color histRev = Color(0xFFF8FAFD);

  /// 时间轴那条竖线。原型 `.pj-tl:before{background:#e6ecf5}`。
  static const Color histLine = Color(0xFFE6ECF5);

  /// 想法盒分类标签的描边。原型 `.fb-tag{border:1px solid #cfdcfb}`。
  static const Color ideaTagBorder = Color(0xFFCFDCFB);

  /// 想法盒的浅底：左栏行悬停与「未分类」标签共用。原型 `#f6f8fc`。
  static const Color hoverBg = Color(0xFFF6F8FC);

  /// 想法卡悬停时的描边。原型 `.fb-idea:hover{border-color:#c3d1e4}`。
  static const Color cardHoverLine = Color(0xFFC3D1E4);

  /// 只读输入框的底色。原型 `.st-linkrow input{background:#f6f8fb}`。
  static const Color readonlyFieldBg = Color(0xFFF6F8FB);

  /// 主界面外层壳的底色。整体原型 `.main{background:#f2f6fc}`。
  static const Color shellBg = Color(0xFFF2F6FC);

  /// 桌宠停靠的那层桌面底。整体原型 `body` 的渐变起点 `--bg1:#eef2f7`，
  /// 屏幕上只有宠物时露出的就是它。
  static const Color desktopBg = Color(0xFFEEF2F7);

  // 圆角
  /// 全局字体族。控件里要显式写 TextStyle 时带上它，别让数字掉回默认字体。
  ///
  /// 使用者 2026-10-26 的《页面操作流程》第 1 行定死「所有字体务必均为微软雅黑」，
  /// 于是从宋体改回微软雅黑。写英文族名 `Microsoft YaHei`：Windows 注册的族名就是
  /// 它，中文名「微软雅黑」在不同 locale 下不一定认，放进 fallback 兜底。
  static const String fontFamily = 'Microsoft YaHei';

  /// 微软雅黑的几个别名，缺一个在个别机器上就整屏掉回默认字。
  static const List<String> fontFamilyFallback = <String>[
    '微软雅黑',
    'Microsoft YaHei',
    'MicrosoftYaHei',
  ];

  static const double radiusShell = 18;
  static const double radiusPage = 14;
  static const double radiusCard = 12;
  static const double radiusControl = 10;

  // 字号
  static const double fontPageTitle = 18;
  static const double fontCardTitle = 15;
  static const double fontBody = 13;
  static const double fontMeta = 12;
  static const double fontBadge = 11;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: desktopBg,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      // 全站统一微软雅黑：Material 的组件默认走 `Typography` 里那套 Roboto 文本主题，
      // 只写 `fontFamily` 覆盖不到 Tooltip、SnackBar 这些自己带样式的组件。
      // 这里把文字主题整体改掉，界面里就不必每处 `TextStyle` 再点名。
      textTheme: Typography.blackMountainView.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: line),
        ),
      ),
    );
  }
}
