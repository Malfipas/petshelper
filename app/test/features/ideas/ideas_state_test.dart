import 'package:ai_pet_assistant/domain/model/category.dart';
import 'package:ai_pet_assistant/domain/model/idea.dart';
import 'package:ai_pet_assistant/features/ideas/ideas_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10).millisecondsSinceEpoch;
  int at(int month, int day, int hour, int minute) =>
      DateTime(2026, month, day, hour, minute).millisecondsSinceEpoch;

  Idea idea({
    required String id,
    String title = '一条想法',
    String? categoryId,
    int? createdAt,
  }) => Idea(
    id: id,
    title: title,
    categoryId: categoryId,
    createdAt: createdAt ?? now,
  );

  const study = Category(
    id: 'c1',
    name: '学习',
    color: '#3B82F6',
    createdAt: 0,
  );
  const life = Category(id: 'c2', name: '生活', color: '#22C55E', createdAt: 1);

  group('想法卡上的时间', () {
    test('半分钟前说刚刚', () {
      expect(ideaWhen(now - 20000, now), '刚刚');
    });

    test('当天说今天加时分', () {
      expect(ideaWhen(at(10, 26, 9, 5), now), '今天 09:05');
    });

    test('隔一天说昨天加时分', () {
      expect(ideaWhen(at(10, 25, 21, 5), now), '昨天 21:05');
    });

    test('昨晚 23 点记的，今早看是昨天', () {
      final morning = DateTime(2026, 10, 26, 8).millisecondsSinceEpoch;
      expect(ideaWhen(at(10, 25, 23, 0), morning), '昨天 23:00');
    });

    test('一周内说几天前，不带时分', () {
      expect(ideaWhen(at(10, 23, 14, 30), now), '3 天前');
    });

    test('八到十三天说上周', () {
      expect(ideaWhen(at(10, 17, 14, 30), now), '上周');
    });

    test('再久报月日', () {
      expect(ideaWhen(at(9, 26, 14, 30), now), '9 月 26 日');
    });
  });

  group('右下角标签', () {
    final state = IdeaBoxState(categories: const [study, life], nowMs: now);

    test('归好了就写分类名，用主色', () {
      final one = idea(id: 'i1', categoryId: 'c1');
      expect(state.tagOf(one), '学习');
      expect(state.isTagged(one), isTrue);
    });

    test('分类没了退回灰标签，不崩', () {
      final one = idea(id: 'i1', categoryId: 'c9');
      expect(state.tagOf(one), '未分类');
      expect(state.isTagged(one), isFalse);
    });

    test('配了 key 但还没轮到，说待分类', () {
      final one = idea(id: 'i1');
      final keyed = state.copyWith(hasKey: true);
      expect(keyed.tagOf(one), '待分类');
      expect(keyed.isTagged(one), isFalse);
    });

    test('没配 key 说未分类', () {
      expect(state.tagOf(idea(id: 'i1')), '未分类');
    });
  });

  group('筛选与计数', () {
    final ideas = [
      idea(id: 'i3', categoryId: 'c1'),
      idea(id: 'i2', categoryId: 'c2'),
      idea(id: 'i1', categoryId: 'c1'),
    ];
    final state = IdeaBoxState(ideas: ideas, categories: const [study, life]);

    test('全部时看得到每一条', () {
      expect(state.visible.length, 3);
      expect(state.title, '全部想法');
      expect(state.countLabel, '3 条');
    });

    test('切到某一类只剩那几条，标题换成分类名', () {
      final one = state.copyWith(viewCategoryId: 'c1');
      expect(one.visible.map((idea) => idea.id), ['i3', 'i1']);
      expect(one.title, '学习');
      expect(one.countLabel, '2 条');
    });

    test('条数始终按全部算，切类不缩水', () {
      final one = state.copyWith(viewCategoryId: 'c1');
      expect(one.total, 3);
      expect(one.countIn('c1'), 2);
      expect(one.countIn('c2'), 1);
      expect(one.countIn('c9'), 0);
    });
  });
}
