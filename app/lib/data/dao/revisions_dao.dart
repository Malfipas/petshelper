import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// revisions 表的存取。改一次记一条，不改不记。
class RevisionsDao extends DatabaseAccessor<AppDb> {
  RevisionsDao(super.db);

  Future<List<Revision>> byTarget(String targetType, String targetId) =>
      (select(db.revisions)
            ..where((t) => t.targetType.equals(targetType) & t.targetId.equals(targetId))
            ..orderBy([(t) => OrderingTerm.desc(t.at)]))
          .get();

  Future<int> countByTarget(String targetType, String targetId) async {
    final rows = await byTarget(targetType, targetId);
    return rows.length;
  }

  Future<int> insertOne(RevisionsCompanion companion) => into(db.revisions).insert(companion);

  Future<int> deleteByTarget(String targetType, String targetId) => (delete(
    db.revisions,
  )..where((t) => t.targetType.equals(targetType) & t.targetId.equals(targetId))).go();
}
