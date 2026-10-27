import 'dart:math';

final _rng = Random();

/// 本地主键：前缀 + 毫秒 + 三位随机。
///
/// 单机应用够用，不为生成主键再引一个依赖；同一毫秒里连着建两条也不会撞。
String newId(String prefix) {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final tail = _rng.nextInt(46656).toRadixString(36).padLeft(3, '0');
  return '$prefix-$ms-$tail';
}
