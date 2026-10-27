import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/model/ai_attachment.dart';
import '../../domain/port/attachment_picker.dart';

/// 桌面上用系统文件对话框挑附件。
///
/// 读盘只在这里做：图片编 base64 交出去，文本文件按 UTF-8 读成正文，其他
/// 类型的二进制文件读进上下文只会是一堆乱码，直接跳过并说明一句。
class DesktopAttachmentPicker implements AttachmentPicker {
  const DesktopAttachmentPicker();

  /// 认得出的图片后缀，其余按文本处理。
  static const Set<String> _imageExt = <String>{
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
  };

  /// 认得出的文本后缀。这里不追求全，认不出的一律拒绝，好过把乱码塞给模型。
  static const Set<String> _textExt = <String>{
    'txt',
    'md',
    'markdown',
    'json',
    'yaml',
    'yml',
    'csv',
    'log',
    'html',
    'xml',
    'dart',
    'py',
    'js',
    'ts',
    'java',
    'c',
    'h',
    'cpp',
    'cs',
    'sql',
    'tex',
  };

  @override
  Future<AttachmentPickOutcome> pick({required int remaining}) async {
    if (remaining <= 0) {
      return const AttachmentPickFailed('最多带 ${AiAttachment.maxCount} 个附件，先移掉一个');
    }

    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        allowMultiple: remaining > 1,
        withData: true,
        dialogTitle: '选图片或文本文件',
      );
    } catch (_) {
      return const AttachmentPickFailed('打不开文件选择框，再试一次');
    }
    if (result == null || result.files.isEmpty) {
      return const AttachmentPickCancelled();
    }

    final picked = <AiAttachment>[];
    String note = '';
    for (final file in result.files.take(remaining)) {
      final bytes = file.bytes;
      if (bytes == null) {
        note = _merge(note, '${file.name} 读不出来，换一个');
        continue;
      }
      final ext = (file.extension ?? '').toLowerCase();
      if (_imageExt.contains(ext)) {
        if (bytes.length > AiAttachment.maxImageBytes) {
          note = _merge(note, '${file.name} 超过 4MB，压一下再试');
          continue;
        }
        picked.add(
          AiAttachment.image(
            name: file.name,
            mimeType: _mime(ext),
            base64: base64Encode(bytes),
          ),
        );
        continue;
      }
      if (_textExt.contains(ext)) {
        final text = _readText(bytes);
        if (text.isEmpty) {
          note = _merge(note, '${file.name} 里没有可读的文字');
          continue;
        }
        picked.add(AiAttachment.file(name: file.name, content: _clip(text)));
        continue;
      }
      note = _merge(note, '${file.name} 这类文件读不了，换成图片或文本文件');
    }

    if (picked.isEmpty) {
      return AttachmentPickFailed(note.isEmpty ? '没有选到能用的附件' : note);
    }
    return AttachmentPicked(picked, note: note);
  }

  /// UTF-8 读，坏字节换成替换符：能读多少算多少，别整个文件废掉。
  String _readText(Uint8List bytes) =>
      utf8.decode(bytes, allowMalformed: true).trim();

  /// 超长的正文截断，尾部留一句提示，免得模型以为文件就这么点。
  String _clip(String text) => text.length <= AiAttachment.maxTextChars
      ? text
      : '${text.substring(0, AiAttachment.maxTextChars)}\n…（后面还有，先截到这里）';

  String _merge(String note, String next) => note.isEmpty ? next : '$note；$next';

  String _mime(String ext) => ext == 'jpg' || ext == 'jpeg'
      ? 'image/jpeg'
      : ext == 'svg'
      ? 'image/svg+xml'
      : 'image/$ext';
}
