import 'package:flutter_riverpod/flutter_riverpod.dart';

// drift 的表行也叫 Idea / Note 这类名字，这里只取数据库类型，实体一律从 domain 取。
import '../ai/ai_day_summarizer.dart';
import '../ai/ai_idea_classifier.dart';
import '../ai/ai_project_planner.dart';
import '../ai/chat_client.dart';
import '../data/db/app_db.dart' hide Idea, Note;
import '../data/repository/chat_repository.dart';
import '../data/repository/idea_repository.dart';
import '../data/repository/note_repository.dart';
import '../data/repository/project_repository.dart';
import '../data/repository/record_repository.dart';
import '../data/repository/settings_repository.dart';
import '../data/repository/task_repository.dart';
import '../domain/port/attachment_picker.dart';
import '../domain/port/chat_gateway.dart';
import '../domain/port/day_summarizer.dart';
import '../domain/port/idea_classifier.dart';
import '../domain/port/idea_gateway.dart';
import '../domain/port/note_gateway.dart';
import '../domain/port/project_gateway.dart';
import '../domain/port/project_plan_writer.dart';
import '../domain/port/project_planner.dart';
import '../domain/port/record_gateway.dart';
import '../domain/port/secure_key_gateway.dart';
import '../domain/port/task_gateway.dart';
import '../domain/usecase/classify_idea.dart';
import '../domain/usecase/finish_task.dart';
import '../domain/usecase/start_task.dart';
import '../domain/usecase/stop_task.dart';
import '../domain/usecase/summarize_day.dart';
import '../platform/autostart.dart';
import '../platform/files/desktop_attachment_picker.dart';
import '../platform/launch_at_startup_autostart.dart';
import '../platform/secure_store.dart';
import '../platform/timer/timer_service.dart';
import '../platform/tray/tray.dart';
import '../platform/tray/tray_manager_driver.dart';
import '../platform/window/window_driver.dart';
import '../platform/window/window_manager_driver.dart';

/// 全站依赖在这里一处装配：界面只读 provider，不自己 new 数据库或 Repository。
///
/// 数据库是异步打开的，所以这里不给默认值：`main` 打开后经
/// `ProviderScope(overrides: [appDbProvider.overrideWithValue(db)])` 注入；
/// 测试用 `AppDb.memory()` 覆盖成内存库。

/// 应用数据库。未注入时读取即报错，避免悄悄连到别处。
final appDbProvider = Provider<AppDb>(
  (ref) => throw UnimplementedError(
    'appDbProvider 还没装配：main 里注入 AppDb.open() 的结果，测试用 AppDb.memory() 覆盖。',
  ),
);

/// 桌宠窗口的系统能力。
///
/// B08 起窗时取用，位置与侧别由 `PetWindow` 管；测试里换成假 driver，不用真开窗。
final windowDriverProvider = Provider<WindowDriver>((ref) => WindowManagerDriver());

/// 托盘图标与菜单。设置页开关、退出入口都经 `TrayController` 用它。
final trayDriverProvider = Provider<TrayDriver>((ref) => TrayManagerDriver());

/// 开机自启。设置页的开关读它、改它。
final autoStartProvider = Provider<AutoStart>((ref) => LaunchAtStartupAutoStart());

/// 计时服务。面板与第 4、6 页共用一份，收起面板也不会停表。
///
/// 挂在 ProviderScope 而不是页面里：页面拆掉时计时还在跑，回来还得接着显示。
final timerServiceProvider = Provider<TimerService>((ref) {
  final service = TimerService();
  ref.onDispose(service.dispose);
  return service;
});

// 七个 Repository。界面不直接用它们，用的是下面的端口。

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(appDbProvider)),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(appDbProvider)),
);

final recordRepositoryProvider = Provider<RecordRepository>(
  (ref) => RecordRepository(ref.watch(appDbProvider)),
);

