import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// chat_messages 表的存取。对话按 ownerType + ownerId 隔离。
class ChatMessagesDao extends DatabaseAccessor<AppDb> {
  ChatMessagesDao(super.db);

  Future<List<ChatMessage>> byOwner(String ownerType, String ownerId) =>
      (select(db.chatMessages)
            ..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))
            ..orderBy([(t) => OrderingTerm.asc(t.at)]))
          .get();

  Stream<List<ChatMessage>> watchByOwner(String ownerType, String ownerId) =>
      (select(db.chatMessages)
            ..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))
            ..orderBy([(t) => OrderingTerm.asc(t.at)]))
          .watch();

  Future<int> insertOne(ChatMessagesCompanion companion) => into(db.chatMessages).insert(companion);

  Future<int> deleteByOwner(String ownerType, String ownerId) => (delete(
    db.chatMessages,
  )..where((t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId))).go();
}
