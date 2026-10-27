part of 'projects_notifier.dart';

/// 进度史那一块的写操作：切排法、改正文留痕、看修订链、写随手记。
///
/// 与待办一样，写完一律先落库再重读，界面不自己拼结果。
mixin ProjectHistoryActions on Notifier<ProjectListState> {
  /// 重读整个详情与列表；由宿主 `ProjectListNotifier` 提供。
  Future<void> reload();

  /// 页面统一的时钟，测试里由宿主固定住。
  DateTime get now;

  /// 进度史在「按流程顺序」与「按天分组」两种排法之间切，数据不动。
  void toggleHistoryAxis() => state = state.copyWith(historyTimeline: !state.historyTimeline);

  /// 打开某条正文的编辑；手记编辑一起收掉，一次只改一处。
  void beginEditEntry(String entryId) =>
      state = state.copyWith(editingEntryId: entryId, clearHistoryNoteEditing: true);

  void cancelEditEntry() => state = state.copyWith(clearEditingEntry: true);

  /// 保存改过的正文：空白或没改就只退编辑态；真改了才写留痕再重读。
  Future<bool> saveEntry(String entryId, String text) async {
    final entry = state.detailProgress.where((it) => it.id == entryId).firstOrNull;
    final after = text.trim();
    if (entry == null || after.isEmpty || after == entry.content) {
      state = state.copyWith(clearEditingEntry: true);
      return false;
    }
    await ref
        .read(projectRepositoryProvider)
        .reviseProgress(entry.id, entry.content, after, now.millisecondsSinceEpoch);
    if (!ref.mounted) return false;
    state = state.copyWith(clearEditingEntry: true);
    // 改过之后修订链多了一条，缓存作废；展开着的那条顺手重读。
    final opened = state.openRevisions.contains(entryId);
    final cache = {...state.revisions}..remove(entryId);
    state = state.copyWith(revisions: cache);
    await _refreshProgress();
    if (!ref.mounted) return false;
    if (opened) await _loadRevisions(entryId);
    if (!ref.mounted) return false;
    await reload();
    return true;
  }

  /// 展开或收起修订链。第一次展开才读库，之后走缓存。
  Future<void> toggleRevisions(String entryId) async {
    if (state.openRevisions.contains(entryId)) {
      state = state.copyWith(openRevisions: {...state.openRevisions}..remove(entryId));
      return;
    }
    state = state.copyWith(openRevisions: {...state.openRevisions, entryId});
    if (state.revisions.containsKey(entryId)) return;
    await _loadRevisions(entryId);
  }

  Future<void> _loadRevisions(String entryId) async {
    final list = await ref
        .read(projectRepositoryProvider)
        .revisionsOf(RevisionTarget.progressEntry.name, entryId);
    if (!ref.mounted) return;
    state = state.copyWith(revisions: {...state.revisions, entryId: list});
  }

  /// 打开进度史的随手记；同样一次只改一处。
  void beginHistoryNote(String entryId) =>
      state = state.copyWith(historyNoteEditingId: entryId, clearEditingEntry: true);

  void cancelHistoryNote() => state = state.copyWith(clearHistoryNoteEditing: true);

  /// 写进度史的随手记，空白等于删掉；只刷这一条，不重读整个详情。
  Future<void> saveHistoryNote(String entryId, String body) async {
    await ref
        .read(noteRepositoryProvider)
        .save(NoteOwner.history, entryId, body, now.millisecondsSinceEpoch);
    if (!ref.mounted) return;
    final notes = {...state.historyNotes};
    if (body.trim().isEmpty) {
      notes.remove(entryId);
    } else {
      notes[entryId] = body.trim();
    }
    state = state.copyWith(historyNotes: notes, clearHistoryNoteEditing: true);
  }

  /// 重读进度史与它的随手记。写完正文只刷这一块，列表百分比由 `reload` 另算。
  Future<void> _refreshProgress() async {
    final id = state.openId;
    if (id == null) return;
    final bundle = await ref.read(projectRepositoryProvider).load(id);
    if (!ref.mounted || !bundle.exists) return;
    final notes = await ref.read(noteRepositoryProvider).textsOf(NoteOwner.history);
    if (!ref.mounted) return;
    state = state.copyWith(detailProgress: sortProgress(bundle.progress), historyNotes: notes);
  }
}
