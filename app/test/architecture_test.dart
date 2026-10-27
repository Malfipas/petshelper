import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 分层边界：界面与领域层不许 import drift。
/// 界面要 drift 的类型时，由 Repository 在 data 层转成领域模型，而不是把 drift 漏出去。
void main() {
  group('依赖方向', () {
    test('features 与 domain 不 import drift', () {
      final dirs = ['lib/features', 'lib/domain'];
      for (final dir in dirs) {
        final entries = Directory(dir).listSync(recursive: true);
        for (final entry in entries) {
          if (entry is! File || !entry.path.endsWith('.dart')) continue;
          final text = File(entry.path).readAsStringSync();
          expect(
            text.contains("import 'package:drift/"),
            isFalse,
            reason: '${entry.path} 不该 import drift',
          );
          expect(
            text.contains('import \'../db/'),
            isFalse,
            reason: '${entry.path} 不该直接碰 data 层的数据库',
          );
        }
      }
    });

    test('platform 与 ai 不 import drift', () {
      final dirs = ['lib/platform', 'lib/ai'];
      for (final dir in dirs) {
        final entries = Directory(dir).listSync(recursive: true);
        for (final entry in entries) {
          if (entry is! File || !entry.path.endsWith('.dart')) continue;
          final text = File(entry.path).readAsStringSync();
          expect(
            text.contains("import 'package:drift/"),
            isFalse,
            reason: '${entry.path} 不该 import drift',
          );
        }
      }
    });

    test('domain 不 import Flutter', () {
      final entries = Directory('lib/domain').listSync(recursive: true);
      for (final entry in entries) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        final text = File(entry.path).readAsStringSync();
        expect(
          text.contains('package:flutter/'),
          isFalse,
          reason: '${entry.path} 不该 import Flutter',
        );
      }
    });
  });
}
