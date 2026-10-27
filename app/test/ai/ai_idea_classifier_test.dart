import 'package:ai_pet_assistant/ai/ai_idea_classifier.dart';
import 'package:ai_pet_assistant/ai/chat_client.dart';
import 'package:ai_pet_assistant/ai/prompts.dart';
import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/model/idea.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements ChatClient {
  _FakeClient(this._outcome);

  final ChatOutcome _outcome;
  String? system;
  String? user;
  int calls = 0;

  @override
  Future<ChatOutcome> complete({
    required String system,
    required String user,
    List<AiAttachment> attachments = const [],
  }) async {
    calls++;
    this.system = system;
    this.user = user;
    return _outcome;
  }
}

Idea _idea({String title = '写产品文档', String body = ''}) =>
    Idea(id: 'i1', title: title, body: body, createdAt: 0);

void main() {
  group('AiIdeaClassifier', () {
    test('答得上：把回话收拾成类名，话术带标题与正文', () async {
      final client = _FakeClient(const ChatReply('写作'));
      final classifier = AiIdeaClassifier(client);

      final result = await classifier.classify(_idea(body: '先列提纲'));

      expect(result, '写作');
      expect(client.system, classifySystemPrompt);
      expect(client.user, contains('标题：写产品文档'));
      expect(client.user, contains('正文：先列提纲'));
    });

    test('正文空着就不提正文那一行', () async {
      final client = _FakeClient(const ChatReply('写作'));

      await AiIdeaClassifier(client).classify(_idea());

      expect(client.user, isNot(contains('正文：')));
    });

    test('没标题就不发请求', () async {
      final client = _FakeClient(const ChatReply('写作'));

      final result = await AiIdeaClassifier(client).classify(_idea(title: '   '));

      expect(result, isNull);
      expect(client.calls, 0);
    });

    test('没配 key：返回 null，想法留在未分类', () async {
      final classifier = AiIdeaClassifier(_FakeClient(const ChatNoKey()));

      expect(await classifier.classify(_idea()), isNull);
    });

    test('这次没成：返回 null，不当成一条真分类写下去', () async {
      final classifier = AiIdeaClassifier(_FakeClient(const ChatError('网络断了')));

      expect(await classifier.classify(_idea()), isNull);
    });
  });

  group('cleanCategoryName', () {
    test('去引号、去前缀、去句末标点', () {
      expect(cleanCategoryName('「写作」'), '写作');
      expect(cleanCategoryName('分类：找工作。'), '找工作');
      expect(cleanCategoryName('类别: 家里的事'), '家里的事');
      expect(cleanCategoryName('“产品想法”'), '产品想法');
    });

    test('只认第一行：后面那段解释不要', () {
      expect(cleanCategoryName('写作\n理由：这条想法是写文档'), '写作');
    });

    test('答了一整句时取第一段', () {
      expect(cleanCategoryName('写作，因为这条想法是写文档'), '写作');
    });

    test('模型说归不出来就返回 null', () {
      expect(cleanCategoryName('无法归类'), isNull);
      expect(cleanCategoryName('我不确定'), isNull);
      expect(cleanCategoryName('   '), isNull);
    });

    test('类名过长按上限截断，不顶掉左栏那一列', () {
      const long = '这是一个非常非常长的分类名字啊';
      final result = cleanCategoryName(long);

      expect(result, isNotNull);
      expect(result!.length, maxCategoryChars);
    });
  });
}
