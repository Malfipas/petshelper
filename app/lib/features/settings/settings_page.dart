import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'settings_notifier.dart';
import 'settings_state.dart';

/// 第 8 页 · 设置：模型 API key、只读地址、开机自启。
///
/// 三件事刻意没做：
/// - 不在页面上回显已存的 key。输入框每次进来都是空的，只有本次敲进去的内容
///   才看得见（PRD 第 8 页 733–734 行：不回显完整 key）。
/// - 不堆说明文字。卡片里只有标题、一句状态和控件本身。「key 卡片不放状态行」
///   这条 2026-10-27 破了：存完切出再进来，输入框是空的，分不清「存住了」还是
///   「没存」，标题旁那两个字只解决这个歧义。
/// - 「演示视频」那一行暂时整行注释掉：真实链接还没定，摆个占位地址只会让人
///   复制了去打不开。notifier 与仓库那头的读写都还在，放开时把那几行注释放开即可。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _key = TextEditingController();
  final _demo = TextEditingController();
  final _repo = TextEditingController();
  final _demoFocus = FocusNode();
  final _repoFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 每次进页都重读：地址可能在别处改过，key 的配没配也可能刚被清掉。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(settingsProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _key.dispose();
    _demo.dispose();
    _repo.dispose();
    _demoFocus.dispose();
    _repoFocus.dispose();
    super.dispose();
  }

  /// 全选某个地址并聚焦，给「剪贴板不可用」当退路：用户按 Ctrl+C 就能拿走。
  void _select(String? target) {
    final toRepo = target == 'repo';
    final controller = toRepo ? _repo : _demo;
    final focus = toRepo ? _repoFocus : _demoFocus;
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    ref.listen<SettingsState>(settingsProvider, (before, after) {
      if (after.demoUrl != _demo.text) _demo.text = after.demoUrl;
      if (after.repoUrl != _repo.text) _repo.text = after.repoUrl;
      if (before == null || before.selectTick != after.selectTick) {
        _select(after.selectTarget);
      }
    });

    return KeyedSubtree(
      key: const ValueKey<String>('page-settings'),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置',
              key: ValueKey<String>('settings-title'),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontPageTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
            if (state.alert.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                state.alert,
                key: const ValueKey<String>('settings-alert'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontMeta,
                  color: AppTheme.ink3,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '模型 API key',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.fontCardTitle,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 只在标题旁写两个字，不回显 key 的任何一位。
                      //
                      // 使用者 2026-10-27 反馈：存完切出再进来，输入框是空的，
                      // 分不清「存住了」还是「没存」。状态字只解决这个歧义，
                      // 不代替按钮上那一下「已保存」。
                      Text(
                        state.configured ? '已配置' : '未配置',
                        key: const ValueKey<String>('settings-key-state'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.fontMeta,
                          color: state.configured ? AppTheme.primary : AppTheme.ink3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'API key',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontBody,
                      color: AppTheme.ink2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              key: const ValueKey<String>('settings-key'),
                              controller: _key,
                              obscureText: !state.revealed,
                              obscuringCharacter: '•',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.fontBody,
                                color: AppTheme.ink,
                              ),
                              decoration: _fieldDecoration(
                                hint: state.configured ? '已配置，输入新的 key 可替换' : 'sk-…',
                                fill: Colors.white,
                                borderColor: AppTheme.line2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _EyeButton(revealed: state.revealed, onTap: notifier.toggleReveal),
                      const SizedBox(width: 8),
                      _SettingsButton(
                        key: const ValueKey<String>('settings-save'),
                        label: state.saveLabel,
                        filled: true,
                        onTap: () => unawaited(notifier.save(_key.text)),
                      ),
                      const SizedBox(width: 8),
                      _SettingsButton(
                        key: const ValueKey<String>('settings-clear'),
                        label: state.clearLabel,
                        onTap: () {
                          // 清除之后输入框不该还留着刚敲的 key。
                          _key.clear();
                          unawaited(notifier.clear());
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '项目地址',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontCardTitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 演示视频那一行暂时不出现：真实链接还没定，占位地址摆在这里
                  // 只会让人点了复制再去粘贴一个打不开的地址。等视频有了再放开。
                  // _UrlRow(
                  //   label: '演示视频',
                  //   fieldKey: const ValueKey<String>('settings-url-demo'),
                  //   controller: _demo,
                  //   focusNode: _demoFocus,
                  //   copyLabel: state.copyLabel(demo: true),
                  //   copyKey: const ValueKey<String>('settings-copy-demo'),
                  //   onCopy: () => unawaited(notifier.copyDemo()),
                  // ),
                  // const SizedBox(height: 12),
                  _UrlRow(
                    label: '项目仓库',
                    fieldKey: const ValueKey<String>('settings-url-repo'),
                    controller: _repo,
                    focusNode: _repoFocus,
                    copyLabel: state.copyLabel(demo: false),
                    copyKey: const ValueKey<String>('settings-copy-repo'),
                    onCopy: () => unawaited(notifier.copyRepo()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 装上就自启，而且没有出口，用户只能去注册表里删——这一格就是那个出口。
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '启动',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontCardTitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '开机后自动出现在桌面右缘',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.fontBody,
                            color: AppTheme.ink2,
                          ),
                        ),
                      ),
                      Switch(
                        key: const ValueKey<String>('settings-autostart'),
                        value: state.autoStart,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                        // 写注册表还没回来时先禁用：连点两下会让最终状态取决于谁后到。
                        onChanged: state.autoStartBusy
                            ? null
                            : (value) => unawaited(notifier.setAutoStart(value)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 两种输入框共用的边框与内边距，只有底色与描边色不同。
  InputDecoration _fieldDecoration({
    required String hint,
    required Color fill,
    required Color borderColor,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.fontBody,
        color: AppTheme.ink3,
      ),
      isDense: true,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: border(borderColor),
      focusedBorder: border(AppTheme.primary),
      border: border(borderColor),
    );
  }
}

/// 一块白底卡片：细描边、圆角 12、内边距 20 / 22，照原型 `.st-card`。
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      border: Border.all(color: AppTheme.line),
    ),
    child: child,
  );
}

/// 一行只读地址：72 宽的标签、窄一点的输入框、复制按钮。
class _UrlRow extends StatelessWidget {
  const _UrlRow({
    required this.label,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.copyLabel,
    required this.copyKey,
    required this.onCopy,
  });

  final String label;
  final ValueKey<String> fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String copyLabel;
  final ValueKey<String> copyKey;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontBody,
              color: AppTheme.ink2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              height: 38,
              child: TextField(
                key: fieldKey,
                controller: controller,
                focusNode: focusNode,
                readOnly: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontBody,
                  color: AppTheme.ink2,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.readonlyFieldBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: border(AppTheme.line),
                  focusedBorder: border(AppTheme.primary),
                  border: border(AppTheme.line),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SettingsButton(key: copyKey, label: copyLabel, onTap: onCopy),
      ],
    );
  }
}

/// 设置页的按钮：实心主色与白底描边两档。原型 `.st-btn`。
class _SettingsButton extends StatefulWidget {
  const _SettingsButton({super.key, required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;

  /// 实心主色（保存）。其余是白底描边。
  final bool filled;

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final filled = widget.filled;
    final borderColor = filled ? AppTheme.primary : (_hovering ? AppTheme.primary : AppTheme.line2);
    final textColor = filled ? Colors.white : (_hovering ? AppTheme.primary : AppTheme.ink2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontBody,
              fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// key 输入框右侧那只眼睛：38 见方，明文时图标转主色。
class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      key: const ValueKey<String>('settings-eye'),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.line2),
        ),
        child: Icon(
          revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
          color: revealed ? AppTheme.primary : AppTheme.ink2,
        ),
      ),
    ),
  );
}
