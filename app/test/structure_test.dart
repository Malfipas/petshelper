import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 目录树必须与 docs/07-开发.md 的类设计一致，缺一层这里就红。
void main() {
  group('lib 目录树符合类设计', () {
    test('六层顶层目录齐全', () {
      const expected = ['app', 'domain', 'data', 'platform', 'ai', 'features'];
      for (final name in expected) {
        expect(Directory('lib/$name').existsSync(), isTrue, reason: '缺少 lib/$name');
      }
    });

    test('domain 分 model 与 usecase', () {
      expect(Directory('lib/domain/model').existsSync(), isTrue);
      expect(Directory('lib/domain/usecase').existsSync(), isTrue);
    });

    test('data 分 db、dao、repository', () {
      expect(Directory('lib/data/db').existsSync(), isTrue);
      expect(Directory('lib/data/dao').existsSync(), isTrue);
      expect(Directory('lib/data/repository').existsSync(), isTrue);
    });

    test('platform 有 window、tray 目录与两个单文件', () {
      expect(Directory('lib/platform/window').existsSync(), isTrue);
      expect(Directory('lib/platform/tray').existsSync(), isTrue);
      expect(File('lib/platform/autostart.dart').existsSync(), isTrue);
      expect(File('lib/platform/secure_store.dart').existsSync(), isTrue);
    });

    test('features 按八页切出七个子目录', () {
      const expected = ['pet', 'panel', 'tasks', 'records', 'projects', 'ideas', 'settings'];
      for (final name in expected) {
        expect(
          Directory('lib/features/$name').existsSync(),
          isTrue,
          reason: '缺少 lib/features/$name',
        );
      }
    });

    test('域层不 import Flutter', () {
      // B01 时域层还没有实体文件；此处先立规矩，B04 起真正生效。
      final dirs = ['lib/domain/model', 'lib/domain/usecase'];
      for (final dir in dirs) {
        final entries = Directory(dir).listSync();
        for (final entry in entries) {
          if (entry is! File || !entry.path.endsWith('.dart')) continue;
          final text = File(entry.path).readAsStringSync();
          expect(
            text.contains('package:flutter/'),
            isFalse,
            reason: '${entry.path} 不该 import Flutter',
          );
        }
      }
    });
  });
}
