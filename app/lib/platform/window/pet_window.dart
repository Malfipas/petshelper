import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'pet_layout.dart';
import 'window_driver.dart';
import 'window_geometry.dart';

/// 一次落位：贴多高。
///
/// 横向已经固定为桌面右缘（使用者 2026-10-26 的要求），所以这里只剩纵向比例。
typedef PetPlacement = ({double anchorY});

/// 桌宠窗口。
///
/// 管四件事：贴多高（可交给外面持久化）、三档尺寸（常驻 / 面板 / 主界面）、
/// 头顶气泡要不要占位、拖动与松手后的落位。形象与气泡内容都是界面层的事，
/// 这里只碰窗口。
class PetWindow {
  PetWindow(
    this._driver, {
    double initialAnchorY = 0.5,
    this.onPlacementChanged,
    this.onLayout,
  }) : _anchorY = initialAnchorY;

  final WindowDriver _driver;

  /// 落位变了通知外面一声，由调用方写进设置。只有纵向比例会变，
  /// 拖出去又放回原处时不通知，省掉一次无意义的落盘。
  final Future<void> Function(PetPlacement placement)? onPlacementChanged;

  /// 每次摆完位把新布局交出去。界面要按它换尺寸与内容位置，
  /// 窗口层不认识 widget，由 app 层翻成相对坐标。
  final void Function(PetLayout layout)? onLayout;

  /// 正在被拖。拖动期间界面不该弹悬停面板，松手后也要等指针离开再回来才恢复，
  /// 这条状态就是给界面层判断用的。
  final ValueNotifier<bool> dragging = ValueNotifier<bool>(false);

  /// 纵向比例小到这个程度当作没动，免得浮点误差每次都写库。
  static const double anchorEpsilon = 0.002;

  /// 拖动期间多久看一眼窗口位置。
  ///
  /// 松手这件事系统不告诉我们，只能靠「位置连续两次没变」反推。[WindowDriver.dragEnded]
  /// 那条路留着当第二只手：窗口移动事件偶尔会漏，漏一次就再也收不到「停下」。
  static const Duration dragPollInterval = Duration(milliseconds: 80);

  double _anchorY;
  PetStage _stage = PetStage.collapsed;
  double? _deadlineHeight;
  double? _reportHeight;
  ScreenWorkArea? _area;
  PetLayout? _layout;
  StreamSubscription<void>? _dragEndedSub;
  Timer? _dragPoll;
  Rect? _lastBounds;
  int _stillTicks = 0;

  /// 拖动中的宠物框（屏幕绝对坐标）。空表示没在拖。
  ///
  /// 主界面档拖宠物要自己算——交给系统会连主界面一起搬走，见 [beginDrag]。
  Rect? _draggingPet;

  /// 拖动中的宠物至少留这么多在屏里，免得拖出去就再也抓不回来。
  static const double petKeepVisible = 48;

  /// 宠物只贴桌面右缘。留着这个读法，是因为布局层的气泡与面板仍按侧别算锚点。
  WindowEdge get edge => WindowEdge.right;

  double get anchorY => _anchorY;
  PetStage get stage => _stage;

  /// 当前这一档的布局，界面按它把宠物、气泡、面板、主界面摆进窗口。
  PetLayout? get layout => _layout;

  /// 主界面档等于「展开」。留着这个读法，起窗流程与界面判断都按它说事。
  bool get expanded => _stage == PetStage.main;

  /// 起窗：先把窗口样式准备好，再按记住的高度摆到位。
  Future<void> open() async {
    await _driver.prepare();
    _area = await _driver.workArea();
    _dragEndedSub ??= _driver.dragEnded.listen((_) => unawaited(endDrag()));
    await _place();
  }

  /// 换档。每档窗口尺寸不同，换完要重新摆位，否则内容会被裁掉。
  ///
  /// 置顶跟着换：桌宠与面板要压在所有窗口上面，主界面却必须能被别的窗口盖住——
  /// 使用者 2026-10-26 的反馈里，一直置顶会让主界面永远挡住他正在用的程序。
  Future<void> setStage(PetStage stage) async {
    if (_stage == stage) return;
    _stage = stage;
    // 换档时把「拖动中」这件事收掉：比如拖到一半点了收起，宠物那半截位置
    // 就不该再拽着窗口停在铺满的样子。
    _draggingPet = null;
    dragging.value = false;
    await _place();
    await _driver.setAlwaysOnTop(stage != PetStage.main);
  }

  /// 收起与主界面两档的开关。
  Future<void> setExpanded(bool value) => setStage(value ? PetStage.main : PetStage.collapsed);

  /// 气泡要不要占位、各占多高。
  ///
  /// 传 `null` 表示这一档不出现。高度由界面层按内容算好交过来：原型的气泡是
  /// 内容自然高度，窗口提前不知这个数就会把文字裁掉。
  Future<void> setBubbles({required double? deadlineHeight, required double? reportHeight}) async {
    if (_deadlineHeight == deadlineHeight && _reportHeight == reportHeight) {
      return;
    }
    _deadlineHeight = deadlineHeight;
    _reportHeight = reportHeight;
    await _place();
  }

