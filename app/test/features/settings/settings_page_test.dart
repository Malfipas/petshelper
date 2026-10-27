import 'package:ai_pet_assistant/app/key_configured.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' show AppDb;
import 'package:ai_pet_assistant/data/repository/settings_repository.dart';
import 'package:ai_pet_assistant/domain/port/secure_key_gateway.dart';
import 'package:ai_pet_assistant/features/settings/settings_page.dart';
import 'package:ai_pet_assistant/platform/autostart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假的系统凭据，只记存了什么。
class _FakeKeyStore implements SecureKeyGateway {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async => stored = key;

  @override
  Future<void> clear() async => stored = null;
}

/// 假的开机自启，只记开没开。`accept=false` 用来演系统不接受的情况。
class _FakeAutoStart implements AutoStart {
  bool on = true;
  bool accept = true;
  int writes = 0;

  @override
  Future<bool> isEnabled() async => on;

  @override
  Future<bool> enable() async {
    writes++;
    if (!accept) return false;
    on = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    writes++;
    if (!accept) return false;
    on = false;
    return true;
  }
}

void main() {
  late AppDb db;
  late ProviderContainer container;
  late _FakeKeyStore keyStore;
  late _FakeAutoStart autoStart;

  String? clipboard;
  bool clipboardWorks = true;

  setUp(() {
    db = AppDb.memory();
    keyStore = _FakeKeyStore();
    autoStart = _FakeAutoStart();
    clipboard = null;
    clipboardWorks = true;
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        secureKeyGatewayProvider.overrideWithValue(keyStore),
        autoStartProvider.overrideWithValue(autoStart),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 704, height: 560, child: SettingsPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 接管系统剪贴板。
  void mockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method != 'Clipboard.setData') return null;
        if (!clipboardWorks) throw PlatformException(code: 'unavailable');
        final args = call.arguments as Map<Object?, Object?>;
        clipboard = args['text'] as String?;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  TextField keyField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const ValueKey<String>('settings-key')));

  testWidgets('进页看到标题、两块卡片与占位地址', (tester) async {
    await pumpPage(tester);

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('模型 API key'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('项目地址'), findsOneWidget);
    expect(find.text('项目仓库'), findsOneWidget);

    // 演示视频那一行暂时隐藏（页面里相关代码被注释掉了），等真实链接定了再放开。
    expect(find.text('演示视频'), findsNothing);
    expect(find.byKey(const ValueKey<String>('settings-url-demo')), findsNothing);
    expect(find.byKey(const ValueKey<String>('settings-copy-demo')), findsNothing);

    // 地址是只读的，值取占位常量。
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey<String>('settings-url-repo')))
          .controller!
          .text,
      SettingsRepository.repoUrlPlaceholder,
    );
  });

  testWidgets('key 输入框默认掩码，点眼睛切明文再切回', (tester) async {
    await pumpPage(tester);
    expect(keyField(tester).obscureText, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('settings-eye')));
    await tester.pumpAndSettle();
    expect(keyField(tester).obscureText, isFalse);

    await tester.tap(find.byKey(const ValueKey<String>('settings-eye')));
    await tester.pumpAndSettle();
    expect(keyField(tester).obscureText, isTrue);
  });

  testWidgets('填了 key 点保存：进凭据、置为已配，按钮先显示「已保存」', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-key')),
      'sk-live-abc',
    );
    await tester.tap(find.byKey(const ValueKey<String>('settings-save')));
    await tester.pumpAndSettle();

    expect(keyStore.stored, 'sk-live-abc');
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isTrue);
    expect(find.text('已保存'), findsOneWidget);

    // 输入框保留刚敲的内容，不清空。
    expect(keyField(tester).controller!.text, 'sk-live-abc');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('已保存'), findsNothing);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('点清除：抹掉凭据、清空输入框并关掉全站 AI 开关', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-key')),
      'sk-live-abc',
    );
    await tester.tap(find.byKey(const ValueKey<String>('settings-save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('settings-clear')));
    await tester.pumpAndSettle();

    expect(keyStore.stored, isNull);
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isFalse);
    expect(keyField(tester).controller!.text, '');
    expect(find.text('已清除'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('已清除'), findsNothing);
    expect(find.text('清除'), findsOneWidget);
  });

  testWidgets('把内容删光再点保存，按清除走', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-key')),
      'sk-live-abc',
    );
    await tester.tap(find.byKey(const ValueKey<String>('settings-save')));
    await tester.pumpAndSettle();
    expect(keyStore.stored, 'sk-live-abc');

    await tester.enterText(find.byKey(const ValueKey<String>('settings-key')), '   ');
    await tester.tap(find.byKey(const ValueKey<String>('settings-save')));
    await tester.pumpAndSettle();

    expect(keyStore.stored, isNull);
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isFalse);
    // 保存按钮显示「已清除」，清除按钮仍是「清除」。
    expect(find.text('已清除'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  // 演示视频那一行暂时隐藏，页面上没有这个键，这条用例等那一行回来再放开。
  // testWidgets('复制演示视频：进剪贴板，按钮变「已复制」再复原', (tester) async {
  //   mockClipboard(tester);
  //   await pumpPage(tester);
  //
  //   await tester.tap(find.byKey(const ValueKey<String>('settings-copy-demo')));
  //   await tester.pumpAndSettle();
  //
  //   expect(clipboard, SettingsRepository.demoUrlPlaceholder);
  //   expect(find.text('已复制'), findsOneWidget);
  //
  //   await tester.pump(const Duration(milliseconds: 1600));
  //   expect(find.text('已复制'), findsNothing);
  //   expect(find.text('复制'), findsNWidgets(2));
  // });

  testWidgets('复制项目仓库：进剪贴板，按钮变「已复制」再复原', (tester) async {
    mockClipboard(tester);
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey<String>('settings-copy-repo')));
    await tester.pumpAndSettle();

    expect(clipboard, SettingsRepository.repoUrlPlaceholder);
    expect(find.text('已复制'), findsOneWidget);
    // 页面上只剩这一行地址，它此刻显示「已复制」，所以一个「复制」都不该在。
    expect(find.text('复制'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('已复制'), findsNothing);
    expect(find.text('复制'), findsOneWidget);
  });

  testWidgets('剪贴板不可用：给一句提醒，并把那行地址选中', (tester) async {
    mockClipboard(tester);
    clipboardWorks = false;
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey<String>('settings-copy-repo')));
    await tester.pumpAndSettle();

    expect(find.text('剪贴板不可用，地址已选中，请按 Ctrl+C 复制'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey<String>('settings-url-repo')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    // 抄不到就别声称抄到了。
    expect(find.text('已复制'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('剪贴板不可用，地址已选中，请按 Ctrl+C 复制'), findsNothing);
  });

  testWidgets('没配过 key 时标题旁写「未配置」', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const ValueKey<String>('settings-key-state')), findsOneWidget);
    expect(find.text('未配置'), findsOneWidget);
  });

  testWidgets('配过 key 时标题旁写「已配置」，输入框仍留空、只提示可替换', (tester) async {
    await container.read(settingsRepositoryProvider).setKeyConfigured(true);

    await pumpPage(tester);

    expect(find.text('已配置'), findsOneWidget);
    expect(find.text('未配置'), findsNothing);
    // 不回显 key 本身，输入框是空的。
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey<String>('settings-key')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('已配置，输入新的 key 可替换'), findsOneWidget);
  });

  testWidgets('存下 key 后状态字当场从「未配置」变成「已配置」，切页回来也还在', (tester) async {
    await pumpPage(tester);
    expect(find.text('未配置'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('settings-key')), 'sk-live');
    await tester.tap(find.byKey(const ValueKey<String>('settings-save')));
    await tester.pumpAndSettle();

    expect(find.text('已配置'), findsOneWidget);
    expect(keyStore.stored, 'sk-live');
    // 存完那一刻全站开关也翻过来了，面板与别的页不用等重进。
    expect(container.read(keyConfiguredProvider), isTrue);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('开机自启的开关按注册表真值画，点一下就写回去', (tester) async {
    await pumpPage(tester);

    final toggle = find.byKey(const ValueKey<String>('settings-autostart'));
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(autoStart.writes, 1);
    expect(autoStart.on, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('系统不接受的改动不回显成功，而是弹一句', (tester) async {
    autoStart.accept = false;
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey<String>('settings-autostart')));
    await tester.pumpAndSettle();

    // 注册表没变，开关还在原位。
    expect(tester.widget<Switch>(find.byKey(const ValueKey<String>('settings-autostart'))).value, isTrue);
    expect(find.textContaining('系统没有撤掉开机自启'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });
}
