import 'package:drift/drift.dart';

/// 想法分类。只由 AI 生成，用户可改名；想法存 categoryId，改名不牵连想法。
class Categories extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  TextColumn get name => text()();

  /// 十六进制色值，如 `#3B82F6`。
  TextColumn get color => text()();

  IntColumn get createdAt => integer()();
}
