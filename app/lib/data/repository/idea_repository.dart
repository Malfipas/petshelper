import 'package:drift/drift.dart';

import '../../domain/model/category.dart';
import '../../domain/model/idea.dart';
import '../../domain/port/idea_gateway.dart';
import '../dao/categories_dao.dart';
import '../dao/ideas_dao.dart';
import '../db/app_db.dart' as db;
import '../id.dart';
import '../mapping/row_mappers.dart';

/// 想法盒的取数入口。
///
/// 管两张表：ideas、categories。分类由 AI 生成，用户可改名、可搬想法。
class IdeaRepository implements IdeaGateway {
  IdeaRepository(db.AppDb database)
    : _ideas = IdeasDao(database),
      _categories = CategoriesDao(database);

  final IdeasDao _ideas;
  final CategoriesDao _categories;

  /// 分类配色轮换用，AI 不给色时按顺序取一个。
  static const palette = <String>['#3B82F6', '#14B8A6', '#F59E0B', '#A855F7', '#EF4444'];

  Stream<List<Idea>> watchAll() => _ideas.watchAll().map(_toList);

  Future<List<Idea>> all() async => _toList(await _ideas.all());

  Future<List<Idea>> unclassified() async => _toList(await _ideas.unclassified());

  Stream<List<Category>> watchCategories() =>
      _categories.watchAll().map((rows) => rows.map((row) => row.toDomain()).toList());

  Future<List<Category>> categories() async =>
      (await _categories.all()).map((row) => row.toDomain()).toList();

  /// 等着归类的一条，没有就空。每条想法只送一次。
  Future<Idea?> nextUnclassified() async {
    final rows = await _ideas.unclassified();
    return rows.isEmpty ? null : rows.first.toDomain();
  }

  @override
  Future<Idea?> byId(String ideaId) async {
    final row = await _ideas.byId(ideaId);
    return row?.toDomain();
  }

  Future<String> add(String title, {String body = '', required int nowMs}) async {
    final id = newId('i');
    await _ideas.insertOne(
      db.IdeasCompanion.insert(id: id, title: title, body: Value(body), createdAt: nowMs),
    );
    return id;
  }

  Future<void> rename(String ideaId, String title) =>
      _edit(ideaId, (row) => row.copyWith(title: title));

  Future<void> setBody(String ideaId, String body) =>
      _edit(ideaId, (row) => row.copyWith(body: body));

  Future<void> moveToCategory(String ideaId, String? categoryId) =>
      _edit(ideaId, (row) => row.copyWith(categoryId: Value(categoryId)));

  /// 归类落定：记下分类与归类时间，之后不再送 AI。
  @override
  Future<void> markClassified(String ideaId, String? categoryId, int nowMs) => _edit(
    ideaId,
    (row) => row.copyWith(categoryId: Value(categoryId), classifiedAt: Value(nowMs)),
  );

  /// 按名字取分类，没有就建一个。AI 归类与用户手动归类都走这里。
  @override
  Future<String> ensureCategory(String name, int nowMs) async {
    final trimmed = name.trim();
    final existing = await _categories.byName(trimmed);
    if (existing != null) return existing.id;
    final id = newId('c');
    final count = (await _categories.all()).length;
    await _categories.insertOne(
      db.CategoriesCompanion.insert(
        id: id,
        name: trimmed,
        color: palette[count % palette.length],
        createdAt: nowMs,
      ),
    );
    return id;
  }

  Future<void> renameCategory(String categoryId, String name) async {
    final row = await _categories.byId(categoryId);
    if (row == null) return;
    await _categories.updateRow(row.copyWith(name: name));
  }

  Future<void> delete(String ideaId) => _ideas.deleteById(ideaId);

  List<Idea> _toList(Iterable<db.Idea> rows) =>
      rows.map((row) => row.toDomain()).toList(growable: false);

  Future<void> _edit(String ideaId, db.Idea Function(db.Idea row) change) async {
    final row = await _ideas.byId(ideaId);
    if (row == null) return;
    await _ideas.updateRow(change(row));
  }
}
