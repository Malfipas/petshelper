import 'package:ai_pet_assistant/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 断言一律对整体原型 `:root` 的原文取值，不照实现回读。
void main() {
  group('主题令牌与整体原型 :root 一致', () {
    test('主色与浅底：--accent #2563eb、--accent-soft #e8effd', () {
      expect(AppTheme.primary, const Color(0xFF2563EB));
      expect(AppTheme.primarySoft, const Color(0xFFE8EFFD));
    });

    test('墨色与边框：--ink #1f2937、--ink2 #5b6676、--line #c9d4e3', () {
      expect(AppTheme.ink, const Color(0xFF1F2937));
      expect(AppTheme.ink2, const Color(0xFF5B6676));
      expect(AppTheme.line, const Color(0xFFC9D4E3));
    });

    test('虚线用的 line2 比 line 浅一档，且不和 line 撞色', () {
      // 原型引用了没定义的 --line2，这里按同一族补一档，但要浅于 --line。
      expect(AppTheme.line2, isNot(AppTheme.line));
      expect(AppTheme.line2.computeLuminance(), greaterThan(AppTheme.line.computeLuminance()));
    });

    test('进度条底色 --track #d8e0ec，PRD 584 同值', () {
      expect(AppTheme.track, const Color(0xFFD8E0EC));
    });

    test('危险色 --danger #d94a3d', () {
      expect(AppTheme.danger, const Color(0xFFD94A3D));
    });

    // 壳的底色是原型 `.main{background:#f2f6fc}`，不是 body 那层桌面渐变。
    test('壳底色取 .main 的 #f2f6fc', () {
      expect(AppTheme.shellBg, const Color(0xFFF2F6FC));
    });

    test('桌面底色取 body 渐变的 --bg1 #eef2f7，并用作 scaffold 底', () {
      expect(AppTheme.desktopBg, const Color(0xFFEEF2F7));
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFEEF2F7));
    });

    test('圆角四档：壳 18、页面 14、卡片 12、控件 10', () {
      expect(AppTheme.radiusShell, 18);
      expect(AppTheme.radiusPage, 14);
      expect(AppTheme.radiusCard, 12);
      expect(AppTheme.radiusControl, 10);
    });

    test('字号五档：18、15、13、12、11', () {
      expect(AppTheme.fontPageTitle, 18);
      expect(AppTheme.fontCardTitle, 15);
      expect(AppTheme.fontBody, 13);
      expect(AppTheme.fontMeta, 12);
      expect(AppTheme.fontBadge, 11);
    });

    test('light 主题能构建且主色一致', () {
      final theme = AppTheme.light;
      expect(theme.colorScheme.primary, AppTheme.primary);
      expect(theme.useMaterial3, isTrue);
    });

    test('全应用统一微软雅黑：fontFamily 是 Microsoft YaHei，fallback 覆盖中文名', () {
      // 《页面操作流程》第 1 行：任何地方出现的字都要是微软雅黑。
      expect(AppTheme.fontFamily, 'Microsoft YaHei');
      expect(AppTheme.light.textTheme.bodyMedium!.fontFamily, AppTheme.fontFamily);
      expect(AppTheme.light.textTheme.bodyMedium!.fontFamilyFallback, contains('微软雅黑'));
    });
  });
}
