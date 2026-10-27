import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/confirm_overlay.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../domain/model/task_item.dart';
import '../panel/panel_notifier.dart';
import '../pet/pet_notifier.dart';
import 'solo_detail.dart';
import 'solo_notifier.dart';
import 'solo_row.dart';

/// 「独立事项」页。
///
/// 一列卡片：点行头展开详情，点「开始」把这一件交给面板计时并收起主界面。
/// 走秒数字全部来自面板那边，这一页不自己计时。
class SoloPage extends ConsumerStatefulWidget {
  const SoloPage({super.key});

  @override
  ConsumerState<SoloPage> createState() => _SoloPageState();
}

class _SoloPageState extends ConsumerState<SoloPage> {
  final TextEditingController _newName = TextEditingController();
  final TextEditingController _newDesc = TextEditingController();
  bool _formOpen = false;

  /// 等着二次确认的那一条。非空时页面上压一张确认卡。
  TaskItem? _pendingDelete;

  @override
  void dispose() {
    _newName.dispose();
    _newDesc.dispose();
    super.dispose();
  }

  void _openForm() => setState(() => _formOpen = true);

  void _closeForm() {
    _newName.clear();
    _newDesc.clear();
    setState(() => _formOpen = false);
  }

  Future<void> _submit() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    await ref.read(soloListProvider.notifier).create(name: name, description: _newDesc.text);
    if (mounted) _closeForm();
  }

  /// 点「开始」：先开表，再收主界面、把面板摆出来。
  ///
  /// 开表失败（另一件正在跑、这条已经完成）就原地不动，不跳走。
  Future<void> _start(TaskItem task) async {
    final ok = await ref.read(soloListProvider.notifier).start(task.id);
    if (!ok || !mounted) return;
    _showPanel();
  }

  /// 标记：把这一件设成小任务窗口的当前事项，不开始计时。
  Future<void> _mark(TaskItem task) async {
    await ref.read(panelNotifierProvider.notifier).setCurrentTask(task.id);
    if (!mounted) return;
    _showPanel();
  }

  void _showPanel() {
    ref.read(petNotifierProvider.notifier).openPanel();
    context.go(AppRoutes.pet);
  }

  /// 删除前先问一声：使用者 2026-10-26 要求二次确认，并写明后果。
  Future<void> _delete(TaskItem task) async {
    await ref.read(soloListProvider.notifier).remove(task.id);
    if (mounted) setState(() => _pendingDelete = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(soloListProvider);
    final panel = ref.watch(panelNotifierProvider);
    final board = ref.read(soloListProvider.notifier);
    final now = DateTime.now();

    // `page-solo` 是壳认页用的地址键（路由与冒烟测试都认它），别改名。
    return KeyedSubtree(
      key: const ValueKey<String>('page-solo'),
      child: Stack(
        children: [
          Column(
            key: const ValueKey<String>('page-solo-body'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(state.flash, state.items.length),
              if (_formOpen)
                _NewForm(
                  name: _newName,
                  description: _newDesc,
                  onCancel: _closeForm,
                  onSubmit: _submit,
                ),
              Expanded(
                child: state.loading && state.items.isEmpty
                    ? const SizedBox.shrink()
                    : state.items.isEmpty
                    ? const _Empty()
                    : ListView.builder(
                        key: const ValueKey<String>('solo-list'),
                        padding: EdgeInsets.zero,
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final task = state.items[index];
                          final mine = panel.taskId == task.id;
                          final isCurrent = mine && !task.done;
                          // 面板那边 `running` 表示「这一轮还没停」，暂停时它仍是 true，
                          // 所以暂停要单独判 `paused`，否则按钮会一直画成蓝色走秒。
                          final running = mine && panel.running && !panel.paused;
                          final paused = mine && panel.running && panel.paused;
                          final open = state.openId == task.id;
                          return SoloRow(
                            task: task,
                            now: now,
                            isCurrent: isCurrent,
                            isRunning: running,
                            isPaused: paused,
                            clockLabel: panel.clockLabel,
                            open: open,
                            onTapHead: () => board.toggleDetail(task.id),
                            onToggleDone: () => board.toggleDone(task.id),
                            onStart: () => _start(task),
                            onOpenPanel: _showPanel,
                            onMark: () => unawaited(_mark(task)),
                            detail: open
                                ? SoloDetail(
                                    key: ValueKey<String>('solo-detail-${task.id}'),
                                    task: task,
                                    running: running,
                                    paused: paused,
                                    clockLabel: panel.clockLabel,
                                    onAutoSave: (name, description) => board.autoSave(
                                      id: task.id,
                                      name: name,
                                      description: description,
                                    ),
                                    onSave: (name, description, note) => board.saveNow(
                                      id: task.id,
                                      name: name,
                                      description: description,
                                      note: note,
                                    ),
                                    onDelete: () => setState(() => _pendingDelete = task),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_pendingDelete != null)
            Positioned.fill(
              child: ConfirmOverlay(
                title: '删除「${_pendingDelete!.name}」？',
                message: '相关数据将不会被保留',
                onCancel: () => setState(() => _pendingDelete = null),
                onConfirm: () => unawaited(_delete(_pendingDelete!)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? flash, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 标题与它下面那行小字。《页面操作流程》第 5 节要求标题下方显示当前事项数。
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '独立事项',
                key: ValueKey<String>('solo-title'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '$count个项目',
                key: const ValueKey<String>('solo-count'),
                style: const TextStyle(fontSize: 12, color: AppTheme.ink3),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: flash == null
                ? const SizedBox.shrink()
                : Text(
                    flash,
                    key: const ValueKey<String>('solo-flash'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.ink3),
                  ),
          ),
          _NewButton(onTap: _openForm),
        ],
      ),
    );
  }
}

/// 标题排右边那枚「新建事项」。
class _NewButton extends StatefulWidget {
  const _NewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NewButton> createState() => _NewButtonState();
}

class _NewButtonState extends State<_NewButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const ValueKey<String>('solo-new'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? AppTheme.primarySoft : Colors.white,
            border: Border.all(color: _hover ? AppTheme.primary : AppTheme.line2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('新建事项', style: TextStyle(fontSize: 13, color: AppTheme.primary)),
        ),
      ),
    );
  }
}

/// 新建表单：只问名字与说明。
class _NewForm extends StatelessWidget {
  const _NewForm({
    required this.name,
    required this.description,
    required this.onCancel,
    required this.onSubmit,
  });

  final TextEditingController name;
  final TextEditingController description;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('solo-form'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.line2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              key: const ValueKey<String>('solo-form-name'),
              controller: name,
              maxLength: 40,
              style: const TextStyle(fontSize: 14, color: AppTheme.ink),
              decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                border: InputBorder.none,
                hintText: '事项名称',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
          ),
          Container(
            height: 60,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.line2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              key: const ValueKey<String>('solo-form-desc'),
              controller: description,
              maxLines: 2,
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppTheme.ink),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '事项说明',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _FormButton(
                key: const ValueKey<String>('solo-form-cancel'),
                label: '取消',
                onTap: onCancel,
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: name,
                builder: (context, value, _) {
                  final enabled = value.text.trim().isNotEmpty;
                  return _FormButton(
                    key: const ValueKey<String>('solo-form-ok'),
                    label: '确定',
                    primary: true,
                    enabled: enabled,
                    onTap: enabled ? onSubmit : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormButton extends StatefulWidget {
  const _FormButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool enabled;

  @override
  State<_FormButton> createState() => _FormButtonState();
}

class _FormButtonState extends State<_FormButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final primary = widget.primary;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? AppTheme.primary : Colors.white,
              border: Border.all(
                color: primary
                    ? AppTheme.primary
                    : _hover
                    ? AppTheme.primary
                    : AppTheme.line2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                color: primary
                    ? Colors.white
                    : _hover
                    ? AppTheme.primary
                    : AppTheme.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 空态：不放假数据，只说一句「还没有独立事项」。
///
/// 使用者 2026-10-25 去掉了这里那枚蓝色「新建事项」：页头右上角本来就有一个，
/// 同一页两个入口重复，空态只留文案。
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey<String>('solo-empty'),
      padding: EdgeInsets.symmetric(vertical: 54),
      child: Text(
        '还没有独立事项',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink2),
      ),
    );
  }
}