final ideaRepositoryProvider = Provider<IdeaRepository>(
  (ref) => IdeaRepository(ref.watch(appDbProvider)),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(appDbProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(appDbProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDbProvider)),
);

/// key 的安全存储。设置页写与清，AI 客户端读。
final secureKeyGatewayProvider = Provider<SecureKeyGateway>((ref) => SystemSecureKeyGateway());

/// 模型客户端，全站一份。
///
/// 默认走 DeepSeek 的 OpenAI 兼容接口；换成 Moonshot、通义、本地 llama.cpp
/// 只改 `HttpChatClient` 的 baseUrl 与模型名，调用方不动。
final chatClientProvider = Provider<ChatClient>(
  (ref) => HttpChatClient(keys: ref.watch(secureKeyGatewayProvider)),
);

/// 拆解端口：项目详情页的「AI 帮助」用它把目标拆成步骤与事项。
final projectPlannerProvider = Provider<ProjectPlanner>(
  (ref) => AiProjectPlanner(ref.watch(chatClientProvider)),
);

/// 拆解结果的落库口，由项目仓库实现。
final projectPlanWriterProvider = Provider<ProjectPlanWriter>(
  (ref) => ref.watch(projectRepositoryProvider),
);

/// 挑附件的系统文件对话框。测试里换成假实现，不弹窗、不读盘。
final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => const DesktopAttachmentPicker(),
);

// 端口：用例与界面只认这些窄接口，换存储不用改上面那一层之外的东西。

final taskGatewayProvider = Provider<TaskGateway>((ref) => ref.watch(taskRepositoryProvider));

final projectGatewayProvider = Provider<ProjectGateway>(
  (ref) => ref.watch(projectRepositoryProvider),
);

final recordGatewayProvider = Provider<RecordGateway>((ref) => ref.watch(recordRepositoryProvider));

final ideaGatewayProvider = Provider<IdeaGateway>((ref) => ref.watch(ideaRepositoryProvider));

final noteGatewayProvider = Provider<NoteGateway>((ref) => ref.watch(noteRepositoryProvider));

final chatGatewayProvider = Provider<ChatGateway>((ref) => ref.watch(chatRepositoryProvider));

/// AI 归类端口：第 7 页新建想法存下之后走它。
///
/// B23 接上了客户端；没 key 或这次没归成仍然返回 null，想法留在未分类。
final ideaClassifierProvider = Provider<IdeaClassifier>(
  (ref) => AiIdeaClassifier(ref.watch(chatClientProvider)),
);

/// AI 总结端口：第 5 页「今日小结」走它。
///
/// 答不出（没 key、超时、答非所问）返回 null，`SummarizeDay` 降级成流水账。
final daySummarizerProvider = Provider<DaySummarizer>(
  (ref) => AiDaySummarizer(ref.watch(chatClientProvider)),
);

// 六个用例。界面拿到就能调，不关心数据从哪来。

final startTaskProvider = Provider<StartTask>((ref) => StartTask(ref.watch(taskGatewayProvider)));

final stopTaskProvider = Provider<StopTask>((ref) => StopTask(ref.watch(taskGatewayProvider)));

final finishTaskProvider = Provider<FinishTask>(
  (ref) => FinishTask(
    tasks: ref.watch(taskGatewayProvider),
    projects: ref.watch(projectGatewayProvider),
    notes: ref.watch(noteGatewayProvider),
  ),
);

final classifyIdeaProvider = Provider<ClassifyIdea>(
  (ref) => ClassifyIdea(
    ideas: ref.watch(ideaGatewayProvider),
    classifier: ref.watch(ideaClassifierProvider),
  ),
);

final summarizeDayProvider = Provider<SummarizeDay>(
  (ref) => SummarizeDay(
    tasks: ref.watch(taskGatewayProvider),
    records: ref.watch(recordGatewayProvider),
    notes: ref.watch(noteGatewayProvider),
    chats: ref.watch(chatGatewayProvider),
    summarizer: ref.watch(daySummarizerProvider),
  ),
);
