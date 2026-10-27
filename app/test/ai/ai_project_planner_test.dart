import 'package:ai_pet_assistant/ai/ai_project_planner.dart';
import 'package:ai_pet_assistant/ai/chat_client.dart';
import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/port/project_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记下这次问的是什么，并按剧本回一句。
class _ScriptedClient implements ChatClient {
  _ScriptedClient(this.outcome);

  final ChatOutcome outcome;
  String? system;
  String? user;
  List<AiAttachment> attachments = const <AiAttachment>[];
  int calls = 0;

  @override
  Future<ChatOutcome> complete({
    required String system,
    required String user,
    List<AiAttachment> attachments = const <AiAttachment>[],
  }) async {
    calls++;
    this.system = system;
    this.user = user;
    this.attachments = attachments;
    return outcome;
  }
}

void main() {
  test('模型答了像样的 JSON 就给 PlanReady', () async {
    final client = _ScriptedClient(
      const ChatReply('{"reply":"先摸底","steps":[{"name":"摸现状","task":"列出已有材料"}]}'),
    );
    final outcome = await AiProjectPlanner(client).plan(projectName: '开题', goal: '两周写完');

    expect(outcome, isA<PlanReady>());
    expect((outcome as PlanReady).plan.steps.single.name, '摸现状');
    expect(client.user, contains('项目名：开题'));
    expect(client.user, contains('目标：两周写完'));
    expect(client.system, contains('JSON'));
  });

  test('项目名空着时不把空名字塞进话里', () async {
    final client = _ScriptedClient(const ChatReply('{"steps":[{"name":"第一步"}]}'));

    await AiProjectPlanner(client).plan(projectName: '  ', goal: '做点什么');

    expect(client.user, '目标：做点什么');
  });

  test('没配 key 时返回 PlanNotConfigured，界面据此引导去设置页', () async {
    final outcome = await AiProjectPlanner(_ScriptedClient(const ChatNoKey())).plan(
      projectName: 'p',
      goal: 'g',
    );

    expect(outcome, isA<PlanNotConfigured>());
  });

  test('请求失败把原因原样带出来', () async {
    final outcome = await AiProjectPlanner(
      _ScriptedClient(const ChatError('连不上模型服务，检查网络后再试')),
    ).plan(projectName: 'p', goal: 'g');

    expect(outcome, isA<PlanFailed>());
    expect((outcome as PlanFailed).reason, contains('连不上'));
  });

  test('模型答了看不懂的话算失败，不硬塞半份结果', () async {
    final outcome = await AiProjectPlanner(
      _ScriptedClient(const ChatReply('我建议你先想一想。')),
    ).plan(projectName: 'p', goal: 'g');

    expect(outcome, isA<PlanFailed>());
  });

  test('目标空着直接失败，连请求都不发', () async {
    final client = _ScriptedClient(const ChatReply('{}'));

    final outcome = await AiProjectPlanner(client).plan(projectName: 'p', goal: '   ');

    expect(outcome, isA<PlanFailed>());
    expect(client.calls, 0);
  });

  test('只带图片没写话也能拆：附件原样交给客户端', () async {
    final client = _ScriptedClient(const ChatReply('{"steps":[{"name":"看图"}]}'));
    final image = AiAttachment.image(
      name: '需求.png',
      mimeType: 'image/png',
      base64: 'AAAA',
    );

    final outcome = await AiProjectPlanner(client).plan(
      projectName: 'p',
      goal: '  ',
      attachments: <AiAttachment>[image],
    );

    expect(outcome, isA<PlanReady>());
    expect(client.attachments.single.name, '需求.png');
    // 话里没有目标，就让模型按附件判断，不能留一个空的「目标：」。
    expect(client.user, contains('按附件'));
  });
}
