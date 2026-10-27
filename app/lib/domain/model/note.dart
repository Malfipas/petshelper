/// 随手记挂在谁身上：事项上、进度史某一条上，或记录页某天某一条。
///
/// [dayThought] 与 [daySummary] 是记录页（第 5 页）的两类文字，共用这张表：
/// 钥匙是 `日期|组键|条目`，同一条事项在别的日期、别的组里各算一条。
enum NoteOwner {
  task,
  history,

  /// 我的感想：每条事项展开后的虚线框，以及今日小结下面那块。
  dayThought,

  /// 每条事项 AI 总结里我自己改过的那一版，压过生成值。
  daySummary;

  static NoteOwner fromDb(String value) =>
      NoteOwner.values.firstWhere((owner) => owner.name == value, orElse: () => NoteOwner.task);
}

/// 随手记。三个入口（悬停面板、独立事项详情、项目待办卡片）共用这一份。
///
/// 一个 owner 只有一条，空文本等于没有。owner 是创建时定下的 id，写完就不再改挂。
class Note {
  const Note({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.body,
    required this.updatedAt,
  });

  final String id;
  final NoteOwner ownerType;
  final String ownerId;
  final String body;
  final int updatedAt;

  bool get isEmpty => body.trim().isEmpty;
}
