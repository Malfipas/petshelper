import '../model/ai_attachment.dart';

/// 打开系统文件选择器挑几个附件。
///
/// 端口只说「给我几张图或几份文件」，怎么弹窗、怎么读盘是 `platform/` 的事。
/// 取消、选不出可用的、超出上限三种都要能表达，界面才知道是静默收场还是说一句。
abstract interface class AttachmentPicker {
  /// [remaining] 是这一轮还能再带几个；`<= 0` 时实现应直接返回失败，别弹窗。
  Future<AttachmentPickOutcome> pick({required int remaining});
}

/// 挑附件的结果。
sealed class AttachmentPickOutcome {
  const AttachmentPickOutcome();
}

/// 挑到了。[note] 非空时界面要补一句（例如某个文件被跳过）。
class AttachmentPicked extends AttachmentPickOutcome {
  const AttachmentPicked(this.attachments, {this.note = ''});

  final List<AiAttachment> attachments;
  final String note;
}

/// 使用者按了取消，或一个都没选。
class AttachmentPickCancelled extends AttachmentPickOutcome {
  const AttachmentPickCancelled();
}

/// 这次挑不出可用的，[reason] 是给使用者看的一句话。
class AttachmentPickFailed extends AttachmentPickOutcome {
  const AttachmentPickFailed(this.reason);

  final String reason;
}
