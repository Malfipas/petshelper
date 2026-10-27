import '../model/chat_message.dart';

/// 用例读写对话要用的最小接口，由 `ChatRepository` 实现。
abstract interface class ChatGateway {
  Future<List<ChatMessage>> thread(ChatOwner ownerType, String ownerId);

  /// 这条事务问过 AI 没有。日总结拿它决定要不要把对话算进去。
  Future<bool> hasAsked(ChatOwner ownerType, String ownerId);
}
