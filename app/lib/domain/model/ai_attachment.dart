/// 随一句话一起送进模型的附件类型。
enum AiAttachmentKind {
  /// 图片，按 base64 编进多模态消息。
  image,

  /// 文本文件，正文拼进同一条文字消息。
  text,
}

/// 一条附件：要么是一张图，要么是一份文本。
///
/// 领域层只认「这张图长什么样、这份文件里写了什么」，不管文件是怎么选来的；
/// 选文件、读字节是 `platform/` 的事，界面只拿到这里的结果。
class AiAttachment {
  const AiAttachment({
    required this.name,
    required this.kind,
    this.mimeType = '',
    this.base64 = '',
    this.content = '',
  });

  /// 一张图。[base64] 是不带 `data:` 前缀的裸编码。
  factory AiAttachment.image({
    required String name,
    required String mimeType,
    required String base64,
  }) => AiAttachment(
    name: name,
    kind: AiAttachmentKind.image,
    mimeType: mimeType,
    base64: base64,
  );

  /// 一份文本文件。
  factory AiAttachment.file({required String name, required String content}) =>
      AiAttachment(name: name, kind: AiAttachmentKind.text, content: content);

  /// 一次最多带几个。多了模型那头也读不完，界面上还挤。
  static const int maxCount = 5;

  /// 单张图的上限。base64 会再胀三分之一，4MB 是不让请求体失控的线。
  static const int maxImageBytes = 4 * 1024 * 1024;

  /// 单份文本的字符上限。
  static const int maxTextChars = 8000;

  /// 文件名，界面上显示用。
  final String name;

  final AiAttachmentKind kind;

  /// 图片的 MIME，例如 `image/png`。
  final String mimeType;

  /// 图片的裸 base64。
  final String base64;

  /// 文本文件的正文（已截断）。
  final String content;

  bool get isImage => kind == AiAttachmentKind.image;

  /// 拼进多模态消息的 `data:` 地址。
  String get dataUrl => 'data:$mimeType;base64,$base64';

  @override
  String toString() => 'AiAttachment($name, $kind)';
}
