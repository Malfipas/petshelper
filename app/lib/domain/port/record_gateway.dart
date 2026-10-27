import '../model/daily_record.dart';

/// 用例读写日总结要用的最小接口，由 `RecordRepository` 实现。
abstract interface class RecordGateway {
  Future<DailyRecord?> byDate(String date);

  /// AI 写总结：直接盖掉正文，不动机改标记。
  Future<void> setSummary(String date, String text, int nowMs);
}
