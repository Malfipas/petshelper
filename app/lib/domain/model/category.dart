/// 想法分类。只由 AI 归类时生成，用户可以改名。
///
/// 想法存的是 `categoryId`，所以改名字不会牵连已经归好的想法。
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// 十六进制色值，如 `#3B82F6`。
  final String color;

  final int createdAt;
}
