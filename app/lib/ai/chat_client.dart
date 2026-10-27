import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/model/ai_attachment.dart';
import '../domain/port/secure_key_gateway.dart';

/// 一次模型调用的结果。
sealed class ChatOutcome {
  const ChatOutcome();
}

/// 拿到了回答。
class ChatReply extends ChatOutcome {
  const ChatReply(this.text);

  final String text;
}

/// 还没配 key。
class ChatNoKey extends ChatOutcome {
  const ChatNoKey();
}

/// 配了 key 但这次没成，`reason` 是给使用者看的一句话。
class ChatError extends ChatOutcome {
  const ChatError(this.reason);

  final String reason;
}

/// 一次一问一答，不带历史。
///
/// 带历史要落会话表，而这一版的问答都短、也不回看，先把接口收窄。
abstract interface class ChatClient {
  /// [attachments] 为空时按纯文字发；带了附件就换成 OpenAI 兼容的多模态
  /// 消息体（文字段 + `image_url` 段 + 文本文件的文字段）。
  Future<ChatOutcome> complete({
    required String system,
    required String user,
    List<AiAttachment> attachments = const <AiAttachment>[],
  });
}

/// OpenAI 兼容的 `/chat/completions` 客户端。
///
/// 之所以挑兼容协议：DeepSeek、Moonshot、通义、本地 llama.cpp 都是这个形状，
/// 换一家只改 baseUrl 与模型名，不动代码。默认指向 DeepSeek，因为它的 key
/// 就是 `sk-` 开头、国内直连、按量便宜。
class HttpChatClient implements ChatClient {
  HttpChatClient({
    required this.keys,
    http.Client? httpClient,
    Uri? endpoint,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('$defaultBaseUrl/chat/completions');

  static const String defaultBaseUrl = 'https://api.deepseek.com';
  static const String defaultModel = 'deepseek-chat';

  /// key 从这里读；读不到就当作没配。
  final SecureKeyGateway keys;
  final http.Client _http;
  final Uri _endpoint;
  final String model;
  final Duration timeout;

  @override
  Future<ChatOutcome> complete({
    required String system,
    required String user,
    List<AiAttachment> attachments = const <AiAttachment>[],
  }) async {
    final key = await keys.read();
    if (key == null || key.isEmpty) return const ChatNoKey();

    try {
      final response = await _http
          .post(
            _endpoint,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode(<String, Object>{
              'model': model,
              'temperature': 0.6,
              'messages': <Map<String, Object>>[
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': _userContent(user, attachments)},
              ],
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ChatError('key 没通过校验，请到设置页换一个');
      }
      if (response.statusCode != 200) {
        return ChatError('服务返回 ${response.statusCode}，稍后再试');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const ChatError('看不懂服务的返回');
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return const ChatError('模型没有返回内容');
      final message = (choices.first as Map)['message'];
      if (message is! Map) return const ChatError('模型没有返回内容');
      final text = message['content'];
      if (text is! String || text.trim().isEmpty) return const ChatError('模型没有返回内容');
      return ChatReply(text);
    } on TimeoutException {
      return const ChatError('等太久了，请再试一次');
    } catch (_) {
      // 断网、DNS、TLS、读 body 失败，对使用者都是同一件事。
      return const ChatError('连不上模型服务，检查网络后再试');
    }
  }
}

/// 把一句话与几份附件拼成 `content`。
///
/// 没有附件时仍然是一个纯字符串：这是最常见的路径，不该为它背上数组的开销，
/// 老模型（只认 `content: "..."`）也还能接着用。有附件才换成数组，图片走
/// `image_url`，文本文件的正文接在文字段后面——模型的上下文里它们就是一段话。
Object _userContent(String user, List<AiAttachment> attachments) {
  if (attachments.isEmpty) return user;
  final text = StringBuffer(user.trim());
  for (final item in attachments) {
    if (item.isImage) continue;
    if (text.isNotEmpty) text.write('\n\n');
    text.write('【文件 ${item.name}】\n${item.content}');
  }
  return <Map<String, Object>>[
    {
      'type': 'text',
      'text': text.isEmpty ? '按这些附件里的内容判断。' : text.toString(),
    },
    for (final item in attachments)
      if (item.isImage)
        {
          'type': 'image_url',
          'image_url': <String, String>{'url': item.dataUrl},
        },
  ];
}
