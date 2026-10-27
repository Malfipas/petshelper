import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' show AppDb;
import 'package:ai_pet_assistant/domain/model/idea.dart';
import 'package:ai_pet_assistant/domain/port/idea_classifier.dart';
import 'package:ai_pet_assistant/features/ideas/ideas_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记下被调了几次、答什么，用来验证「每条只归一次」。
class _FakeClassifier implements IdeaClassifier {
  _FakeClassifier(this.answer);

  String? answer;
  int calls = 0;
  final List<String> titles = [];

  @override
  Future<String?> classify(Idea idea) async {
    calls += 1;
    titles.add(idea.title);
    return answer;
  }
}

void main() {
  late AppDb db;
  late ProviderContainer container;
  late _FakeClassifier classifier;

  final base = DateTime(2026, 10, 26, 10);

  setUp(() {
    db = AppDb.memory();
    classifier = _FakeClassifier('学习');
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        ideaClassifierProvider.overrideWithValue(classifier),
        ideaBoxProvider.overrideWith(() => IdeaBoxNotifier(now: () => base)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<IdeaBoxNotifier> boot() async {
    final notifier = container.read(ideaBoxProvider.notifier);
    await notifier.refresh();
    return notifier;
  }

  Future<void> enableKey() =>
      container.read(settingsRepositoryProvider).setKeyConfigured(true);

  Future<String> newCategory(String name) => container
      .read(ideaRepositoryProvider)
      .ensureCategory(name, base.millisecondsSinceEpoch);

  Future<List<Idea>> ideas() => container.read(ideaRepositoryProvider).all();

  test('一进页读出想法与分类，默认看全部', () async {
    await container.read(ideaRepositoryProvider).add('记账', nowMs: base.millisecondsSinceEpoch);
    final notifier = await boot();
    final state = container.read(ideaBoxProvider);

    expect(state.ideas.single.title, '记账');
    expect(state.viewCategoryId, IdeaBoxState.allCategory);
    expect(state.hasKey, isFalse);
    expect(state.ideas, hasLength(1));
    expect(notifier.now, base.millisecondsSinceEpoch);
  });

  test('新建存下就进列表最上面，没配 key 不送归类', () async {
    final notifier = await boot();
    await container.read(ideaRepositoryProvider).add('旧的一条', nowMs: base.millisecondsSinceEpoch - 86400000);

    notifier.startCreate();
    expect(container.read(ideaBoxProvider).creating, isTrue);

    await notifier.saveNew(title: '  记账  ', body: ' 每月底对一遍账 ');
    await pumpEventQueue();

    final state = container.read(ideaBoxProvider);
    expect(state.creating, isFalse);
    expect(state.ideas.first.title, '记账');
    expect(state.ideas.first.body, '每月底对一遍账');
    expect(state.ideas, hasLength(2));
    expect(classifier.calls, 0);
    expect(state.tagOf(state.ideas.first), '未分类');
  });

  test('新建时自己选了分类：直接算归好，AI 不再碰', () async {
    await enableKey();
    final categoryId = await newCategory('学习');

    final notifier = await boot();
    await notifier.saveNew(title: '看论文', categoryId: categoryId);
    await pumpEventQueue();

    final saved = (await ideas()).single;
    expect(saved.categoryId, categoryId);
    expect(saved.classifiedAt, isNotNull);
    expect(classifier.calls, 0);
    expect(container.read(ideaBoxProvider).tagOf(saved), '学习');
  });

  test('配了 key 又没指定分类：送一次归类，归上后不再送', () async {
    await enableKey();
    final notifier = await boot();

    await notifier.saveNew(title: '复习线性代数');
    await pumpEventQueue();

    final state = container.read(ideaBoxProvider);
    final saved = state.ideas.single;
    expect(classifier.calls, 1);
    expect(classifier.titles, ['复习线性代数']);
    expect(saved.classifiedAt, isNotNull);
    expect(state.tagOf(saved), '学习');

    // 再刷新一次、再存一条别的，旧那条都不该被重新归。
    await notifier.refresh();
    await notifier.saveNew(title: '另一条');
    await pumpEventQueue();
    expect(classifier.titles.where((title) => title == '复习线性代数'), hasLength(1));
  });

  test('归不上就留未分类，等下次再试', () async {
    await enableKey();
    classifier.answer = null;
    final notifier = await boot();

    await notifier.saveNew(title: '乱七八糟的念头');
    await pumpEventQueue();

    final state = container.read(ideaBoxProvider);
    final saved = state.ideas.single;
    expect(saved.classifiedAt, isNull);
    expect(state.tagOf(saved), '待分类');
  });

  group('就地编辑', () {
    test('只改文字不动分类：归类时间原样', () async {
      final repo = container.read(ideaRepositoryProvider);
      final categoryId = await newCategory('学习');
      final ideaId = await repo.add('看论文', body: '摘要', nowMs: base.millisecondsSinceEpoch);
      await repo.markClassified(ideaId, categoryId, base.millisecondsSinceEpoch);

      final notifier = await boot();
      notifier.startEdit(ideaId);
      await notifier.saveEdit(
        ideaId: ideaId,
        title: '看论文（改）',
        body: '摘要与引言',
        categoryId: categoryId,
      );

      final saved = (await ideas()).single;
      expect(saved.title, '看论文（改）');
      expect(saved.body, '摘要与引言');
      expect(saved.categoryId, categoryId);
      expect(saved.classifiedAt, base.millisecondsSinceEpoch);
      expect(container.read(ideaBoxProvider).editingId, isNull);
    });

    test('把想法搬到另一类，标签跟着变', () async {
      final repo = container.read(ideaRepositoryProvider);
      final study = await newCategory('学习');
      final life = await newCategory('生活');
      final ideaId = await repo.add('买台灯', nowMs: base.millisecondsSinceEpoch);
      await repo.markClassified(ideaId, study, base.millisecondsSinceEpoch);

      final notifier = await boot();
      await notifier.saveEdit(ideaId: ideaId, title: '买台灯', body: '', categoryId: life);

      final state = container.read(ideaBoxProvider);
      final saved = (await ideas()).single;
      expect(saved.categoryId, life);
      expect(state.tagOf(saved), '生活');
    });

    test('存下标题为空什么都不做', () async {
      final repo = container.read(ideaRepositoryProvider);
      final ideaId = await repo.add('原样', nowMs: base.millisecondsSinceEpoch);
      final notifier = await boot();
      notifier.startEdit(ideaId);

      await notifier.saveEdit(ideaId: ideaId, title: '   ', body: 'x');

      expect((await ideas()).single.title, '原样');
      expect(container.read(ideaBoxProvider).editingId, ideaId);
    });
  });

  test('删除要两次：先挂红，再点才真删', () async {
    final repo = container.read(ideaRepositoryProvider);
    final ideaId = await repo.add('删掉它', nowMs: base.millisecondsSinceEpoch);
    final notifier = await boot();

    notifier.armDelete(ideaId);
    expect(container.read(ideaBoxProvider).deleteArmedId, ideaId);
    expect(await ideas(), hasLength(1));

    await notifier.delete(ideaId);
    expect(await ideas(), isEmpty);
    expect(container.read(ideaBoxProvider).deleteArmedId, isNull);
    expect(container.read(ideaBoxProvider).ideas, isEmpty);
  });

  test('分类改名不动想法，标签跟着新名字', () async {
    final repo = container.read(ideaRepositoryProvider);
    final categoryId = await newCategory('学习');
    final ideaId = await repo.add('看论文', nowMs: base.millisecondsSinceEpoch);
    await repo.markClassified(ideaId, categoryId, base.millisecondsSinceEpoch);

    final notifier = await boot();
    notifier.startRename(categoryId);
    expect(container.read(ideaBoxProvider).renamingCategoryId, categoryId);

    await notifier.commitRename('  读书  ');

    final state = container.read(ideaBoxProvider);
    expect(state.categories.single.name, '读书');
    expect(state.renamingCategoryId, isNull);
    expect((await ideas()).single.categoryId, categoryId);
    expect(state.tagOf(state.ideas.single), '读书');
  });

  test('分类改名为空或没变，都不动库', () async {
    final categoryId = await newCategory('学习');
    final notifier = await boot();

    notifier.startRename(categoryId);
    await notifier.commitRename('   ');
    expect(container.read(ideaBoxProvider).categories.single.name, '学习');

    notifier.startRename(categoryId);
    await notifier.commitRename('学习');
    expect(container.read(ideaBoxProvider).categories.single.name, '学习');
  });

  test('切到某一类只摆那几条，切回来又是全部', () async {
    final repo = container.read(ideaRepositoryProvider);
    final study = await newCategory('学习');
    final id1 = await repo.add('看论文', nowMs: base.millisecondsSinceEpoch);
    await repo.markClassified(id1, study, base.millisecondsSinceEpoch);
    await repo.add('买台灯', nowMs: base.millisecondsSinceEpoch + 1000);

    final notifier = await boot();
    notifier.selectCategory(study);

    final filtered = container.read(ideaBoxProvider);
    expect(filtered.visible.map((idea) => idea.title), ['看论文']);
    expect(filtered.title, '学习');
    expect(filtered.total, 2);

    notifier.selectCategory(IdeaBoxState.allCategory);
    expect(container.read(ideaBoxProvider).visible, hasLength(2));
  });

  test('编辑到一半切分类，编辑态收掉', () async {
    final ideaId = await container
        .read(ideaRepositoryProvider)
        .add('一条', nowMs: base.millisecondsSinceEpoch);
    final notifier = await boot();
    notifier.startEdit(ideaId);
    notifier.selectCategory(IdeaBoxState.allCategory);

    expect(container.read(ideaBoxProvider).editingId, isNull);
  });
}
