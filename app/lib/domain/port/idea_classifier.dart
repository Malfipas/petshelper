import '../model/idea.dart';

/// 想法归类的那一下，由 `ai/` 层在 B23 实现。
///
/// 返回分类名；没配 key、超时、答不出可用分类时返回 null——用例据此保持未分类，
/// 不把失败当成一条错误分类写下去。
abstract interface class IdeaClassifier {
  Future<String?> classify(Idea idea);
}
