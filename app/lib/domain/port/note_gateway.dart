import '../model/note.dart';

/// 用例读写随手记要用的最小接口，由 `NoteRepository` 实现。
abstract interface class NoteGateway {
  Future<String> textOf(NoteOwner ownerType, String ownerId);

  /// 写一条，owner 上原来有就覆盖；空白文本等于删掉。
  Future<void> save(NoteOwner ownerType, String ownerId, String body, int nowMs);

}
