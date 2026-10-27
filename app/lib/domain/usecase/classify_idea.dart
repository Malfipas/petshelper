import '../model/idea.dart';
import '../port/idea_classifier.dart';
import '../port/idea_gateway.dart';

/// 给想法归一次类：每条只送一次 AI，归过的不再送。
///
/// 归不出结果（没配 key、超时、答的分类为空）就保持未分类，等下次再说——
/// 不拿「未分类」当成一个分类写进库，也不把失败标成已归类。
class ClassifyIdea {
  const ClassifyIdea({required this.ideas, required this.classifier});

  final IdeaGateway ideas;
  final IdeaClassifier classifier;

  Future<ClassifyIdeaOutcome> call({required String ideaId, required int nowMs}) async {
    final idea = await ideas.byId(ideaId);
    if (idea == null) return const ClassifyIdeaNotFound();
    if (idea.classified) return ClassifyIdeaAlreadyClassified(idea);

    final name = await classifier.classify(idea);
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return ClassifyIdeaUnavailable(idea);

    final categoryId = await ideas.ensureCategory(trimmed, nowMs);
    await ideas.markClassified(ideaId, categoryId, nowMs);
    return ClassifyIdeaClassified(idea: idea, categoryId: categoryId, categoryName: trimmed);
  }
}

/// 归类的结果。密封，调用方要把每种情况写全。
sealed class ClassifyIdeaOutcome {
  const ClassifyIdeaOutcome();
}

/// 归好了。
class ClassifyIdeaClassified extends ClassifyIdeaOutcome {
  const ClassifyIdeaClassified({
    required this.idea,
    required this.categoryId,
    required this.categoryName,
  });

  final Idea idea;
  final String categoryId;
  final String categoryName;
}

/// 之前就归过，这次没调 AI。
class ClassifyIdeaAlreadyClassified extends ClassifyIdeaOutcome {
  const ClassifyIdeaAlreadyClassified(this.idea);

  final Idea idea;
}

/// AI 这一下没给出可用分类，保持未分类。
class ClassifyIdeaUnavailable extends ClassifyIdeaOutcome {
  const ClassifyIdeaUnavailable(this.idea);

  final Idea idea;
}

/// 想法不在库里（可能已被删掉）。
class ClassifyIdeaNotFound extends ClassifyIdeaOutcome {
  const ClassifyIdeaNotFound();
}
