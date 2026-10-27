import 'package:ai_pet_assistant/platform/window/drag_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 拖动起手只看按键：左键拖，右键与中键不拖。
void main() {
  test('按住左键才起手', () {
    expect(canStartDrag(primaryButtonMask), isTrue);
  });

  test('右键不拖', () {
    expect(canStartDrag(0x02), isFalse);
  });

  test('中键不拖', () {
    expect(canStartDrag(0x04), isFalse);
  });

  test('没按键时不动', () {
    expect(canStartDrag(0x00), isFalse);
  });

  test('左键与别的键一起按着仍算左键', () {
    expect(canStartDrag(primaryButtonMask | 0x02), isTrue);
  });
}
