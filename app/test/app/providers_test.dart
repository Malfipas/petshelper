import 'package:ai_pet_assistant/app/providers.dart';
import 'package:ai_pet_assistant/data/db/app_db.dart' hide Idea, Note;
import 'package:ai_pet_assistant/data/repository/chat_repository.dart';
import 'package:ai_pet_assistant/data/repository/idea_repository.dart';
import 'package:ai_pet_assistant/data/repository/note_repository.dart';
import 'package:ai_pet_assistant/data/repository/project_repository.dart';
import 'package:ai_pet_assistant/data/repository/record_repository.dart';
import 'package:ai_pet_assistant/data/repository/task_repository.dart';
import 'package:ai_pet_assistant/domain/model/day_digest.dart';
import 'package:ai_pet_assistant/domain/model/idea.dart';
import 'package:ai_pet_assistant/domain/port/secure_key_gateway.dart';
import 'package:ai_pet_assistant/domain/usecase/classify_idea.dart';
import 'package:ai_pet_assistant/domain/usecase/finish_task.dart';
import 'package:ai_pet_assistant/domain/usecase/start_task.dart';
import 'package:ai_pet_assistant/domain/usecase/stop_task.dart';
import 'package:ai_pet_assistant/domain/usecase/summarize_day.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 没有 key 的安全存储：AI 客户端读到 null 就走 ChatNoKey 那条路。
class _NoKey implements SecureKeyGateway {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String key) async {}

  @override
  Future<void> clear() async {}
}

/// 依赖装配：库一处注入，端口指向 Repository，六个用例拿得到。
void main() {
  group('依赖装配', () {
    late AppDb db;
    late ProviderContainer container;

    setUp(() {
      db = AppDb.memory();
      container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          // AI 端口现在会去读 key：一律给个空的，别让测试摸到本机凭据。
          secureKeyGatewayProvider.overrideWithValue(_NoKey()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('没注入数据库时读取直接报错，并说清该怎么装', () {
      final bare = ProviderContainer();
      addTearDown(bare.dispose);

      // riverpod 3 会把 provider 抛的异常包一层再抛，类型不对外，这里只认文案。
      expect(
        () => bare.read(appDbProvider),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('appDbProvider 还没装配'),
            '报错里说清该怎么装配',
          ),
        ),
      );
    });

    test('端口指向对应的 Repository 实现', () {
      expect(container.read(taskGatewayProvider), isA<TaskRepository>());
      expect(container.read(projectGatewayProvider), isA<ProjectRepository>());
      expect(container.read(recordGatewayProvider), isA<RecordRepository>());
      expect(container.read(ideaGatewayProvider), isA<IdeaRepository>());
      expect(container.read(noteGatewayProvider), isA<NoteRepository>());
      expect(container.read(chatGatewayProvider), isA<ChatRepository>());
    });

    test('五个用例都装得出来', () {
      expect(container.read(startTaskProvider), isA<StartTask>());
      expect(container.read(stopTaskProvider), isA<StopTask>());
      expect(container.read(finishTaskProvider), isA<FinishTask>());
      expect(container.read(classifyIdeaProvider), isA<ClassifyIdea>());
      expect(container.read(summarizeDayProvider), isA<SummarizeDay>());
    });

    test('同一个库只开一份，重复读拿到同一组 Repository', () {
      expect(container.read(taskRepositoryProvider), same(container.read(taskRepositoryProvider)));
    });

    test('没配 key 时 AI 端口答不出，归类与总结都留给降级', () async {
      final classifier = container.read(ideaClassifierProvider);
      final summarizer = container.read(daySummarizerProvider);

      final category = await classifier.classify(const Idea(id: 'i1', title: '做个桌宠', createdAt: 1));
      // 材料要非空：空材料返回 null 是「没东西可写」，测不出没 key 那条路。
      final summary = await summarizer.summarize(
        const DayDigest(date: '2026-10-23', doneNames: ['写第三章']),
      );

      expect(category, isNull);
      expect(summary, isNull);
    });
  });
}
