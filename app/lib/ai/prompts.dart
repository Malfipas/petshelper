import '../domain/model/day_digest.dart';

/// 拆解用的系统提示词。
///
/// 三条约束都是为了能直接落库：只给步骤名与一句话事项，不给工期、优先级、
/// 负责人（这一版没有这些字段）；步数限制在 3~5，多了落进流程条就成噪音；
/// 事项必须是一个起身就能开始的动作，「认真研究」这种话拆了等于没拆。
const String planSystemPrompt = '''
你是一个帮人把大目标拆成小步的助手。对方会给你一个项目名和一个目标。

只输出一个 JSON 对象，不要任何解释、不要 Markdown 代码块的说明文字：
{"reply": "一句话回应", "steps": [{"name": "步骤名", "task": "这一步要做的一件事"}]}

规则：
1. steps 给 3 到 5 步，按执行顺序排列，覆盖从开始到收尾。
2. name 是步骤名，6 个字以内，动词开头。
3. task 是这一步里能立刻动手的一件具体事，15 个字以内，不要写"认真思考""好好准备"这类空话。
4. reply 是一句平实的话，不超过 30 个字，不要客套、不要用感叹号堆砌。
5. 不要输出工期、优先级、负责人、日期。
''';

/// 拆解请求的用户话术。项目名可能为空（列表页直接拆），空则不提。
///
/// 目标也可能为空：这时人只丢了图片或文件进来，让模型按附件判断。
String planUserPrompt({required String projectName, required String goal}) {
  final name = projectName.trim();
  final target = goal.trim().isEmpty ? '（没有文字说明，按附件里的内容判断）' : goal.trim();
  return name.isEmpty ? '目标：$target' : '项目名：$name\n目标：$target';
}

/// 悬停面板里「问一问」的系统提示词。
///
/// 使用者要的是一句能听懂的答复，不是客服口吻的长篇。限制 120 字是让回答
/// 停在气泡能显示的长度上；超出由界面自己截断。
const String askSystemPrompt = '''
你是一只陪人干活的桌面宠物，回答要短、要具体、说人话。

规则：
1. 一次只回答一个问题，控制在 120 字以内。
2. 不用「亲」「宝子」这类称呼，不用感叹号堆砌，不列大段编号清单。
3. 不知道就说不知道，不要编造事实、链接、书名。
''';

/// 想法归类用的系统提示词（v1）。
///
/// 输出必须能当一个分类名落库：左栏那一列只有一行宽度，套引号、写前缀、
/// 答一整段解释都会变成噪音。所以要它只给类名本身，2 到 6 个字。
const String classifySystemPrompt = '''
你在帮一个人把他随手记下的想法归到一个类里。对方会给你一条想法的标题，可能还有正文。

规则：
1. 只输出类名本身。不要引号、不要句号、不要「分类：」这类前缀、不要解释。
2. 类名 2 到 6 个字，名词，例如「写作」「找工作」「产品想法」「家里的事」。
3. 宁可给一个宽一点的类，也不要把一条想法硬塞进两个类。
4. 实在归不出一个可用的类，就只回「无法归类」四个字。
''';

/// 归类请求的用户话术。正文常常是空的，空就不提。
String classifyUserPrompt({required String title, required String body}) {
  final text = body.trim();
  return text.isEmpty ? '标题：${title.trim()}' : '标题：${title.trim()}\n正文：$text';
}

/// 日总结用的系统提示词（v1）。
///
/// 「今日小结」在右栏最上面，卡片宽度有限，所以限一段话 150 字以内，不分条、
/// 不加标题。只许用给到的材料，是因为这一版拿不到聊天全量，模型一旦顺着
/// 猜动机就容易写出跟当天无关的话。
const String summarySystemPrompt = '''
你在帮一个人回顾他的一天。对方会给你这一天做过的事、每件投入多久、写下的随手记。

规则：
1. 写一段话，80 到 150 字，不分条、不列编号、不加标题、不用 Markdown。
2. 先说做成了什么，再说时间主要花在哪，最后一句写这天留下的线索；没有随手记就不提这句。
3. 只用给到的材料。不猜动机、不评价好坏、不用感叹号堆砌。
4. 不要编造材料里没有的数字、名称或计划。
''';

/// 日总结请求的用户话术：把 [DayDigest] 摊成一份人读得懂的材料。
///
/// 时长统一换成分钟：模型对「95 分钟」比对「5700 秒」更有概念，也免得它
/// 在回话里原样搬一串秒数。
String summaryUserPrompt(DayDigest digest) {
  final buffer = StringBuffer()
    ..writeln('日期：${digest.date}')
    ..writeln('完成：${digest.doneNames.length} 件')
    ..writeln('投入：${(digest.totalSeconds / 60).round()} 分钟');
  if (digest.doneNames.isNotEmpty) {
    buffer.writeln('完成的事：${digest.doneNames.join('、')}');
  }
  if (digest.items.isNotEmpty) {
    buffer.writeln('事项：');
    for (final item in digest.items) {
      final minutes = (item.seconds / 60).round();
      final note = item.note.trim();
      buffer.write('- ${item.name.isEmpty ? '（未命名）' : item.name}｜$minutes 分钟');
      if (note.isNotEmpty) buffer.write('｜随手记：$note');
      buffer.writeln();
    }
  }
  return buffer.toString().trim();
}