  /// 起手拖宠物。调用方先用 `canStartDrag` 看过按键，这里不再看。
  ///
  /// 两档两套走法，区别只在于窗口里除了宠物还有没有别的东西：
  /// - 常驻档：窗口就是宠物，交给系统整窗拖，跟手最省事；
  /// - 主界面档：窗口是「主界面 ∪ 宠物」，系统拖会把主界面一起搬走（使用者反馈的
  ///   「连带拖动」）。这一档改成窗口临时铺满工作区、宠物按指针自己走，
  ///   主界面原地不动，松手再缩回并集。
  ///
  /// 面板档不给拖——面板上要能点东西。
  Future<void> beginDrag() async {
    if (_stage == PetStage.panel || dragging.value) return;
    final area = _area ?? await _driver.workArea();
    _area = area;
    dragging.value = true;

    if (_stage == PetStage.main) {
      _draggingPet = _layout?.pet ??
          petBounds(area: area, edge: WindowEdge.right, anchorY: _anchorY, expanded: true);
      await _place();
      return;
    }

    _lastBounds = await _driver.bounds();
    _stillTicks = 0;
    _dragPoll?.cancel();
    _dragPoll = Timer.periodic(dragPollInterval, (_) => unawaited(_pollDrag()));
    await _driver.startDrag();
  }

  /// 拖动中把宠物挪一段。只有主界面档自己算的时候用得着；常驻档由系统跟手。
  ///
  /// 指针的位移就是宠物的位移，横向与纵向都允许跟手（松手才吸回右缘），
  /// 但至少留 [petKeepVisible] 那么多在屏里，拖出去还抓得回来。
  Future<void> dragPetBy(Offset delta) async {
    final pet = _draggingPet;
    if (pet == null || delta == Offset.zero) return;
    final area = _area ?? await _driver.workArea();
    _area = area;
    final minLeft = area.left - pet.width + petKeepVisible;
    final maxLeft = area.right - petKeepVisible;
    final minTop = area.top - pet.height + petKeepVisible;
    final maxTop = area.bottom - petKeepVisible;
    // Rect 自己没有 clamp，横纵各夹一次。
    _draggingPet = Rect.fromLTWH(
      (pet.left + delta.dx).clamp(minLeft, maxLeft).toDouble(),
      (pet.top + delta.dy).clamp(minTop, maxTop).toDouble(),
      pet.width,
      pet.height,
    );
    await _place();
  }

  /// 松手：纵向吸附成比例，横向一律回桌面右缘。
  ///
  /// 位置取的是「宠物框」而不是整个窗口：主界面档窗口里还装着主界面，拿窗口中心
  /// 判位置会算进主界面那一大块。先摆位再通知：界面看到的窗口与实际位置一致，
  /// 不用等写库回来。
  ///
  /// 常驻档的松手由系统拖动反推（轮询与 `dragEnded` 两条路），主界面档由界面
  /// 在抬手时显式调用这里。
  Future<void> endDrag() async {
    if (!dragging.value) return;
    dragging.value = false;
    _dragPoll?.cancel();
    _dragPoll = null;
    final area = _area ?? await _driver.workArea();
    _area = area;

    final Rect petRect;
    final movedPet = _draggingPet;
    if (movedPet != null) {
      petRect = movedPet;
    } else {
      final Rect bounds;
      try {
        bounds = _lastBounds = await _driver.bounds();
      } on Object {
        _stillTicks = 0;
        return;
      }
      final layout = _layout;
      petRect = layout == null
          ? bounds
          : layout.pet.shift(bounds.topLeft - layout.window.topLeft);
    }
    _stillTicks = 0;
    _draggingPet = null;

    final anchorY = settleAnchorY(area: area, current: petRect);
    final moved = (anchorY - _anchorY).abs() > anchorEpsilon;
    _anchorY = anchorY;
    await _place();
    if (moved) await onPlacementChanged?.call((anchorY: _anchorY));
  }

  /// 拖动期间每 [dragPollInterval] 看一眼：位置连续两拍没变就当作松手了。
  Future<void> _pollDrag() async {
    if (!dragging.value) return;
    final Rect now;
    try {
      now = await _driver.bounds();
    } on Object {
      return;
    }
    if (_lastBounds == now) {
      _stillTicks++;
      if (_stillTicks >= 2) await endDrag();
      return;
    }
    _lastBounds = now;
    _stillTicks = 0;
  }

  void dispose() {
    _dragEndedSub?.cancel();
    _dragEndedSub = null;
    _dragPoll?.cancel();
    _dragPoll = null;
    dragging.dispose();
  }

  Future<void> _place() async {
    final area = _area ?? await _driver.workArea();
    _area = area;
    // 只有主界面档才铺满：常驻档窗口本来就等于宠物，铺满反而白占一屏。
    final moving = _stage == PetStage.main && _draggingPet != null;
    final layout = petLayout(
      area: area,
      edge: WindowEdge.right,
      anchorY: _anchorY,
      stage: _stage,
      petOverride: moving ? _draggingPet : null,
      // 拖宠物时窗口铺满工作区：主界面与宠物的屏幕位置各自独立，窗口这一层
      // 临时变大不会把它们带着走。
      windowOverride: moving
          ? Rect.fromLTWH(area.left, area.top, area.width, area.height)
          : null,
      showDeadlineBubble: _deadlineHeight != null,
      showReportBubble: _reportHeight != null,
      deadlineHeight: _deadlineHeight ?? 0,
      reportHeight: _reportHeight ?? 0,
    );
    _layout = layout;
    await _driver.placeAt(layout.window);
    onLayout?.call(layout);
  }
}
