import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/model/category.dart';
import '../../domain/model/idea.dart';
import '../../domain/usecase/classify_idea.dart';
import 'ideas_state.dart';

export 'ideas_state.dart';

/// 第 7 页的状态与动作：筛选、新建、就地编辑、两段式删除、分类改名。
///
/// 归类只在一处触发——新建存下之后。改标题、改正文都不再送 AI：
/// 一旦归过，反复解析会把用户手动搬的分类打乱。
class IdeaBoxNotifier extends Notifier<IdeaBoxState> {
  IdeaBoxNotifier({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// 卡片上的相对时间与归类时间戳都走这个时钟，测试里固定得住。
  final DateTime Function() _now;

  /// 「删除」按钮三秒后自动还原的那只表。
  Timer? _armTimer;

  @override
  IdeaBoxState build() {
    ref.onDispose(() => _armTimer?.cancel());
    unawaited(refresh());
    return IdeaBoxState(nowMs: now);
  }

  int get now => _now().millisecondsSinceEpoch;

  /// 重读全部想法与分类，顺带把「配没配 key」带回来。
  Future<void> refresh() async {
    final repo = ref.read(ideaRepositoryProvider);
    final settings = await ref.read(settingsRepositoryProvider).current();
    final ideas = _sorted(await repo.all());
    final categories = await repo.categories();

    // 正在编辑的那条可能已经在别处被删掉，编辑态要跟着收。
    final editingId = state.editingId;
    final editingGone = editingId != null && !ideas.any((idea) => idea.id == editingId);
    state = state.copyWith(
      ideas: ideas,
      categories: categories,
      hasKey: settings.keyConfigured,
      nowMs: now,
      clearEditing: editingGone,
    );
  }

  /// 换一个分类看。切换时把编辑态收掉，免得切回来又冒出一张编辑卡。
  void selectCategory(String categoryId) {
    state = state.copyWith(viewCategoryId: categoryId, creating: false, clearEditing: true);
  }

  /// 点「新建想法」：新建卡摆在列表顶部，所以先切回「全部」。
  void startCreate() {
    state = state.copyWith(
      viewCategoryId: IdeaBoxState.allCategory,
      creating: true,
      clearEditing: true,
    );
  }

  /// 点某条想法就地编辑。
  void startEdit(String ideaId) {
    state = state.copyWith(editingId: ideaId, creating: false);
  }

  /// 取消编辑或新建。
  void cancelEdit() {
    state = state.copyWith(creating: false, clearEditing: true);
  }

  /// 新建存下。标题必填由界面拦一道，这里再拦一道。
  ///
  /// 用户在下拉里亲手选了分类，就直接算归好类——之后 AI 不再碰它；
  /// 没选才留给 AI，配了 key 才会真的送出去一次。
  Future<void> saveNew({required String title, String body = '', String? categoryId}) async {
    final name = title.trim();
    if (name.isEmpty) return;
    final repo = ref.read(ideaRepositoryProvider);
    final ideaId = await repo.add(name, body: body.trim(), nowMs: now);
    if (categoryId != null && categoryId.isNotEmpty) {
      await repo.markClassified(ideaId, categoryId, now);
    }
    state = state.copyWith(creating: false, clearEditing: true);
    await refresh();
    if (categoryId == null || categoryId.isEmpty) {
      unawaited(_classify(ideaId));
    }
  }

  /// 编辑存下：标题、正文、分类一起写。
  ///
  /// 分类动过就记成「归类落定」——用户自己搬的，比 AI 那次说了算。
  Future<void> saveEdit({
    required String ideaId,
    required String title,
    required String body,
    String? categoryId,
  }) async {
    final name = title.trim();
    if (name.isEmpty) return;
    final repo = ref.read(ideaRepositoryProvider);
    Idea? before;
    for (final idea in state.ideas) {
      if (idea.id == ideaId) {
        before = idea;
        break;
      }
    }

    await repo.rename(ideaId, name);
    await repo.setBody(ideaId, body.trim());
    if (before == null || before.categoryId != categoryId) {
      await repo.markClassified(ideaId, categoryId, now);
    }

    state = state.copyWith(clearEditing: true);
    await refresh();
  }

  /// 让 AI 给这一条归一次类；归不上就保持未分类，等下次再说。
  Future<void> _classify(String ideaId) async {
    if (!state.hasKey) return;
    final outcome = await ref.read(classifyIdeaProvider)(ideaId: ideaId, nowMs: now);
    if (outcome is ClassifyIdeaClassified) await refresh();
  }

  /// 第一次点「删除」：按钮变成红的「确认删除」，三秒内不再点就还原。
  void armDelete(String ideaId) {
    _armTimer?.cancel();
    state = state.copyWith(deleteArmedId: ideaId);
    _armTimer = Timer(const Duration(seconds: 3), () {
      if (state.deleteArmedId == ideaId) {
        state = state.copyWith(clearDeleteArmed: true);
      }
    });
  }

  /// 第二次点「确认删除」才真删。
  Future<void> delete(String ideaId) async {
    _armTimer?.cancel();
    await ref.read(ideaRepositoryProvider).delete(ideaId);
    state = state.copyWith(clearDeleteArmed: true, clearEditing: true);
    await refresh();
  }

  /// 左栏点「重命名」：该分类原地变输入框。
  void startRename(String categoryId) {
    state = state.copyWith(renamingCategoryId: categoryId);
  }

  void cancelRename() {
    state = state.copyWith(clearRenaming: true);
  }

  /// 改名落库。名字没变或空了就当取消：分类不能重名，也不给空名。
  ///
  /// 想法存的是 categoryId，所以改名不用动任何一条想法。
  Future<void> commitRename(String name) async {
    final categoryId = state.renamingCategoryId;
    final trimmed = name.trim();
    state = state.copyWith(clearRenaming: true);
    if (categoryId == null || trimmed.isEmpty) return;
    if (categoryNameOf(categoryId) == trimmed) return;

    await ref.read(ideaRepositoryProvider).renameCategory(categoryId, trimmed);
    await refresh();
  }

  /// 当前状态下这个分类叫什么，交给 [IdeaBoxState.categoryName]，这里只是给改名比对用。
  String categoryNameOf(String categoryId) => state.categoryName(categoryId);

  List<Idea> _sorted(List<Idea> ideas) => ideas.toList()
    ..sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
}

/// 第 7 页的状态入口。
final ideaBoxProvider = NotifierProvider<IdeaBoxNotifier, IdeaBoxState>(IdeaBoxNotifier.new);

/// 分类列表按建出来的先后摆，左栏与下拉共用同一份顺序。
List<Category> orderedCategories(List<Category> categories) {
  final list = [...categories];
  list.sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return List<Category>.unmodifiable(list);
}
