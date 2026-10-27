/// 修订针对谁：日总结，或进度史某一条。
enum RevisionTarget {
  dailyRecord,
  progressEntry;

  static RevisionTarget fromDb(String value) => RevisionTarget.values.firstWhere(
    (target) => target.name == value,
    orElse: () => RevisionTarget.dailyRecord,
  );
}

/// 一次改动的留痕。日总结与进度史都能改，但都记在这本册子里。
///
/// 有了它，「改过 N 次」和「原来写的是什么」都查得回来，不用把原文覆盖掉。
class Revision {
  const Revision({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.before,
    required this.after,
    required this.at,
  });

  final String id;
  final RevisionTarget targetType;
  final String targetId;
  final String before;
  final String after;
  final int at;
}
