import '../../domain/model/category.dart';
import '../../domain/model/idea.dart';

/// 第 7 页的全部状态：看哪一类、谁在编辑、谁等着确认删除、配没配 key。
///
/// 想法按收进来的时间倒序摆；分类的条数永远按「全部」算，不跟着筛选变。
class IdeaBoxState {
  const IdeaBoxState({
    this.ideas = const <Idea>[],
    this.categories = const <Category>[],
    this.viewCategoryId = allCategory,
    this.editingId,
    this.creating = false,
    this.renamingCategoryId,
    this.deleteArmedId,
    this.hasKey = false,
    this.nowMs = 0,
  });

  /// 左栏第一行「全部」的筛选值。不落库，只是个占位 id。
  static const String allCategory = 'all';

  /// 全部想法，按 [Idea.createdAt] 倒序。
  final List<Idea> ideas;

  /// 左栏那些分类，按建出来的先后。
  final List<Category> categories;

  /// 右栏正在看哪一类：[allCategory] 或某个分类 id。
  final String viewCategoryId;

  /// 正在就地编辑的那条想法。
  final String? editingId;

  /// 新建卡开着。
  final bool creating;

  /// 正在改名的那个分类。
  final String? renamingCategoryId;

  /// 已经点过一次「删除」、正等第二次确认的那条。三秒没点就还原。
  final String? deleteArmedId;

  /// 配了 key 没有。它决定归类跑不跑、标签写「待分类」还是「未分类」。
  final bool hasKey;

  /// 当前时刻，格式化「今天 10:20」时用它。
  final int nowMs;

  /// 右栏要摆的想法：全部，或只看某一类。
  List<Idea> get visible => viewCategoryId == allCategory
      ? ideas
      : ideas.where((idea) => idea.categoryId == viewCategoryId).toList(growable: false);

  /// 页头标题：「全部想法」或分类名。
  String get title => viewCategoryId == allCategory ? '全部想法' : categoryName(viewCategoryId);

  /// 页头条数。
  String get countLabel => '${visible.length} 条';

  /// 「全部」那一行的条数。
  int get total => ideas.length;

  /// 某个分类下有几条。
  int countIn(String categoryId) => ideas.where((idea) => idea.categoryId == categoryId).length;

  /// 分类名；找不到（分类没了、想法还指着它）给空串，界面据此退回「未分类」。
  String categoryName(String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return '';
  }

  /// 这一条右下角那个小标签：分类名，或者「待分类」「未分类」。
  ///
  /// 「待分类」用在配了 key、这条还没轮到时——它跟「未分类」不是一回事：
  /// 前者还会自动归，后者已经不会再归了。
  String tagOf(Idea idea) {
    final id = idea.categoryId;
    final name = id == null ? '' : categoryName(id);
    if (name.isNotEmpty) return name;
    return hasKey ? '待分类' : '未分类';
  }

  /// 标签是不是「真归到某一类了」：是才用主色，否则是灰的。
  bool isTagged(Idea idea) => idea.categoryId != null && categoryName(idea.categoryId!).isNotEmpty;

  IdeaBoxState copyWith({
    List<Idea>? ideas,
    List<Category>? categories,
    String? viewCategoryId,
    String? editingId,
    bool clearEditing = false,
    bool? creating,
    String? renamingCategoryId,
    bool clearRenaming = false,
    String? deleteArmedId,
    bool clearDeleteArmed = false,
    bool? hasKey,
    int? nowMs,
  }) => IdeaBoxState(
    ideas: ideas ?? this.ideas,
    categories: categories ?? this.categories,
    viewCategoryId: viewCategoryId ?? this.viewCategoryId,
    editingId: clearEditing ? null : (editingId ?? this.editingId),
    creating: creating ?? this.creating,
    renamingCategoryId: clearRenaming ? null : (renamingCategoryId ?? this.renamingCategoryId),
    deleteArmedId: clearDeleteArmed ? null : (deleteArmedId ?? this.deleteArmedId),
    hasKey: hasKey ?? this.hasKey,
    nowMs: nowMs ?? this.nowMs,
  );
}

/// 想法卡右下角的时间：刚刚 / 今天 10:20 / 昨天 21:05 / 3 天前 / 上周 / 10 月 3 日。
///
/// 日差按本地日历日算，不按 24 小时：昨晚 23:40 记的，今早开机该说「昨天」。
String ideaWhen(int createdAtMs, int nowMs) {
  final at = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final clock = '${_two(at.hour)}:${_two(at.minute)}';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) {
    if (nowMs - createdAtMs < 60000) return '刚刚';
    return '今天 $clock';
  }
  if (days == 1) return '昨天 $clock';
  if (days < 7) return '$days 天前';
  if (days < 14) return '上周';
  return '${at.month} 月 ${at.day} 日';
}

String _two(int value) => value.toString().padLeft(2, '0');
