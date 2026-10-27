import 'package:ai_pet_assistant/app/app.dart';
import 'package:ai_pet_assistant/app/main_shell.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/features/pet/pet_frame.dart';
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_on_main.dart';
import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_pet_stage_port.dart';

/// 主界面壳的样式，逐条对着 `prototype/整体原型.html` 的 CSS 取值。
///
/// 原型里主界面是 `.main`（壳）＋ `.tabs`/`.tab`（标签排）＋ `.sheet`（页面纸），
/// 这里的断言直接写原型上的数字，不读实现里的常量，改实现时测试才会真的响。
void main() {
  late AppDb db;
  late FakePetStagePort port;
  late ProviderContainer container;

  setUp(() {
    db = AppDb.memory();
    port = FakePetStagePort();
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        petStagePortProvider.overrideWithValue(port),
        petPollIntervalProvider.overrideWithValue(null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    port.dispose();
    await db.close();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AiPetApp()),
    );
    await tester.pumpAndSettle();
  }

  Container shellOf(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const ValueKey<String>('main-shell')));

  Container sheetOf(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const ValueKey<String>('main-sheet')));

  AnimatedContainer tabBoxOf(WidgetTester tester, MainTab tab) =>
      tester.widget<AnimatedContainer>(find.byKey(ValueKey<String>('tab-box-${tab.name}')));

  /// 标签里那行字的实际样式。字包在 `AnimatedDefaultTextStyle` 里，
  /// `Text` 自己没有样式，得从渲染出来的 `RichText` 上读。
  TextStyle tabStyleOf(WidgetTester tester, MainTab tab) => tester
      .widget<RichText>(
        find.descendant(
          of: find.byKey(ValueKey<String>('tab-box-${tab.name}')),
          matching: find.byType(RichText),
        ),
      )
      .text
      .style!;

  group('壳', () {
    // 原型 `.main`：`padding:16px 18px 18px`。顶部那 16 像素只当留白，不再是拖动区。
    testWidgets('内边距上 16（留白）、左右与下 18', (tester) async {
      await pumpShell(tester);

      final top = tester.widget<SizedBox>(find.byKey(const ValueKey<String>('main-shell-top')));
      expect(top.height, 16);
      // 主界面不许拖：顶部不再有可抓的那条。
      expect(find.byKey(const ValueKey<String>('main-shell-drag')), findsNothing);

      final body = tester.widget<Padding>(find.byKey(const ValueKey<String>('main-shell-body')));
      expect(body.padding, const EdgeInsets.fromLTRB(18, 0, 18, 18));
    });

    // 主界面档的窗口是「主界面 ∪ 宠物」，宠物贴桌面边缘，壳只能占主界面那一块。
    testWidgets('主界面档壳缩到主界面那一块，不铺满整窗', (tester) async {
      // 1920×1080 屏上的主界面档：主界面 1344×756 居中，宠物坐在右边中下。
      const main = Rect.fromLTWH(288, 156, 1344, 756);
      container.read(petFrameProvider.notifier).apply(
        const PetFrame(
          size: Size(1920, 1080),
          pet: Rect.fromLTWH(1632, 598, 288, 288),
          main: main,
        ),
      );
      await pumpShell(tester);

      expect(tester.getRect(find.byKey(const ValueKey<String>('main-shell'))), main);
    });

    // 原型 `.main`：背景 #f2f6fc、`border:1px solid var(--line)`、`border-radius:18px`。
    testWidgets('底色是壳色，边框一像素，圆角 18', (tester) async {
      await pumpShell(tester);
      final decoration = shellOf(tester).decoration! as BoxDecoration;

      expect(decoration.color, const Color(0xFFF2F6FC));
      expect(decoration.borderRadius, BorderRadius.circular(18));
      expect((decoration.border! as Border).top.color, const Color(0xFFC9D4E3));
      expect((decoration.border! as Border).top.width, 1);
    });

    // 原型 `.tabs` 里只有五个标签，产品名标题不在原型里，加它就是偏离。
    testWidgets('顶部没有产品名标题', (tester) async {
      await pumpShell(tester);
      expect(find.text('AI桌宠日常助手'), findsNothing);
    });

    // 原型 `.sheet`：`padding:26px 30px`。
    testWidgets('页面纸内边距竖直 26、水平 30', (tester) async {
      await pumpShell(tester);
      expect(sheetOf(tester).padding, const EdgeInsets.symmetric(horizontal: 30, vertical: 26));
    });

    // 原型 `.sheet`：白底、`border:1px solid var(--line)`、`border-radius:14px`。
    testWidgets('页面纸白底、细边框、圆角 14', (tester) async {
      await pumpShell(tester);
      final decoration = sheetOf(tester).decoration! as BoxDecoration;

      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(14));
      expect((decoration.border! as Border).top.color, const Color(0xFFC9D4E3));
    });
  });

  group('标签排', () {
    // 原型 `.tabs`：`gap:8px`。
    testWidgets('标签之间隔 8', (tester) async {
      await pumpShell(tester);

      for (final tab in MainTab.values) {
        final pad = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byKey(ValueKey<String>('tab-box-${tab.name}')),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(pad.padding, const EdgeInsets.only(right: 8), reason: tab.label);
      }
    });

    // 原型 `.tab`：`min-height:38px; padding:0 20px; font-size:14px; border-radius:12px`。
    testWidgets('标签最低 38 高、水平内边距 20、圆角 12、字 14', (tester) async {
      await pumpShell(tester);

      for (final tab in MainTab.values) {
        final box = tabBoxOf(tester, tab);
        expect(box.constraints?.minHeight, 38, reason: tab.label);
        expect(box.padding, const EdgeInsets.symmetric(horizontal: 20), reason: tab.label);
        expect(
          (box.decoration! as BoxDecoration).borderRadius,
          BorderRadius.circular(12),
          reason: tab.label,
        );

        // 原型 `.tab{transition:… .15s}`：换态走 150ms，不硬跳。
        expect(box.duration, const Duration(milliseconds: 150), reason: tab.label);

        expect(tabStyleOf(tester, tab).fontSize, 14, reason: tab.label);
      }
    });

    // 原型 `.tab.on`：白底、`border-color:var(--line)`、`font-weight:600`、
    // `box-shadow:0 2px 8px rgba(30,50,80,.08)`。
    testWidgets('选中的那块：白底、细边框、字重 600、带浅影', (tester) async {
      await pumpShell(tester);
      final box = tabBoxOf(tester, MainTab.solo);
      final decoration = box.decoration! as BoxDecoration;

      expect(decoration.color, Colors.white);
      expect((decoration.border! as Border).top.color, const Color(0xFFC9D4E3));
      expect(decoration.boxShadow, hasLength(1));
      expect(decoration.boxShadow!.single.offset, const Offset(0, 2));
      expect(decoration.boxShadow!.single.blurRadius, 8);
      expect(tabStyleOf(tester, MainTab.solo).fontWeight, FontWeight.w600);

      // 字色也走 150ms，跟底色同一条节奏。
      final textAnimation = tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tab-box-solo')),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
      expect(textAnimation.duration, const Duration(milliseconds: 150));
    });

    // 原型 `.tab`：没选中的 `background:transparent; border:1px solid transparent`，
    // 也没有阴影，只有文字。
    testWidgets('没选中的那几块：透明底、透明边框、没有影子', (tester) async {
      await pumpShell(tester);

      for (final tab in MainTab.values) {
        if (tab == MainTab.solo) continue;
        final decoration = tabBoxOf(tester, tab).decoration! as BoxDecoration;

        expect(decoration.color, Colors.transparent, reason: tab.label);
        expect((decoration.border! as Border).top.color, Colors.transparent, reason: tab.label);
        expect(decoration.boxShadow, isNull, reason: tab.label);
        expect(tabStyleOf(tester, tab).fontWeight, FontWeight.w400, reason: tab.label);
      }
    });

    // 原型 `.tab`：字色 `var(--ink2)`，选中或悬停提到 `var(--ink)`。
    testWidgets('未选中的字色降一档，选中的用主墨色', (tester) async {
      await pumpShell(tester);

      expect(tabStyleOf(tester, MainTab.solo).color, const Color(0xFF1F2937));
      expect(tabStyleOf(tester, MainTab.projects).color, const Color(0xFF5B6676));
    });

    // 原型 `.tab:hover{color:var(--ink)}`：只提字色，底、边、影都不动。
    testWidgets('悬停只把字色提到主墨色', (tester) async {
      await pumpShell(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();

      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey<String>('tab-projects'))));
      await tester.pumpAndSettle();

      expect(tabStyleOf(tester, MainTab.projects).color, const Color(0xFF1F2937));
      final hovered = tabBoxOf(tester, MainTab.projects).decoration! as BoxDecoration;
      expect(hovered.color, Colors.transparent);
      expect((hovered.border! as Border).top.color, Colors.transparent);
      expect(hovered.boxShadow, isNull);

      // 指针移开，字色退回降一档的灰。
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(tabStyleOf(tester, MainTab.projects).color, const Color(0xFF5B6676));
    });

    // 原型 `.tabs` 的顺序：独立事项、我的项目、我的记录、想法盒、设置。
    testWidgets('五个标签的文案与顺序照原型排', (tester) async {
      await pumpShell(tester);

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList();

      expect(labels.take(5).toList(), ['独立事项', '我的项目', '我的记录', '想法盒', '设置']);
      expect(MainTab.values.map((tab) => tab.label).toList(), labels.take(5));
    });
  });

  group('收起', () {
    // PRD 418：展开态桌宠是主界面唯一的关闭入口，点它回常驻态。
    testWidgets('点展开态桌宠收起主界面', (tester) async {
      await pumpShell(tester);
      container.read(petNotifierProvider.notifier).openMain();
      await tester.pump();

      expect(find.byType(PetOnMain), findsOneWidget);
      await tester.tap(find.byType(PetOnMain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey<String>('main-shell')), findsNothing);
      expect(port.calls, contains('collapsed'));
    });

  testWidgets('界面挂中文本地化，选日期的日历跟着说中文', (tester) async {
    await pumpShell(tester);

    final context = tester.element(find.byKey(const ValueKey<String>('main-shell')));
    // 使用者 2026-10-26：项目新建页的截止日期要中文日历。
    // showDatePicker 的年月、星期、按钮全取自 MaterialLocalizations，这里验它。
    final material = MaterialLocalizations.of(context);
    expect(Localizations.localeOf(context).languageCode, 'zh');
    expect(material.datePickerHelpText, '选择日期');
    expect(material.cancelButtonLabel, '取消');
    expect(material.okButtonLabel, '确定');
  });
  });

  group('主界面上的桌宠', () {
    testWidgets('拖宠物：逐帧喂位移、抬手收尾，主界面那块不动', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1920×1080 屏上的主界面档：主界面 1344×756 居中，宠物坐在右边。
      container.read(petFrameProvider.notifier).apply(
        const PetFrame(
          size: Size(1920, 1080),
          pet: Rect.fromLTWH(1632, 598, 288, 288),
          main: Rect.fromLTWH(288, 156, 1344, 756),
        ),
      );
      await pumpShell(tester);
      container.read(petNotifierProvider.notifier).openMain();
      await tester.pump();

      final petFinder = find.byType(PetOnMain);
      expect(petFinder, findsOneWidget);
      final shellBefore = tester.getRect(find.byKey(const ValueKey<String>('main-shell')));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final start = tester.getCenter(petFinder);
      await mouse.moveTo(start);
      await mouse.down(start);
      await mouse.moveBy(const Offset(10, 0));
      await tester.pump();
      await mouse.moveBy(const Offset(20, 10));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(port.drags, 1);
      // 起手那一下只用来过 slop，后面那次位移逐帧喂给窗口层。
      expect(port.offsets, const [Offset(20, 10)]);
      expect(port.dragEnds, 1);
      // 使用者 2026-10-27：只能拖桌宠，主界面不许跟着动。
      expect(tester.getRect(find.byKey(const ValueKey<String>('main-shell'))), shellBefore);
    });
  });
}
