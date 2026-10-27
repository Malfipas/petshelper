/// 进度史里的一条：什么时候、哪一步、发生了什么。
///
/// 第 6 页的「改过 N 次」直接读 `revisionCount`，每次改动都经过 `revisions` 留痕。
class ProgressEntry {
  const ProgressEntry({
    required this.id,
    required this.projectId,
    required this.stepIndex,
    required this.content,
    required this.at,
    this.revisionCount = 0,
  });

  final String id;
  final String projectId;

  /// 发生在第几步，步骤被删后可能是历史下标。
  final int stepIndex;

  final String content;
  final int at;

  /// 被改过几次。
  final int revisionCount;

  bool get edited => revisionCount > 0;
}
