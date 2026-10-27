import 'progress_entry.dart';
import 'project.dart';
import 'step.dart';

/// 一个项目的完整快照：项目、它的步骤、它的进度史。
///
/// 读模型，不是表。项目不存在时 [project] 为 null，其余两项为空。
class ProjectBundle {
  const ProjectBundle({this.project, this.steps = const [], this.progress = const []});

  final Project? project;
  final List<Step> steps;
  final List<ProgressEntry> progress;

  bool get exists => project != null;

  /// 按 `stepId` 找这一步在流程里的下标，找不到给 -1（未分配步骤）。
  int indexOfStep(String? stepId) {
    if (stepId == null) return -1;
    for (final step in steps) {
      if (step.id == stepId) return step.index;
    }
    return -1;
  }
}
