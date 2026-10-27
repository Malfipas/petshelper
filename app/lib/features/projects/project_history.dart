import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../domain/model/progress_entry.dart';
import '../../domain/model/revision.dart';

import 'projects_notifier.dart';

part 'project_history_axis.dart';
part 'project_history_edit.dart';

/// 详情最下面那块进度史：一句进展一行，能改正文、写随手记、点开修订链。
///
/// 空的时候整块不出现——标题与「时间轴」键一起收掉，不写「还没有进展」这种话。
class ProjectHistorySection extends StatelessWidget {
  const ProjectHistorySection({
    super.key,
    required this.entries,
    required this.notes,
    required this.nowMs,
    required this.timeline,
    required this.editingEntryId,
    required this.noteEditingId,
    required this.openRevisions,
    required this.revisions,
    required this.onToggleAxis,
    required this.onBeginEdit,
    required this.onCancelEdit,
    required this.onSaveEntry,
    required this.onToggleRevisions,
    required this.onBeginNote,
    required this.onCancelNote,
    required this.onSaveNote,
  });

  final List<ProgressEntry> entries;

  /// 进度史的随手记正文，按进度史 id 存。
  final Map<String, String> notes;

  /// 当前时刻，格式化「昨天 21:40」时用它算日差。
  final int nowMs;

  final bool timeline;
  final String? editingEntryId;
  final String? noteEditingId;
  final Set<String> openRevisions;
  final Map<String, List<Revision>> revisions;

  final VoidCallback onToggleAxis;
  final ValueChanged<String> onBeginEdit;
  final VoidCallback onCancelEdit;
  final void Function(String entryId, String text) onSaveEntry;
  final ValueChanged<String> onToggleRevisions;
  final ValueChanged<String> onBeginNote;
  final VoidCallback onCancelNote;
  final void Function(String entryId, String body) onSaveNote;

  @override
  Widget build(BuildContext context) {
    // 《页面操作流程》第 6 节：标题与切换键一直存在，即使下方没有内容。
    if (entries.isEmpty) return _buildHeader(const SizedBox.shrink());
    final body = _HistoryBodyArgs(
      notes: notes,
      nowMs: nowMs,
      editingEntryId: editingEntryId,
      noteEditingId: noteEditingId,
      openRevisions: openRevisions,
      revisions: revisions,
      onBeginEdit: onBeginEdit,
      onCancelEdit: onCancelEdit,
      onSaveEntry: onSaveEntry,
      onToggleRevisions: onToggleRevisions,
      onBeginNote: onBeginNote,
      onCancelNote: onCancelNote,
      onSaveNote: onSaveNote,
    );
    return _buildHeader(
      timeline
          ? _HistoryAxis(entries: entries, args: body)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _HistoryRow(entry: entries[i], args: body, last: i == entries.length - 1),
              ],
            ),
    );
  }

  /// 区块头：标题 + 切换键。下面没有内容时也照画。
  Widget _buildHeader(Widget body) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timeline ? '时间轴' : '进度史',
                key: const ValueKey<String>('hist-title'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink2,
                ),
              ),
              const Spacer(),
              _AxisButton(
                key: const ValueKey<String>('hist-axis'),
                label: timeline ? '进度史' : '时间轴',
                onTap: onToggleAxis,
              ),
            ],
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

/// 两个视图共用的一把参数，免得行与节点各写十来个字段。
class _HistoryBodyArgs {
  const _HistoryBodyArgs({
    required this.notes,
    required this.nowMs,
    required this.editingEntryId,
    required this.noteEditingId,
    required this.openRevisions,
    required this.revisions,
    required this.onBeginEdit,
    required this.onCancelEdit,
    required this.onSaveEntry,
    required this.onToggleRevisions,
    required this.onBeginNote,
    required this.onCancelNote,
    required this.onSaveNote,
  });

  final Map<String, String> notes;
  final int nowMs;
  final String? editingEntryId;
  final String? noteEditingId;
  final Set<String> openRevisions;
  final Map<String, List<Revision>> revisions;
  final ValueChanged<String> onBeginEdit;
  final VoidCallback onCancelEdit;
  final void Function(String entryId, String text) onSaveEntry;
  final ValueChanged<String> onToggleRevisions;
  final ValueChanged<String> onBeginNote;
  final VoidCallback onCancelNote;
  final void Function(String entryId, String body) onSaveNote;
}

