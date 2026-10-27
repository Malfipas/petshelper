import '../model/idea.dart';

/// 用例读写想法要用的最小接口，由 `IdeaRepository` 实现。
abstract interface class IdeaGateway {
  Future<Idea?> byId(String ideaId);

  /// 按名字取分类，没有就建一个，返回分类 id。
  Future<String> ensureCategory(String name, int nowMs);

  /// 归类落定：记下分类与归类时间，之后不再送 AI。
  Future<void> markClassified(String ideaId, String? categoryId, int nowMs);
}
