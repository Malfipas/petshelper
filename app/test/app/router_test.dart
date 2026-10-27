import 'package:ai_pet_assistant/app/app.dart';
import 'package:ai_pet_assistant/app/main_shell.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/app/routes.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_pet_stage_port.dart';

/// 导航：五标签能互相切换、地址能直接落到某一页、走错地址不白屏。
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

  /// 常驻态那页有呼吸动画，永远 settle 不下来，只能按时长 pump。
  Future<void> pumpApp(WidgetTester tester, {String? at, bool settle = true}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AiPetApp(initialLocation: at),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder pageKey(String name) => find.byKey(ValueKey<String>('page-$name'));

  group('主界面五个标签', () {
    testWidgets('默认停在独立事项', (tester) async {
      await pumpApp(tester);

      expect(pageKey('solo'), findsOneWidget);
      expect(tester.widget<MainShell>(find.byType(MainShell)).tab, MainTab.solo);
    });

    testWidgets('点标签能一页页切过去，切到哪页就只有哪页', (tester) async {
      await pumpApp(tester);

      for (final tab in MainTab.values) {
        await tester.tap(find.byKey(ValueKey<String>('tab-${tab.name}')));
        await tester.pumpAndSettle();

        expect(pageKey(tab.name), findsOneWidget, reason: '${tab.label}没出来');
        for (final other in MainTab.values) {
          if (other == tab) continue;
          expect(pageKey(other.name), findsNothing, reason: '${other.label}没退场');
        }
        expect(tester.widget<MainShell>(find.byType(MainShell)).tab, tab, reason: '高亮没跟着走');
      }
    });

    testWidgets('五个标签的文字都在，顺序与原型一致', (tester) async {
      await pumpApp(tester);

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList();

      for (final tab in MainTab.values) {
        expect(labels, contains(tab.label), reason: '少了「${tab.label}」');
      }
    });
  });

  group('地址直达', () {
    testWidgets('地址写某一页，打开就停在那儿', (tester) async {
      await pumpApp(tester, at: MainTab.ideas.path);

      expect(pageKey('ideas'), findsOneWidget);
      expect(tester.widget<MainShell>(find.byType(MainShell)).tab, MainTab.ideas);
    });

    testWidgets('常驻态与悬停面板各是一个落点', (tester) async {
      await pumpApp(tester, at: AppRoutes.pet, settle: false);
      expect(pageKey('pet'), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });

    testWidgets('悬停面板单独成页时也是同一套路由', (tester) async {
      await pumpApp(tester, at: AppRoutes.panel);
      expect(pageKey('panel'), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });

    // PRD 418：主界面档按 Esc 回常驻态，不用去找关闭按钮（原型也没有）。
    testWidgets('主界面档按 Esc 回常驻态', (tester) async {
      await pumpApp(tester);
      expect(find.byType(MainShell), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MainShell), findsNothing);
      expect(pageKey('pet'), findsOneWidget);
    });

    // PRD 419：每次重新打开都回到独立事项，不记上次停在哪页。
    testWidgets('停在别的页收起，再打开落回独立事项', (tester) async {
      await pumpApp(tester, at: MainTab.records.path);
      expect(pageKey('records'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(pageKey('pet'), findsOneWidget);

      // 常驻态桌宠取 `PetFrame.fallback` 的矩形：窗口内 0,0 起 240 见方。
      await tester.tapAt(const Offset(120, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(pageKey('solo'), findsOneWidget);
      expect(tester.widget<MainShell>(find.byType(MainShell)).tab, MainTab.solo);
    });

    testWidgets('走到不认识的地址退回独立事项，不白屏', (tester) async {
      await pumpApp(tester, at: '/nope');

      expect(pageKey('solo'), findsOneWidget);
    });
  });

  group('标签与路径', () {
    test('按路径能找回标签', () {
      expect(MainTab.byPath('/main/records'), MainTab.records);
      expect(MainTab.byPath('/pet'), isNull);
      expect(MainTab.byPath('/main/nothing'), isNull);
    });

    test('五个标签的路径互不相同，也都以 /main 开头', () {
      final paths = MainTab.values.map((tab) => tab.path).toList();

      expect(paths.toSet().length, paths.length);
      for (final path in paths) {
        expect(path.startsWith('/main/'), isTrue, reason: '$path 不在主界面下');
      }
    });
  });
}
