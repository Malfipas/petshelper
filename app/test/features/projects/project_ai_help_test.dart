import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/model/planned_step.dart';
import 'package:ai_pet_assistant/features/projects/project_ai_help.dart';
import 'package:ai_pet_assistant/features/projects/project_ai_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AiHelp help, {
    VoidCallback? onToggle,
    ValueChanged<String>? onGoalChanged,
    VoidCallback? onAsk,
    VoidCallback? onApply,
    VoidCallback? onPickAttachments,
    ValueChanged<String>? onRemoveAttachment,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: ProjectAiHelp(
              help: help,
              onToggle: onToggle ?? () {},
              onGoalChanged: onGoalChanged ?? (_) {},
              onAsk: onAsk ?? () {},
              onApply: onApply ?? () {},
              onPickAttachments: onPickAttachments ?? () {},
              onRemoveAttachment: onRemoveAttachment ?? (_) {},
            ),
          ),
        ),
      ),
    );
    // 转圈是永不停的动画，等 settle 只会等到超时。
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('收起时只占一行，点「展开」才把输入框放出来', (tester) async {
    var toggled = 0;
    await pump(tester, const AiHelp(), onToggle: () => toggled++);

    expect(find.text('AI 帮助'), findsOneWidget);
    expect(
      find.text('如果不知道该怎么做，不如让AI帮你拆解任务'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('project-ai-goal')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-toggle')));
    expect(toggled, 1);
  });

  testWidgets('展开后能写目标、点发送，输入会回传', (tester) async {
    final typed = <String>[];
    var asked = 0;
    await pump(
      tester,
      const AiHelp(open: true, goal: '两周写完'),
      onGoalChanged: typed.add,
      onAsk: () => asked++,
    );

    expect(find.byKey(const ValueKey<String>('project-ai-goal')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('project-ai-goal')),
      '两周写完开题',
    );
    expect(typed, contains('两周写完开题'));

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-ask')));
    expect(asked, 1);
  });

  testWidgets('目标空着时发送键按不动', (tester) async {
    var asked = 0;
    await pump(tester, const AiHelp(open: true), onAsk: () => asked++);

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-ask')));
    expect(asked, 0);
  });

  testWidgets('展开后有附件键，点它去挑文件', (tester) async {
    var picked = 0;
    await pump(tester, const AiHelp(open: true), onPickAttachments: () => picked++);

    expect(find.byKey(const ValueKey<String>('project-ai-attach')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('project-ai-attach')));
    expect(picked, 1);
  });

  testWidgets('已选附件摆成一行，点叉把它移掉', (tester) async {
    final removed = <String>[];
    await pump(
      tester,
      AiHelp(
        open: true,
        attachments: <AiAttachment>[
          AiAttachment.image(name: '草图.png', mimeType: 'image/png', base64: 'AAAA'),
          AiAttachment.file(name: '材料.md', content: '# 材料'),
        ],
      ),
      onRemoveAttachment: removed.add,
    );

    expect(find.text('草图.png'), findsOneWidget);
    expect(find.text('材料.md'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-remove-草图.png')));
    expect(removed, <String>['草图.png']);
  });

  testWidgets('附件满了之后附件键按不动', (tester) async {
    var picked = 0;
    await pump(
      tester,
      AiHelp(
        open: true,
        attachments: <AiAttachment>[
          for (var i = 0; i < AiAttachment.maxCount; i++)
            AiAttachment.file(name: '第$i份.md', content: 'x'),
        ],
      ),
      onPickAttachments: () => picked++,
    );

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-attach')));
    expect(picked, 0);
  });

  testWidgets('挑文件被跳过时，灰色那行说明原因', (tester) async {
    await pump(tester, const AiHelp(open: true, hint: '大图.png 超过 4MB，压一下再试'));

    expect(find.byKey(const ValueKey<String>('project-ai-hint')), findsOneWidget);
    expect(find.text('大图.png 超过 4MB，压一下再试'), findsOneWidget);
  });

  testWidgets('拆完之后把回话与每一步摆出来，点应用才回调', (tester) async {
    var applied = 0;
    await pump(
      tester,
      const AiHelp(
        open: true,
        phase: AiPlanPhase.ready,
        reply: '先摸现状',
        steps: [
          PlannedStep(name: '摸现状', task: '列出已有材料'),
          PlannedStep(name: '搭骨架', task: '写三级目录'),
        ],
      ),
      onApply: () => applied++,
    );

    expect(find.byKey(const ValueKey<String>('project-ai-reply')), findsOneWidget);
    expect(find.text('摸现状'), findsOneWidget);
    expect(find.text('写三级目录'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-apply')));
    expect(applied, 1);
  });

  testWidgets('点了应用之后按钮变「已应用」，再点没反应', (tester) async {
    var applied = 0;
    await pump(
      tester,
      const AiHelp(
        open: true,
        phase: AiPlanPhase.ready,
        applied: true,
        steps: [PlannedStep(name: '一步', task: '做事')],
      ),
      onApply: () => applied++,
    );

    expect(find.text('已应用'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('project-ai-apply')));
    expect(applied, 0);
  });

  testWidgets('失败原因写在卡片里，还能再点一次', (tester) async {
    var asked = 0;
    await pump(
      tester,
      const AiHelp(open: true, goal: '写论文', phase: AiPlanPhase.failed, error: '等太久了，请再试一次'),
      onAsk: () => asked++,
    );

    expect(find.byKey(const ValueKey<String>('project-ai-error')), findsOneWidget);
    expect(find.text('等太久了，请再试一次'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('project-ai-apply')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('project-ai-ask')));
    expect(asked, 1);
  });

  testWidgets('正在拆的时候发送键转圈，点不动', (tester) async {
    var asked = 0;
    await pump(
      tester,
      const AiHelp(open: true, goal: '写论文', phase: AiPlanPhase.thinking),
      onAsk: () => asked++,
      settle: false,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('project-ai-ask')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('project-ai-ask')));
    expect(asked, 0);
  });

  testWidgets('输入框的占位文字是「输入你想拆解的任务或任务步骤」', (tester) async {
    await pump(tester, const AiHelp(open: true));

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('project-ai-goal')),
    );
    expect(field.decoration?.hintText, '输入你想拆解的任务或任务步骤');
  });

  testWidgets('发送键的图标逆时针转了 90°', (tester) async {
    await pump(tester, const AiHelp(open: true, goal: '写论文'));

    final rotated = tester.widget<RotatedBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('project-ai-ask')),
        matching: find.byType(RotatedBox),
      ),
    );
    // quarterTurns 顺时针计数，3 格 = 逆时针 90°。
    expect(rotated.quarterTurns, 3);
  });

  testWidgets('按回车直接发出去，不用去点发送键', (tester) async {
    var asked = 0;
    await pump(
      tester,
      const AiHelp(open: true, goal: '两周写完开题'),
      onAsk: () => asked++,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('project-ai-goal')),
      '两周写完开题',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);

    expect(asked, 1);
  });

  testWidgets('空着按回车不发', (tester) async {
    var asked = 0;
    await pump(tester, const AiHelp(open: true), onAsk: () => asked++);

    // 先让输入框拿到焦点，否则这一下回车无处可去。
    await tester.tap(find.byKey(const ValueKey<String>('project-ai-goal')));
    await tester.testTextInput.receiveAction(TextInputAction.send);

    expect(asked, 0);
  });
}
