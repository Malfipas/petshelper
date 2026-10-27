import 'package:flutter/material.dart';

import 'theme.dart';

/// 压在页面上的二次确认卡。
///
/// 不用 `showDialog`：对话框盖的是整个 Navigator，也就是「主界面 ∪ 桌宠」那块窗口，
/// 主界面只占左边七成时，卡片会偏到右半边去。这里画在页面自己的 Stack 里，
/// 居中的是页面，看上去才像「这张卡片属于这一页」。
class ConfirmOverlay extends StatelessWidget {
  const ConfirmOverlay({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = '删除',
    this.onCancel,
    required this.onConfirm,
  });

  /// 一句话问清楚在删什么，例如「删除「写周报」？」。
  final String title;

  /// 后果说明，例如「相关数据将不会被保留」。
  final String message;

  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey<String>('confirm-overlay'),
      children: [
        // 点空白处等于取消：二次确认不该把人困在页面上。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: const ColoredBox(color: Color(0x24101828)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const ValueKey<String>('confirm-title'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      key: const ValueKey<String>('confirm-message'),
                      style: const TextStyle(fontSize: 13, height: 1.6, color: AppTheme.ink2),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ConfirmButton(
                          key: const ValueKey<String>('confirm-cancel'),
                          label: '取消',
                          onTap: onCancel,
                        ),
                        const SizedBox(width: 8),
                        _ConfirmButton(
                          key: const ValueKey<String>('confirm-ok'),
                          label: confirmLabel,
                          danger: true,
                          onTap: onConfirm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 卡片底部那两枚键：34 高、圆角 10，确认那枚红底。
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: danger ? AppTheme.danger : Colors.white,
          foregroundColor: danger ? Colors.white : AppTheme.ink2,
          side: BorderSide(color: danger ? AppTheme.danger : AppTheme.line2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
