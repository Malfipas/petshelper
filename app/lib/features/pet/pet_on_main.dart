import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/settings.dart';
import '../../platform/window/drag_rule.dart';
import 'pet_frame.dart';
import 'pet_notifier.dart';
import 'pet_stage_port.dart';
import 'pet_visual.dart';

/// 主界面上的展开态桌宠。
///
/// 主界面档里常驻态那一页已经被路由换掉了，宠物得由壳这一层自己画：
/// 按窗口层给的框贴在桌面那一侧，点一下收起主界面回到常驻态，按住拖则整只搬走。
class PetOnMain extends ConsumerStatefulWidget {
  const PetOnMain({super.key, required this.onCollapsed});

  /// 收起之后回哪一页由壳决定——features 不认识路由。
  final VoidCallback onCollapsed;

  @override
  ConsumerState<PetOnMain> createState() => _PetOnMainState();
}

class _PetOnMainState extends ConsumerState<PetOnMain> {
  /// 拖动起手前要先走这么多像素，免得点一下收起被当成拖动。
  static const double _dragSlop = 4;

  Offset? _pressAt;
  bool _dragStarted = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petNotifierProvider);
    if (state.stage != PetViewStage.main) return const SizedBox.shrink();

    final frame = ref.watch(petFrameProvider);
    return Positioned.fromRect(
      rect: frame.pet,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Listener(
          onPointerDown: (event) {
            if (!canStartDrag(event.buttons)) return;
            _pressAt = event.position;
            _dragStarted = false;
          },
          onPointerMove: (event) {
            // 已经在拖：位移交给窗口层，宠物的框会跟着重算，主界面那一块不动。
            if (_dragStarted) {
              if (event.delta != Offset.zero) {
                unawaited(ref.read(petStagePortProvider).dragBy(event.delta));
              }
              return;
            }
            final from = _pressAt;
            if (from == null) return;
            if (!canStartDrag(event.buttons)) return;
            if ((event.position - from).distance <= _dragSlop) return;
            _dragStarted = true;
            _pressAt = null;
            _startDrag();
          },
          onPointerUp: (_) => _endDrag(),
          onPointerCancel: (_) => _endDrag(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _collapse,
            child: Align(
              alignment: Alignment.centerRight,
              child: Image.asset(
                petImageOf(side: PetSide.right, expanded: true),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _collapse() {
    ref.read(petNotifierProvider.notifier).collapse();
    unawaited(ref.read(petStagePortProvider).showCollapsed());
    widget.onCollapsed();
  }

  /// 展开态起手拖动：只搬宠物，主界面钉在原地。
  ///
  /// 窗口层会在这期间把窗口铺满工作区、由这里逐帧喂位移，所以拖动时既不会把
  /// 主界面一起拖走，也不会把界面收起来。
  void _startDrag() {
    unawaited(_beginDrag(ref.read(petStagePortProvider)));
  }

  Future<void> _beginDrag(PetStagePort port) async {
    await port.beginDrag();
    // 起手就抬手的话，beginDrag 可能还没回来：补一次收尾，别让窗口停在铺满的样子。
    if (!_dragStarted) await port.endDrag();
  }

  void _endDrag() {
    _pressAt = null;
    if (!_dragStarted) return;
    _dragStarted = false;
    unawaited(ref.read(petStagePortProvider).endDrag());
  }
}
