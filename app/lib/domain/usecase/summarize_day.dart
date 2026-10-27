import '../model/chat_message.dart';
import '../model/daily_record.dart';
import '../model/day_digest.dart';
import '../model/note.dart';
import '../port/chat_gateway.dart';
import '../port/day_summarizer.dart';
import '../port/note_gateway.dart';
import '../port/record_gateway.dart';
import '../port/task_gateway.dart';

/// 生成某一天的日总结。
///
/// 三条硬规矩：我改过的总结不再覆盖；当天没有内容不写空话；AI 不可用时
/// 降级成把随手记机械整合——宁可是流水账，也不留一条空白记录。
class SummarizeDay {
  const SummarizeDay({
    required this.tasks,
    required this.records,
    required this.notes,
    required this.chats,
    required this.summarizer,
  });

  final TaskGateway tasks;
  final RecordGateway records;
  final NoteGateway notes;
  final ChatGateway chats;
  final DaySummarizer summarizer;

  Future<SummarizeDayOutcome> call({required String date, required int nowMs}) async {
    final record = await records.byDate(date);
    if (record != null && record.editedByUser) {
      return SummarizeDaySkipEdited(record);
    }

    final start = DateTime.parse('${date}T00:00:00');
    final end = start.add(const Duration(days: 1));
    final digest = await _collect(date, start, end);
    if (digest.isEmpty) return const SummarizeDayNothing();

    final written = await summarizer.summarize(digest);
    final text = written?.trim() ?? '';
    if (text.isEmpty) {
      final fallback = _mechanical(digest);
      await records.setSummary(date, fallback, nowMs);
      return SummarizeDayDegraded(fallback);
    }
    await records.setSummary(date, text, nowMs);
    return SummarizeDaySummarized(text);
  }

  Future<DayDigest> _collect(String date, DateTime start, DateTime end) async {
    final entries = await tasks.entriesForDay(
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
    final doneNames = (await tasks.doneBetween(
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    )).map((task) => task.name).toList();

    final items = <DayDigestItem>[];
    for (final entry in entries) {
      items.add(
        DayDigestItem(
          name: entry.task.name,
          seconds: entry.seconds,
          note: await notes.textOf(NoteOwner.task, entry.task.id),
          askedAi: await chats.hasAsked(ChatOwner.panel, entry.task.id),
        ),
      );
    }
    return DayDigest(date: date, items: items, doneNames: doneNames);
  }

  /// 没有 AI 时的流水账：投入多少、做完哪些、随手记原样附上。
  String _mechanical(DayDigest digest) {
    final buffer = StringBuffer();
    final minutes = digest.totalSeconds ~/ 60;
    buffer.writeln(minutes > 0 ? '今天投入 $minutes 分钟。' : '今天没有计时记录。');
    if (digest.doneNames.isNotEmpty) {
      buffer.writeln('完成：${digest.doneNames.join('、')}。');
    }
    for (final item in digest.items.where((item) => item.hasNote)) {
      buffer.writeln('- ${item.name}：${item.note}');
    }
    return buffer.toString().trim();
  }
}

/// 生成的结果。密封，调用方要把每种情况写全。
sealed class SummarizeDayOutcome {
  const SummarizeDayOutcome();
}

/// AI 写好了。
class SummarizeDaySummarized extends SummarizeDayOutcome {
  const SummarizeDaySummarized(this.text);

  final String text;
}

/// AI 没接上，写的是随手记的机械整合。
class SummarizeDayDegraded extends SummarizeDayOutcome {
  const SummarizeDayDegraded(this.text);

  final String text;
}

/// 我改过这一天的总结，不再覆盖。
class SummarizeDaySkipEdited extends SummarizeDayOutcome {
  const SummarizeDaySkipEdited(this.record);

  final DailyRecord record;
}

/// 这一天没有可写的内容，不留空记录。
class SummarizeDayNothing extends SummarizeDayOutcome {
  const SummarizeDayNothing();
}
