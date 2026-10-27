import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' show AppDb;
import 'package:ai_pet_assistant/data/repository/settings_repository.dart';
import 'package:ai_pet_assistant/domain/port/secure_key_gateway.dart';
import 'package:ai_pet_assistant/features/settings/settings_notifier.dart';
import 'package:ai_pet_assistant/features/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假的系统凭据：只记存了什么，不碰注册表与 Keychain。
class _FakeKeyStore implements SecureKeyGateway {
  String? stored;
  int writes = 0;
  int clears = 0;

  /// 打开后写与清都抛错，用来验证界面不假装成功。
  bool broken = false;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async {
    if (broken) throw PlatformException(code: 'denied');
    writes += 1;
    stored = key;
  }

  @override
  Future<void> clear() async {
    if (broken) throw PlatformException(code: 'denied');
    clears += 1;
    stored = null;
  }
}

void main() {
  late AppDb db;
  late ProviderContainer container;
  late _FakeKeyStore keyStore;

  /// 剪贴板收到的内容；null 表示系统没给。
  String? clipboard;
  bool clipboardWorks = true;

  setUp(() {
    db = AppDb.memory();
    keyStore = _FakeKeyStore();
    clipboard = null;
    clipboardWorks = true;
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        secureKeyGatewayProvider.overrideWithValue(keyStore),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 起一个空树，好让 `pump` 推进按钮闪光的计时。
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.read(settingsProvider);
    await tester.pump();
  }

  /// 接管系统剪贴板。`works` 为假时抛错，走「不可用」那条路。
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

  testWidgets('进页读两条地址，库里空着就用占位值', (tester) async {
    await boot(tester);
    final state = container.read(settingsProvider);

    expect(state.demoUrl, SettingsRepository.demoUrlPlaceholder);
    expect(state.repoUrl, SettingsRepository.repoUrlPlaceholder);
    expect(state.saveLabel, '保存');
    expect(state.clearLabel, '清除');
    expect(state.copyLabel(demo: true), '复制');
  });

  testWidgets('库里已经有地址就用库里的，不再顶占位', (tester) async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.setDemoUrl('https://v.example.com/a.mp4');
    await repo.setRepoUrl('https://git.example.com/a');

    await boot(tester);

    expect(container.read(settingsProvider).demoUrl, 'https://v.example.com/a.mp4');
    expect(container.read(settingsProvider).repoUrl, 'https://git.example.com/a');
  });

  testWidgets('存下 key：写凭据、置为已配，按钮闪「已保存」再复原', (tester) async {
    await boot(tester);
    final notifier = container.read(settingsProvider.notifier);

    await notifier.save('  sk-test-123  ');
    await tester.pump();

    expect(keyStore.stored, 'sk-test-123');
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isTrue);
    expect(container.read(settingsProvider).saveLabel, '已保存');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(container.read(settingsProvider).saveLabel, '保存');
  });

  testWidgets('输入为空按保存：当清除处理，不写凭据', (tester) async {
    await boot(tester);
    final notifier = container.read(settingsProvider.notifier);
    await container.read(settingsRepositoryProvider).setKeyConfigured(true);
    keyStore.stored = 'sk-old';

    await notifier.save('   ');
    await tester.pump();

    expect(keyStore.stored, isNull);
    expect(keyStore.writes, 0);
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isFalse);
    // 保存按钮显示「已清除」，清除按钮不动。
    expect(container.read(settingsProvider).saveLabel, '已清除');
    expect(container.read(settingsProvider).clearLabel, '清除');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(container.read(settingsProvider).saveLabel, '保存');
  });

  testWidgets('清除：抹掉凭据并关掉全站 AI 开关', (tester) async {
    await boot(tester);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.save('sk-test');
    await tester.pump();

    await notifier.clear();
    await tester.pump();

    expect(keyStore.stored, isNull);
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isFalse);
    expect(container.read(settingsProvider).clearLabel, '已清除');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(container.read(settingsProvider).clearLabel, '清除');
  });

  testWidgets('凭据写不进去：给一行提醒，不假装存好了', (tester) async {
    await boot(tester);
    final notifier = container.read(settingsProvider.notifier);
    keyStore.broken = true;

    await notifier.save('sk-test');
    await tester.pump();

    expect(keyStore.stored, isNull);
    expect((await container.read(settingsRepositoryProvider).current()).keyConfigured, isFalse);
    expect(container.read(settingsProvider).alert, '保存失败，请重试');
    expect(container.read(settingsProvider).saveLabel, '保存');

    await tester.pump(const Duration(seconds: 4));
    expect(container.read(settingsProvider).alert, '');
  });

  testWidgets('眼睛来回切明文', (tester) async {
    await boot(tester);
    final notifier = container.read(settingsProvider.notifier);

    expect(container.read(settingsProvider).revealed, isFalse);
    notifier.toggleReveal();
    expect(container.read(settingsProvider).revealed, isTrue);
    notifier.toggleReveal();
    expect(container.read(settingsProvider).revealed, isFalse);
  });

  testWidgets('复制地址：进剪贴板，按钮闪「已复制」再复原', (tester) async {
    mockClipboard(tester);
    await boot(tester);

    await container.read(settingsProvider.notifier).copyDemo();
    await tester.pump();

    expect(clipboard, SettingsRepository.demoUrlPlaceholder);
    expect(container.read(settingsProvider).copyLabel(demo: true), '已复制');
    // 另一行的复制按钮不受影响。
    expect(container.read(settingsProvider).copyLabel(demo: false), '复制');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(container.read(settingsProvider).copyLabel(demo: true), '复制');
  });

  testWidgets('剪贴板不可用：提醒一句并请求选中那一行', (tester) async {
    mockClipboard(tester);
    clipboardWorks = false;
    await boot(tester);

    await container.read(settingsProvider.notifier).copyRepo();
    await tester.pump();

    final state = container.read(settingsProvider);
    expect(clipboard, isNull);
    expect(state.alert, '剪贴板不可用，地址已选中，请按 Ctrl+C 复制');
    expect(state.selectTarget, 'repo');
    expect(state.selectTick, 1);
    expect(state.copyLabel(demo: false), '复制');

    // 再失败一次也要重新请求选中，所以轮次继续加。
    await container.read(settingsProvider.notifier).copyRepo();
    await tester.pump();
    expect(container.read(settingsProvider).selectTick, 2);

    await tester.pump(const Duration(seconds: 4));
    expect(container.read(settingsProvider).alert, '');
  });

  testWidgets('复制成功会把上一次的提醒收掉', (tester) async {
    mockClipboard(tester);
    clipboardWorks = false;
    await boot(tester);
    await container.read(settingsProvider.notifier).copyDemo();
    await tester.pump();
    expect(container.read(settingsProvider).alert, isNotEmpty);

    // 只翻开关，不重装剪贴板——重装会让测试悬住。
    clipboardWorks = true;
    await container.read(settingsProvider.notifier).copyDemo();
    await tester.pump();

    expect(container.read(settingsProvider).alert, '');
    expect(container.read(settingsProvider).flash, SettingsFlash.copiedDemo);

    // 把闪光与那条早先的提醒计时走完，免得测试收尾时还剩计时器。
    await tester.pump(const Duration(seconds: 5));
  });
}
