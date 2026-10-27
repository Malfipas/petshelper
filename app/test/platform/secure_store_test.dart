import 'dart:io';
import 'dart:typed_data';

import 'package:ai_pet_assistant/platform/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真跑一次 DPAPI：证明写下去的东西确实被系统加密了、也确实解得回来。
///
/// 不碰真实应用目录，key 文件落在临时目录；只在 Windows 上有意义。
void main() {
  late Directory dir;
  late File file;
  late SystemSecureKeyGateway store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ai_pet_key_');
    file = File('${dir.path}/${SystemSecureKeyGateway.fileName}');
    store = SystemSecureKeyGateway(keyFile: () async => file);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('写进去的 key 能原样读回来，文件里看不到明文', () async {
    await store.write('sk-live-abcdef1234567890');

    expect(await store.read(), 'sk-live-abcdef1234567890');

    final raw = await file.readAsBytes();
    expect(
      String.fromCharCodes(raw),
      isNot(contains('sk-live')),
      reason: '落盘的必须是密文，不能一眼看出 key',
    );
  }, skip: !Platform.isWindows);

  test('清除之后读不到，文件也没了', () async {
    await store.write('sk-live-abcdef');
    expect(await store.read(), isNotNull);

    await store.clear();

    expect(await store.read(), isNull);
    expect(await file.exists(), isFalse);
  }, skip: !Platform.isWindows);

  test('没存过时读出来是 null', () async {
    expect(await store.read(), isNull);
  }, skip: !Platform.isWindows);

  test('文件被改坏就当作没存过，不抛异常', () async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(List<int>.filled(48, 7)));

    expect(await store.read(), isNull);
  }, skip: !Platform.isWindows);

  test('写入会顶掉旧的 key', () async {
    await store.write('sk-old');
    await store.write('sk-new');

    expect(await store.read(), 'sk-new');
  }, skip: !Platform.isWindows);
}
