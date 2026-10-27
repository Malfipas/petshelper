import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' show AppDb;
import 'package:ai_pet_assistant/features/ideas/ideas_notifier.dart';
import 'package:ai_pet_assistant/features/ideas/ideas_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 第 7 页看得见的部分：左栏计数、新建与就地编辑、两段式删除、分类改名。
///
/// 归类与落库的规则在 `ideas_notifier_test.dart` 覆盖，这里只看界面接没接上。
void main() {
  late AppDb db;
  late ProviderContainer container;

  final base = DateTime(2026, 10, 26, 10);

  setUp(() {
    db = AppDb.memory();
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        ideaBoxProvider.overrideWith(() => IdeaBoxNotifier(now: () => base)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 只装想法盒，不带路由与窗口。
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: 704, height: 560, child: IdeasPage())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> seedCategory(String name) => container
      .read(ideaRepositoryProvider)
      .ensureCategory(name, base.millisecondsSinceEpoch);

  Future<String> seedIdea(String title, {String body = '', String? categoryId}) async {
    final repo = container.read(ideaRepositoryProvider);
    final id = await repo.add(title, body: body, nowMs: base.millisecondsSinceEpoch);
    if (categoryId != null) {
      await repo.markClassified(id, categoryId, base.millisecondsSinceEpoch);
    }
    return id;
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

  testWidgets('一条都没有：右栏空态，左栏只有「全部 0」', (tester) async {
    await pumpPage(tester);

    expect(find.text('这里还没有想法'), findsOneWidget);
    expect(find.text('点右上角「新建想法」记一条'), findsOneWidget);
    expect(textOf(tester, 'ideas-view-title'), '全部想法');
    expect(textOf(tester, 'ideas-view-count'), '0 条');
    expect(textOf(tester, 'ideas-cat-count-全部'), '0');
  });

  testWidgets('有想法：标题、正文、时间、未分类标签，左栏带条数', (tester) async {
    final ideaId = await seedIdea('记账', body: '每月底对一遍账');
    await pumpPage(tester);

    expect(textOf(tester, 'ideas-view-count'), '1 条');
    expect(find.text('记账'), findsOneWidget);
    expect(find.text('每月底对一遍账'), findsOneWidget);
    expect(textOf(tester, 'ideas-when-$ideaId'), '刚刚');
    expect(find.text('未分类'), findsOneWidget);
    expect(textOf(tester, 'ideas-cat-count-全部'), '1');
  });

  testWidgets('点「新建想法」开卡，标题空着时存不下', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey<String>('ideas-new')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ideas-editor-new')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('ideas-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('ideas-editor-new')), findsOneWidget);
    expect(await container.read(ideaRepositoryProvider).all(), isEmpty);
  });

  testWidgets('写标题存下：卡进列表，编辑卡收起', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey<String>('ideas-new')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('ideas-editor-title')),
      '做一个记账小工具',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('ideas-editor-body')),
      '先把支出记下来',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ideas-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ideas-editor-new')), findsNothing);
    expect(find.text('做一个记账小工具'), findsOneWidget);
    expect(find.text('先把支出记下来'), findsOneWidget);
    expect(textOf(tester, 'ideas-view-count'), '1 条');
  });

  testWidgets('点卡片就地编辑，改完标题卡片跟着变', (tester) async {
    final ideaId = await seedIdea('旧的标题');
    await pumpPage(tester);

    await tester.tap(find.byKey(ValueKey<String>('ideas-card-$ideaId')));
    await tester.pumpAndSettle();

    final editor = find.byKey(ValueKey<String>('ideas-editor-$ideaId'));
    expect(editor, findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey<String>('ideas-editor-title'))).controller!.text,
      '旧的标题',
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('ideas-editor-title')),
      '新的标题',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ideas-save')));
    await tester.pumpAndSettle();

    expect(find.text('新的标题'), findsOneWidget);
    expect(find.text('旧的标题'), findsNothing);
    expect(editor, findsNothing);
  });

  testWidgets('编辑里换分类下拉，存下后标签变', (tester) async {
    final study = await seedCategory('学习');
    final life = await seedCategory('生活');
    final ideaId = await seedIdea('买台灯', categoryId: study);
    await pumpPage(tester);
    expect(find.text('学习'), findsWidgets);

    await tester.tap(find.byKey(ValueKey<String>('ideas-card-$ideaId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('ideas-editor-category')));
    await tester.pumpAndSettle();
    // 菜单项的指针由外层 InkWell 接，item 本身不是命中目标，故关掉这条告警。
    await tester.tap(
      find.byKey(ValueKey<String>('ideas-cat-option-$life')).last,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ideas-save')));
    await tester.pumpAndSettle();

    final saved = (await container.read(ideaRepositoryProvider).all()).single;
    expect(saved.categoryId, life);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey<String>('ideas-tag-$ideaId')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '生活',
    );
  });

  testWidgets('删除要两次：第一下变「确认删除」，第二下才没', (tester) async {
    final ideaId = await seedIdea('删掉它');
    await pumpPage(tester);
    await tester.tap(find.byKey(ValueKey<String>('ideas-card-$ideaId')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ideas-delete')));
    await tester.pumpAndSettle();
    expect(find.text('确认删除'), findsOneWidget);
    expect(await container.read(ideaRepositoryProvider).all(), hasLength(1));

    await tester.tap(find.byKey(const ValueKey<String>('ideas-delete')));
    await tester.pumpAndSettle();
    expect(await container.read(ideaRepositoryProvider).all(), isEmpty);
    expect(find.text('这里还没有想法'), findsOneWidget);
  });

  testWidgets('点左栏某一类只留那几条，页头换成分类名', (tester) async {
    final study = await seedCategory('学习');
    await seedIdea('看论文', categoryId: study);
    await seedIdea('买台灯');
    await pumpPage(tester);
    expect(textOf(tester, 'ideas-view-count'), '2 条');

    await tester.tap(find.byKey(ValueKey<String>('ideas-cat-$study')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'ideas-view-title'), '学习');
    expect(textOf(tester, 'ideas-view-count'), '1 条');
    expect(find.text('看论文'), findsOneWidget);
    expect(find.text('买台灯'), findsNothing);
  });

  testWidgets('分类行点「重命名」，回车存下后名字与标签一起变', (tester) async {
    final study = await seedCategory('学习');
    await seedIdea('看论文', categoryId: study);
    await pumpPage(tester);

    await tester.tap(find.byKey(ValueKey<String>('ideas-cat-$study')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('ideas-cat-rename-学习')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('ideas-rename-input')),
      '读书',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('读书'), findsWidgets);
    expect(find.text('学习'), findsNothing);
    expect(textOf(tester, 'ideas-view-title'), '读书');
  });

  testWidgets('没配 key 时编辑卡留一句提示，配上就不留', (tester) async {
    final ideaId = await seedIdea('一条');
    await pumpPage(tester);

    await tester.tap(find.byKey(ValueKey<String>('ideas-card-$ideaId')));
    await tester.pumpAndSettle();
    expect(find.text('未配置 API key，AI 不再自动归类'), findsOneWidget);

    await container.read(settingsRepositoryProvider).setKeyConfigured(true);
    await container.read(ideaBoxProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('未配置 API key，AI 不再自动归类'), findsNothing);
  });
}
