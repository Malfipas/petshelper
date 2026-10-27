import '../model/project_bundle.dart';

/// 用例读写项目要用的最小接口，由 `ProjectRepository` 实现。
abstract interface class ProjectGateway {
  /// 项目连步骤与进度史一起取。
  Future<ProjectBundle> load(String projectId);

  /// 记一条进度史，返回它的 id（随手记要挂上去）。
  Future<String> addProgress({
    required String projectId,
    required int stepIndex,
    required String content,
    required int nowMs,
  });
}
