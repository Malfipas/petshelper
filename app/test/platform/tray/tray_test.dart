import 'dart:async';

import 'package:ai_pet_assistant/platform/tray/tray.dart';
import 'package:flutter_test/flutter_test.dart';

/// 托盘点击翻成动作：点哪项做哪件事，收摊之后不再转发。
void main() {
  group('点击转发', () {
    test('点「唤出主界面」只叫唤出', () async {
      final driver = _FakeTrayDriver();
      final calls = <String>[];
      final controller = TrayController(
        driver,
        onShowMain: () => calls.add('show'),
        onQuit: () => calls.add('quit'),
      );
      await controller.start();

      driver.tap(TrayAction.showMain);
      await pumpEventQueue();

      expect(driver.installs, 1);
      expect(calls, ['show']);
    });

    test('点「退出」只叫退出', () async {
      final driver = _FakeTrayDriver();
      final calls = <String>[];
      final controller = TrayController(
        driver,
        onShowMain: () => calls.add('show'),
        onQuit: () => calls.add('quit'),
      );
      await controller.start();

      driver.tap(TrayAction.quit);
      await pumpEventQueue();

      expect(calls, ['quit']);
    });
  });

  group('收摊', () {
    test('停掉之后点击不再转发，图标与菜单被卸掉', () async {
      final driver = _FakeTrayDriver();
      final calls = <String>[];
      final controller = TrayController(
        driver,
        onShowMain: () => calls.add('show'),
        onQuit: () => calls.add('quit'),
      );
      await controller.start();

      await controller.stop();
      driver.tap(TrayAction.quit);
      await pumpEventQueue();

      expect(driver.removes, 1);
      expect(calls, isEmpty);
    });
  });

  group('装不上', () {
    test('系统没有通知区时返回 false，不把启动带崩', () async {
      final driver = _FakeTrayDriver(failInstall: true);
      final calls = <String>[];
      final controller = TrayController(
        driver,
        onShowMain: () => calls.add('show'),
        onQuit: () => calls.add('quit'),
      );

      expect(await controller.start(), isFalse);
      expect(await controller.start(), isFalse);
      expect(calls, isEmpty);
    });

    test('装得上时返回 true', () async {
      final controller = TrayController(_FakeTrayDriver(), onShowMain: () {}, onQuit: () {});

      expect(await controller.start(), isTrue);
    });
  });
}

/// 假托盘：点菜单就是往流里塞一条，代替 native 事件。
class _FakeTrayDriver implements TrayDriver {
  _FakeTrayDriver({this.failInstall = false});

  final bool failInstall;
  final StreamController<TrayAction> _actions = StreamController<TrayAction>.broadcast();
  int installs = 0;
  int removes = 0;

  @override
  Stream<TrayAction> get actions => _actions.stream;

  @override
  Future<void> install() async {
    installs++;
    if (failInstall) throw StateError('没有通知区');
  }

  @override
  Future<void> remove() async {
    removes++;
  }

  void tap(TrayAction action) => _actions.add(action);
}
