import '../../domain/model/note.dart';
import '../../domain/port/note_gateway.dart';
import '../dao/notes_dao.dart';
import '../db/app_db.dart' as db;
import '../id.dart';
import '../mapping/row_mappers.dart';

/// 随手记的取数入口。三个入口（面板、事项详情、进度史）共用这一份。
///
/// 管一张表：notes。按 ownerType + ownerId 取，一个 owner 只有一条，
/// 空文本等于删掉。
class NoteRepository implements NoteGateway {
  NoteRepository(db.AppDb database) : _notes = NotesDao(database);

  final NotesDao _notes;

  Future<Note?> byOwner(NoteOwner ownerType, String ownerId) async {
    final row = await _notes.byOwnerSingle(ownerType.dbValue, ownerId);
    return row?.toDomain();
  }

  @override
  Future<String> textOf(NoteOwner ownerType, String ownerId) async {
    final row = await byOwner(ownerType, ownerId);
    return row?.body ?? '';
  }

  /// 某一类 owner 下的全部随手记，按 `ownerId` 建表；空正文不进来。
  ///
  /// 进度史一列有几十条，逐条 `textOf` 会把一次展开变成几十次查询。
  Future<Map<String, String>> textsOf(NoteOwner ownerType) async {
    final rows = await _notes.byOwnerType(ownerType.dbValue);
    return {
      for (final row in rows)
        if (row.body.trim().isNotEmpty) row.ownerId: row.body,
    };
  }

  /// 某一类 owner 下、ownerId 以 [prefix] 开头的那些，按 ownerId 建表。
  ///
  /// 记录页的感想与总结按 `日期|组键|条目` 存，一天取一次就够。
  Future<Map<String, String>> textsOfPrefix(NoteOwner ownerType, String prefix) async {
    final rows = await _notes.byOwnerTypePrefix(ownerType.dbValue, prefix);
    return {
      for (final row in rows)
        if (row.body.trim().isNotEmpty) row.ownerId: row.body,
    };
  }

  Stream<String> watchText(NoteOwner ownerType, String ownerId) => _notes
      .watchByOwner(ownerType.dbValue, ownerId)
      .map((rows) => rows.isEmpty ? '' : rows.first.body);

  /// 写一条，owner 上原来有就覆盖。空白文本等于删掉。
  @override
  Future<void> save(NoteOwner ownerType, String ownerId, String body, int nowMs) async {
    final text = body.trim();
    final existing = await _notes.byOwnerSingle(ownerType.dbValue, ownerId);
    if (text.isEmpty) {
      if (existing != null) await _notes.deleteById(existing.id);
      return;
    }
    if (existing == null) {
      await _notes.insertOne(
        db.NotesCompanion.insert(
          id: newId('n'),
          ownerType: ownerType.dbValue,
          ownerId: ownerId,
          body: text,
          updatedAt: nowMs,
        ),
      );
      return;
    }
    await _notes.updateRow(existing.copyWith(body: text, updatedAt: nowMs));
  }

  Future<void> deleteFor(NoteOwner ownerType, String ownerId) =>
      _notes.deleteByOwner(ownerType.dbValue, ownerId);
}
