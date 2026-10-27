import 'package:ai_pet_assistant/app/app.dart';
import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/features/pet/pet_notifier.dart';
import 'package:ai_pet_assistant/features/pet/pet_stage_port.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_pet_stage_port.dart';

void main() {
  // 主界面壳按原型只放五标签，不放产品名；默认落点是独立事项。
  testWidgets('空壳能构建并落到独立事项', (tester) async {
    final db = AppDb.memory();
    final port = FakePetStagePort();
    addTearDown(() async {
      port.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDbProvider.overrideWithValue(db),
          petStagePortProvider.overrideWithValue(port),
          petPollIntervalProvider.overrideWithValue(null),
        ],
        child: const AiPetApp(),
      ),
    );

    expect(find.byKey(const ValueKey<String>('page-solo')), findsOneWidget);
    expect(find.text('AI桌宠日常助手'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
