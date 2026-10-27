import 'package:ai_pet_assistant/platform/autostart.dart';
import 'package:flutter_test/flutter_test.dart';

/// 自启开关：改完按系统的真实状态回显，不按点下去的那个值。
void main() {
  test('没开过时读出来是关的', () async {
    final controller = AutoStartController(_FakeAutoStart());

    expect(await controller.isOn(), isFalse);
  });

  test('勾上之后是开的，写了一次注册表', () async {
    final autoStart = _FakeAutoStart();
    final controller = AutoStartController(autoStart);

    final result = await controller.setOn(true);
    expect(result.accepted, isTrue);
    expect(result.on, isTrue);
    expect(await controller.isOn(), isTrue);
    expect(autoStart.enables, 1);
  });

  test('撤掉之后是关的', () async {
    final autoStart = _FakeAutoStart()..on = true;
    final controller = AutoStartController(autoStart);

    final result = await controller.setOn(false);
    expect(result.accepted, isTrue);
    expect(result.on, isFalse);
    expect(await controller.isOn(), isFalse);
    expect(autoStart.disables, 1);
  });

  test('系统拒收时开关不装作开了', () async {
    final controller = AutoStartController(_FakeAutoStart(accept: false));

    // 没接受，但真值仍是「关」——这两种情况要分得开，界面才知道该不该提示。
    final result = await controller.setOn(true);
    expect(result.accepted, isFalse);
    expect(result.on, isFalse);
    expect(await controller.isOn(), isFalse);
  });

  test('系统拒收撤不掉时，真值还是「开」', () async {
    final autoStart = _FakeAutoStart(accept: false)..on = true;
    final controller = AutoStartController(autoStart);

    final result = await controller.setOn(false);
    expect(result.accepted, isFalse);
    // 关键：不能因为「没接受」就报成「关」。
    expect(result.on, isTrue);
  });

  test('系统说写了但状态没变，也算没开', () async {
    final controller = AutoStartController(_StuckAutoStart());

    final result = await controller.setOn(true);
    expect(result.accepted, isTrue);
    expect(result.on, isFalse);
  });
}

/// 假自启：按 [accept] 决定系统接不接受，状态记在内存里。
class _FakeAutoStart implements AutoStart {
  _FakeAutoStart({this.accept = true});

  final bool accept;
  bool on = false;
  int enables = 0;
  int disables = 0;

  @override
  Future<bool> isEnabled() async => on;

  @override
  Future<bool> enable() async {
    enables++;
    if (!accept) return false;
    on = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    disables++;
    if (!accept) return false;
    on = false;
    return true;
  }
}

/// 只回「写成功了」却不改状态的系统，用来确认开关会回读。
class _StuckAutoStart implements AutoStart {
  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<bool> enable() async => true;

  @override
  Future<bool> disable() async => true;
}
