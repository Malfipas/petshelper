import 'dart:convert';

import 'package:ai_pet_assistant/ai/chat_client.dart';
import 'package:ai_pet_assistant/domain/model/ai_attachment.dart';
import 'package:ai_pet_assistant/domain/port/secure_key_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _KeyStore implements SecureKeyGateway {
  _KeyStore(this.key);

  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String value) async => key = value;

  @override
  Future<void> clear() async => key = null;
}

/// 一个像样的 OpenAI 兼容响应。
String _body(String content) => jsonEncode({
  'choices': [
    {
      'message': {'role': 'assistant', 'content': content},
    },
  ],
});

/// 按 UTF-8 造响应。中文走默认 latin1 会在构造那一步就炸，跟被测代码无关。
http.Response _ok(String content) => http.Response.bytes(
  utf8.encode(_body(content)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

HttpChatClient _client(
  MockClient mock, {
  String? key = 'sk-test',
  Duration timeout = const Duration(seconds: 5),
}) => HttpChatClient(
  keys: _KeyStore(key),
  httpClient: mock,
  endpoint: Uri.parse('https://example.com/chat/completions'),
  timeout: timeout,
);

void main() {
  test('有 key 时把消息发出去并取回内容', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return _ok('先做最小的一版');
    });

    final outcome = await _client(mock).complete(system: '你是助手', user: '怎么开始');

    expect(outcome, isA<ChatReply>());
    expect((outcome as ChatReply).text, '先做最小的一版');
    expect(captured.url.path, '/chat/completions');
    expect(captured.headers['Authorization'], 'Bearer sk-test');
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(payload['model'], HttpChatClient.defaultModel);
    expect((payload['messages'] as List), hasLength(2));
  });

  test('没 key 直接返回 ChatNoKey，一次请求都不发', () async {
    var calls = 0;
    final mock = MockClient((request) async {
      calls++;
      return _ok('不该走到这');
    });

    final outcome = await _client(mock, key: null).complete(system: 's', user: 'u');

    expect(outcome, isA<ChatNoKey>());
    expect(calls, 0);
  });

  test('401 说的是 key 没过，不是网络问题', () async {
    final mock = MockClient((request) async => http.Response('{"error":"bad key"}', 401));

    final outcome = await _client(mock).complete(system: 's', user: 'u');

    expect(outcome, isA<ChatError>());
    expect((outcome as ChatError).reason, contains('key'));
  });

  test('500 与空回答都算失败', () async {
    final broken = MockClient((request) async => http.Response('oops', 500));
    final empty = MockClient((request) async => _ok('  '));

    expect(await _client(broken).complete(system: 's', user: 'u'), isA<ChatError>());
    expect(await _client(empty).complete(system: 's', user: 'u'), isA<ChatError>());
  });

  test('返回的不是 JSON 也不会把异常抛到界面', () async {
    final mock = MockClient((request) async => http.Response('<html>502</html>', 200));

    final outcome = await _client(mock).complete(system: 's', user: 'u');

    expect(outcome, isA<ChatError>());
  });

  test('超时给一句能看懂的话', () async {
    final mock = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _ok('太慢');
    });

    final outcome = await _client(
      mock,
      timeout: const Duration(milliseconds: 20),
    ).complete(system: 's', user: 'u');

    expect(outcome, isA<ChatError>());
    expect((outcome as ChatError).reason, contains('等太久'));
  });

  test('没有附件时 content 仍是一个字符串', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return _ok('好');
    });

    await _client(mock).complete(system: 's', user: '怎么开始');

    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    final user = (payload['messages'] as List)[1] as Map<String, dynamic>;
    expect(user['content'], '怎么开始');
  });

  test('带图片时换成多模态数组，图片走 data 地址', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return _ok('好');
    });

    await _client(mock).complete(
      system: 's',
      user: '照着这张图拆',
      attachments: <AiAttachment>[
        AiAttachment.image(name: '草图.png', mimeType: 'image/png', base64: 'AAAA'),
      ],
    );

    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    final user = (payload['messages'] as List)[1] as Map<String, dynamic>;
    final parts = (user['content'] as List).cast<Map<String, dynamic>>();
    expect(parts.first['type'], 'text');
    expect(parts.first['text'], '照着这张图拆');
    expect(parts.last['type'], 'image_url');
    final image = parts.last['image_url'] as Map<String, dynamic>;
    expect(image['url'], 'data:image/png;base64,AAAA');
  });

  test('文本文件的正文并进文字段，带上文件名', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return _ok('好');
    });

    await _client(mock).complete(
      system: 's',
      user: '按材料来',
      attachments: <AiAttachment>[
        AiAttachment.file(name: '材料.md', content: '# 已有调研'),
      ],
    );

    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    final user = (payload['messages'] as List)[1] as Map<String, dynamic>;
    final parts = (user['content'] as List).cast<Map<String, dynamic>>();
    // 纯文字文件不占图片段，正文接在同一段话里。
    expect(parts, hasLength(1));
    expect(parts.single['text'], contains('材料.md'));
    expect(parts.single['text'], contains('# 已有调研'));
  });

  test('只带附件没写话，也还是给模型一段像人说的话', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return _ok('好');
    });

    await _client(mock).complete(
      system: 's',
      user: '',
      attachments: <AiAttachment>[
        AiAttachment.image(name: 'a.png', mimeType: 'image/png', base64: 'AAAA'),
      ],
    );

    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    final user = (payload['messages'] as List)[1] as Map<String, dynamic>;
    final parts = (user['content'] as List).cast<Map<String, dynamic>>();
    expect(parts.first['text'], isNotEmpty);
  });
}