/// 列表里的一行：左边时刻固定 88，右边一句进展与它的 meta。
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.args, required this.last});

  final ProgressEntry entry;
  final _HistoryBodyArgs args;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('hist-${entry.id}'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppTheme.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                historyWhen(entry.at, args.nowMs),
                key: ValueKey<String>('hist-when-${entry.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.ink3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: _HistoryBody(entry: entry, args: args, textSize: 14),
          ),
        ],
      ),
    );
  }
}

/// 正文 + meta + 修订链 + 随手记。行的 14 号与时间轴节点的 13 号只差字号。
class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.entry, required this.args, required this.textSize});

  final ProgressEntry entry;
  final _HistoryBodyArgs args;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final editing = args.editingEntryId == entry.id;
    final note = args.notes[entry.id] ?? '';
    final noteEditing = args.noteEditingId == entry.id;
    final revsOpen = args.openRevisions.contains(entry.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editing)
          _EntryEditor(
            id: entry.id,
            text: entry.content,
            onSave: (text) => args.onSaveEntry(entry.id, text),
            onCancel: args.onCancelEdit,
          )
        else
          Text(
            entry.content,
            key: ValueKey<String>('hist-text-${entry.id}'),
            style: TextStyle(fontSize: textSize, height: 1.6, color: AppTheme.ink),
          ),
        const SizedBox(height: 6),
        Row(
          key: ValueKey<String>('hist-meta-${entry.id}'),
          children: [
            _StepTag(key: ValueKey<String>('hist-step-${entry.id}'), number: entry.stepIndex + 1),
            if (entry.edited) ...[
              const SizedBox(width: 10),
              _LinkText(
                key: ValueKey<String>('hist-revs-${entry.id}'),
                label: '改过 ${entry.revisionCount} 次',
                onTap: () => args.onToggleRevisions(entry.id),
              ),
            ],
            if (!editing) ...[
              const SizedBox(width: 10),
              _LinkText(
                key: ValueKey<String>('hist-edit-${entry.id}'),
                label: '编辑',
                onTap: () => args.onBeginEdit(entry.id),
              ),
            ],
          ],
        ),
        if (revsOpen) _RevisionBox(id: entry.id, list: args.revisions[entry.id]),
        const SizedBox(height: 6),
        _NoteRow(
          id: entry.id,
          note: note,
          editing: noteEditing,
          onBegin: () => args.onBeginNote(entry.id),
          onCancel: args.onCancelNote,
          onSave: (body) => args.onSaveNote(entry.id, body),
        ),
      ],
    );
  }
}

/// 步骤标签：11 号，底 `histTag`，边 `line`，内边距 1/7。
class _StepTag extends StatelessWidget {
  const _StepTag({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.histTag,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text('第 $number 步', style: const TextStyle(fontSize: 11, color: AppTheme.ink2)),
    );
  }
}

/// 11 号主色的文字键：「改过 N 次」「编辑」「随手记」都用它。
class _LinkText extends StatelessWidget {
  const _LinkText({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
      ),
    );
  }
}

/// 修订链：一块浅底，逐条列「时刻 改前 → 改后」。
class _RevisionBox extends StatelessWidget {
  const _RevisionBox({required this.id, required this.list});

  final String id;
  final List<Revision>? list;

  @override
  Widget build(BuildContext context) {
    final rows = list ?? const <Revision>[];
    return Container(
      key: ValueKey<String>('hist-revbox-$id'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: AppTheme.histRev,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            const Text('还没有改动记录', style: TextStyle(fontSize: 12, color: AppTheme.ink3)),
          for (final row in rows)
            Text(
              '${_clock(row.at)}  ${row.before} → ${row.after}',
              style: const TextStyle(fontSize: 12, height: 1.7, color: AppTheme.ink2),
            ),
        ],
      ),
    );
  }

  static String _clock(int atMs) {
    final at = DateTime.fromMillisecondsSinceEpoch(atMs);
    return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }
}

/// 区块头右侧的「时间轴 / 进度史」切换键。
class _AxisButton extends StatelessWidget {
  const _AxisButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
        ),
      ),
    );
  }
}
