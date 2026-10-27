import 'package:drift/drift.dart';

/// 进度史一条。只按流程顺序排，右侧一个时间轴切换。
class ProgressEntries extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  TextColumn get projectId => text()();

  /// 归属步骤的位置，未分配就是 -1。
  IntColumn get stepIndex => integer()();

  /// 这一步发生了什么，一句话。不叫 text，那是 drift 的方法名，会撞。
  TextColumn get content => text()();

  IntColumn get at => integer()();

  /// 改过几次，「改过 N 次」由它出。
  IntColumn get revisionCount => integer().withDefault(const Constant(0))();
}
