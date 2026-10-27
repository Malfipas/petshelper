import 'dart:convert';

import '../domain/model/planned_step.dart';
import '../domain/model/project_plan.dart';

/// 拆解最多收几步。模型偶尔会多给，多出来的落进流程条就是噪音。
const int _maxSteps = 8;

/// 从模型的话里抠出拆解结果，抠不出来返回 null。
///
/// 模型不一定老实：可能套一层 ```json，可能在 JSON 前后各说一句。所以先剥
/// 围栏，再取第一个 `{` 到最后一个 `}`，剩下的交给 `jsonDecode`。宁可返回
/// null 让界面说「没看懂，再试一次」，也不要塞半份数据进项目。
ProjectPlan? parsePlan(String content) {
  final body = _stripFence(content);
  final start = body.indexOf('{');
  final end = body.lastIndexOf('}');
  if (start < 0 || end <= start) return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(body.substring(start, end + 1));
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;

  final rawSteps = decoded['steps'];
  if (rawSteps is! List) return null;

  final steps = <PlannedStep>[];
  for (final item in rawSteps) {
    if (item is! Map) continue;
    final name = _text(item['name']);
    if (name.isEmpty) continue;
    steps.add(PlannedStep(name: _clip(name, 20), task: _clip(_text(item['task']), 40)));
    if (steps.length == _maxSteps) break;
  }
  if (steps.isEmpty) return null;

  return ProjectPlan(reply: _clip(_text(decoded['reply']), 120), steps: steps);
}

/// 去掉包裹的三反引号（可能是 ```json 也可能是 ```）。
String _stripFence(String content) {
  final trimmed = content.trim();
  if (!trimmed.startsWith('```')) return trimmed;
  final firstBreak = trimmed.indexOf('\n');
  if (firstBreak < 0) return trimmed;
  final rest = trimmed.substring(firstBreak + 1);
  final closing = rest.lastIndexOf('```');
  return closing < 0 ? rest : rest.substring(0, closing);
}

String _text(Object? value) => value is String ? value.trim() : '';

/// 截断到 [limit] 个字，防止模型灌一段长文进来撑破卡片。
String _clip(String value, int limit) =>
    value.length <= limit ? value : '${value.substring(0, limit)}…';
