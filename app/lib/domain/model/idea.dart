/// 想法盒里的一条。成形的念头进项目，没成形的先进这里。
///
/// `classifiedAt` 为空才会送 AI 归类——每条只分一次，分过就不再消耗一次调用。
class Idea {
  const Idea({
    required this.id,
    required this.title,
    this.body = '',
    this.categoryId,
    this.classifiedAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;

  /// 归到哪个分类，还没归类为 null。
  final String? categoryId;

  /// 归类落定的时间，毫秒时间戳；没归类为 null。
  final int? classifiedAt;

  final int createdAt;

  bool get needsClassification => classifiedAt == null;

  bool get classified => !needsClassification;
}
