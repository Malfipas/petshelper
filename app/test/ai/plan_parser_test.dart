import 'package:ai_pet_assistant/ai/plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('老老实实的 JSON 能拆出步骤', () {
    final plan = parsePlan(
      '{"reply":"先跑通再打磨","steps":[{"name":"定范围","task":"写下不做什么"},{"name":"搭骨架","task":"建仓库"}]}',
    );

    expect(plan, isNotNull);
    expect(plan!.reply, '先跑通再打磨');
    expect(plan.steps, hasLength(2));
    expect(plan.steps.first.name, '定范围');
    expect(plan.steps.first.task, '写下不做什么');
  });

  test('套了 ```json 围栏也认', () {
    const text = '```json\n{"reply":"好","steps":[{"name":"拆","task":"写第一条"}]}\n```';

    expect(parsePlan(text)?.steps.single.name, '拆');
  });

  test('JSON 前后各说一句废话也认', () {
    const text = '我这样拆：\n{"reply":"可以","steps":[{"name":"看文档","task":"读完 README"}]}\n就这样。';

    expect(parsePlan(text)?.steps.single.task, '读完 README');
  });

  test('根本不是 JSON 返回 null', () {
    expect(parsePlan('我觉得你应该先想清楚目标。'), isNull);
    expect(parsePlan(''), isNull);
  });

  test('steps 为空或没有 name 的项都返回 null', () {
    expect(parsePlan('{"reply":"嗯","steps":[]}'), isNull);
    expect(parsePlan('{"reply":"嗯","steps":[{"task":"没有名字"}]}'), isNull);
  });

  test('缺 reply 也能用，缺 task 的那一步只出步骤', () {
    final plan = parsePlan('{"steps":[{"name":"第一步"},{"name":"第二步","task":"做点事"}]}');

    expect(plan, isNotNull);
    expect(plan!.reply, isEmpty);
    expect(plan.steps.first.task, isEmpty);
    expect(plan.steps.last.task, '做点事');
  });

  test('给太多步只收前 8 步', () {
    final steps = List.generate(12, (i) => '{"name":"第$i步","task":"做事$i"}').join(',');
    final plan = parsePlan('{"reply":"多","steps":[$steps]}');

    expect(plan!.steps, hasLength(8));
  });

  test('过长的名字与事项会被截断，不撑破卡片', () {
    final longName = '一' * 40;
    final plan = parsePlan('{"reply":"长","steps":[{"name":"$longName","task":"${'二' * 80}"}]}');

    expect(plan!.steps.single.name.length, lessThanOrEqualTo(21));
    expect(plan.steps.single.task.length, lessThanOrEqualTo(41));
  });
}
