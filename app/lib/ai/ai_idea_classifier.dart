import '../domain/model/idea.dart';
import '../domain/port/idea_classifier.dart';
import 'chat_client.dart';
import 'prompts.dart';

/// 用模型给一条想法归类。
///
/// 这一层只做三件事：拼话、发请求、把回话收拾成一个能落库的类名。没 key
/// 与这次没成都返回 null——调用方（`ClassifyIdea`）据此把想法留在未分类，
/// 不写一条假分类下去。
class AiIdeaClassifier implements IdeaClassifier {
  const AiIdeaClassifier(this._client);

  final ChatClient _client;

  @override
  Future<String?> classify(Idea idea) async {
    final title = idea.title.trim();
    // 没标题就没什么可归的，也别浪费一次请求。
    if (title.isEmpty) return null;

    final outcome = await _client.complete(
      system: classifySystemPrompt,
      user: classifyUserPrompt(title: title, body: idea.body),
    );
    return switch (outcome) {
      ChatReply(:final text) => cleanCategoryName(text),
      ChatNoKey() || ChatError() => null,
    };
  }
}

/// 类名最长多少字。左栏那一列放不下更长的名字，超了就截。
const int maxCategoryChars = 12;

/// 模型说「归不出来」的几种说法，出现其一就当作没归成。
final RegExp _giveUp = RegExp(r'无法归类|无法判断|不确定|不知道|没有合适的类');

/// 「分类：写作」这种前缀。
final RegExp _prefix = RegExp(r'^\s*(分类|类别|类名|归类)\s*[:：]\s*');

/// 句末与并列的标点：类名里不该出现。
final RegExp _trailingNonsense = RegExp(r'[。．.，,；;、!！?？~～]+$');

/// 首尾的引号、书名号、括号。
final RegExp _wrapping = RegExp(r'''^[\s"'“”‘’《》「」（）()\[\]]+|[\s"'“”‘’《》「」（）()\[\]]+$''');

/// 把模型那句回话收拾成一个能落库的类名；收拾完不成样子就返回 null。
///
/// 模型的常见多余动作：套引号、写「分类：xx」、末尾带句号、答一整段解释。
/// 这里只认第一行，去掉这些壳，再按 [maxCategoryChars] 截断。
String? cleanCategoryName(String raw) {
  final firstLine = raw.trim().split('\n').first.trim();
  if (firstLine.isEmpty) return null;

  var text = firstLine.replaceFirst(_prefix, '');
  text = text.replaceAll(_wrapping, '').replaceAll(_trailingNonsense, '').trim();
  if (text.isEmpty) return null;
  if (_giveUp.hasMatch(text)) return null;
  // 答了一整段解释时，取第一句：类名不会带顿号与逗号。
  final cut = text.split(RegExp(r'[，,。.；;]')).first.trim();
  if (cut.isEmpty) return null;
  return cut.length <= maxCategoryChars ? cut : cut.substring(0, maxCategoryChars);
}
