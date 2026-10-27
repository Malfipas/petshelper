import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// daily_records 表的存取。一天一条，日期用 yyyy-MM-dd。
class DailyRecordsDao extends DatabaseAccessor<AppDb> {
  DailyRecordsDao(super.db);

  Future<List<DailyRecord>> all() => select(db.dailyRecords).get();

  Future<DailyRecord?> byDate(String date) =>
      (select(db.dailyRecords)..where((t) => t.date.equals(date))).getSingleOrNull();

  Future<List<DailyRecord>> monthOf(String yearMonth) =>
      (select(db.dailyRecords)
            ..where((t) => t.date.like('$yearMonth%'))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> insertOne(DailyRecordsCompanion companion) => into(db.dailyRecords).insert(companion);

  Future<bool> updateRow(DailyRecord row) => update(db.dailyRecords).replace(row);

  Future<int> deleteByDate(String date) =>
      (delete(db.dailyRecords)..where((t) => t.date.equals(date))).go();
}
