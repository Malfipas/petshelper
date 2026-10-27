import '../../domain/model/chat_message.dart';
import '../../domain/port/chat_gateway.dart';
import '../dao/chat_messages_dao.dart';
import '../db/app_db.dart' as db;
import '../id.dart';
import '../mapping/row_mappers.dart';

/// 对话的取数入口。执行中问过 AI 的那条会在这里留下痕迹。
///
/// 管一张表：chat_messages，按 ownerType + ownerId 隔离。
class ChatRepository implements ChatGateway {
  ChatRepository(db.AppDb database) : _messages = ChatMessagesDao(database);

  final ChatMessagesDao _messages;

  Stream<List<ChatMessage>> watchThread(ChatOwner ownerType, String ownerId) => _messages
      .watchByOwner(ownerType.dbValue, ownerId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<List<ChatMessage>> thread(ChatOwner ownerType, String ownerId) async =>
      (await _messages.byOwner(ownerType.dbValue, ownerId)).map((row) => row.toDomain()).toList();

  /// 这条事务问过 AI 没有。第 5 页的日总结拿它判断该不该生成。
  @override
  Future<bool> hasAsked(ChatOwner ownerType, String ownerId) async {
    final rows = await _messages.byOwner(ownerType.dbValue, ownerId);
    return rows.isNotEmpty;
  }

  /// 记一条我问的话。
  Future<String> ask(ChatOwner ownerType, String ownerId, String question, int nowMs) async {
    final id = newId('c');
    await _messages.insertOne(
      db.ChatMessagesCompanion.insert(
        id: id,
        ownerType: ownerType.dbValue,
        ownerId: ownerId,
        role: ChatRole.user.dbValue,
        content: question,
        at: nowMs,
      ),
    );
    return id;
  }

  /// 记一条 AI 的回话。
  Future<String> answer(ChatOwner ownerType, String ownerId, String text, int nowMs) async {
    final id = newId('c');
    await _messages.insertOne(
      db.ChatMessagesCompanion.insert(
        id: id,
        ownerType: ownerType.dbValue,
        ownerId: ownerId,
        role: ChatRole.ai.dbValue,
        content: text,
        at: nowMs,
      ),
    );
    return id;
  }

  Future<void> clearThread(ChatOwner ownerType, String ownerId) =>
      _messages.deleteByOwner(ownerType.dbValue, ownerId);
}
