/// 对话里这一句是谁说的。
enum ChatRole {
  user,
  ai;

  static ChatRole fromDb(String value) =>
      ChatRole.values.firstWhere((role) => role.name == value, orElse: () => ChatRole.user);
}

/// 对话挂在谁身上：悬停小面板里的对话，或项目页里的对话。
enum ChatOwner {
  panel,
  project;

  static ChatOwner fromDb(String value) =>
      ChatOwner.values.firstWhere((owner) => owner.name == value, orElse: () => ChatOwner.panel);
}

/// 执行中问过 AI 的一句话。按事务隔离，`ownerType` 目前只有悬停面板。
///
/// 第 5 页的日总结要用它：这条事务问过 AI 没有，就是查这张表有没有行。
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.role,
    required this.content,
    required this.at,
  });

  final String id;
  final String ownerType;
  final String ownerId;
  final ChatRole role;
  final String content;
  final int at;

  bool get isFromUser => role == ChatRole.user;
}
