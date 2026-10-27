import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'project_widgets.dart';

/// 删除项目的二次确认：遮罩铺满页面，弹窗宽 360、圆角 14。
///
/// 点遮罩等于取消，点弹窗本体不关——手一抖不该把已经想清楚的事撤销掉。
class ProjectConfirmDialog extends StatelessWidget {
  const ProjectConfirmDialog({
    super.key,
    required this.projectName,
    required this.onCancel,
    required this.onConfirm,
  });

  /// 弹窗标题里的项目名，取当前展开的那一个。
  final String projectName;

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCancel,
        child: ColoredBox(
          color: const Color(0x47182436),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                key: const ValueKey<String>('proj-confirm'),
                width: 360,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.line2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '删除「$projectName」？',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '项目所有数据将被一并删除。',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        height: 1.7,
                        color: AppTheme.ink2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ProjectButton(
                          key: const ValueKey<String>('proj-cancel-delete'),
                          label: '取消',
                          onTap: onCancel,
                        ),
                        const SizedBox(width: 8),
                        ProjectButton(
                          key: const ValueKey<String>('proj-ok-delete'),
                          label: '确认删除',
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
      ),
    );
  }
}
