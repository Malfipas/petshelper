import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'project_widgets.dart';
import 'projects_notifier.dart';

/// 新建项目的内联表单：名称必填、说明与截止选填。
///
/// 表单只在 `formOpen` 为真时挂载，收起即卸载，控制器自然跟着销毁，
/// 所以每次点开都是空的，不需要外面再清一遍。
class ProjectForm extends StatefulWidget {
  const ProjectForm({
    super.key,
    required this.state,
    required this.onName,
    required this.onDescription,
    required this.onPickDue,
    required this.onCancel,
    required this.onSubmit,
  });

  final ProjectListState state;
  final ValueChanged<String> onName;
  final ValueChanged<String> onDescription;
  final VoidCallback onPickDue;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 两个输入框共用的底：白底、细边、聚焦换主色、内边距只留左右 12。
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 14,
        color: AppTheme.ink3,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        borderSide: const BorderSide(color: AppTheme.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Container(
      key: const ValueKey<String>('proj-form'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              key: const ValueKey<String>('proj-form-name'),
              controller: _nameController,
              onChanged: widget.onName,
              maxLength: 30,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: AppTheme.ink,
              ),
              decoration: _fieldDecoration('项目名'),
            ),
          ),
          if (state.nameTaken)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '已有同名项目',
                key: ValueKey<String>('proj-form-err'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.danger,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: TextField(
              key: const ValueKey<String>('proj-form-desc'),
              controller: _descController,
              onChanged: widget.onDescription,
              maxLength: 40,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: AppTheme.ink,
              ),
              decoration: _fieldDecoration('一句话说明（选填）'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '截止日期',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: AppTheme.ink2,
                ),
              ),
              const SizedBox(width: 8),
              ProjectButton(
                key: const ValueKey<String>('proj-form-due'),
                label: state.dueAt == null ? '选择日期' : dueLabel(state.dueAt),
                minHeight: 32,
                horizontal: 10,
                onTap: widget.onPickDue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ProjectButton(
                key: const ValueKey<String>('proj-form-cancel'),
                label: '取消',
                onTap: widget.onCancel,
              ),
              const SizedBox(width: 8),
              ProjectButton(
                key: const ValueKey<String>('proj-form-ok'),
                label: '确定',
                primary: true,
                enabled: state.canSubmit,
                onTap: widget.onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
