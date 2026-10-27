import 'dart:math' as math;
import 'dart:ui';

import 'window_geometry.dart';

/// 窗口当前该显示哪一档。
///
/// 单窗口应用里，可见内容变大窗口就得跟着变大——窗口之外的透明区域会挡住
/// 别的程序，所以不能靠「开一个大窗、里面留白」。三档各自的尺寸都在这里算。
enum PetStage {
  /// 只有宠物（可带头顶气泡）。
  collapsed,

  /// 宠物 + 悬停面板。
  panel,

  /// 主界面，宠物坐在贴屏那一侧的下角。
  main,
}

/// 面板宽占工作区宽度。整体原型 `.panel{width:30vw}`，实机嫌大降 5 个百分点。
const double panelWidthScale = 0.25;

/// 面板高占工作区高度。整体原型 `.panel{max-height:40vh}`，同样降 5 个百分点。
const double panelHeightScale = 0.35;

/// 气泡宽占工作区宽度。整体原型 `.bubbles{width:25vw}`。
const double bubbleWidthScale = 0.25;

/// 气泡最高占工作区高度。整体原型 `.bubble{max-height:30vh}`，超出在气泡内部滚动。
const double bubbleMaxHeightScale = 0.3;

/// 气泡栈底边压进宠物图头顶的深度。整体原型 `bubbles.top = r.top + 5 - 栈高`。
const double bubbleOverlap = 5;

/// 气泡与面板横向压进宠物图的深度。整体原型 `placeX`：偏移 = 图宽 - 15。
const double floatingInset = 15;

/// 两个气泡上下排开的缝。整体原型 `.bubbles{gap:8px}`。
const double bubbleGap = 8;

/// 浮层离工作区上下边的余量。整体原型 `Math.max(6, …)` / `Math.max(12, …)`。
const double floatingMargin = 12;

/// 面板接在气泡下方的缝。整体原型 `pt = bb + GAP + 6`，其中 GAP 为 5。
const double panelStackGap = 11;

/// 气泡内容高度的兜底值：调用方不传时按这个占位，别让窗口空着。
///
/// 真高度由界面层按内容算好传进来——原型的气泡是内容自然高度（上限 30vh），
/// 窗口必须提前知道这个数，否则气泡会被窗口裁掉。
const double deadlineBubbleHeight = 108;
const double reportBubbleHeight = 132;

/// 一档的总布局：窗口摆在屏幕哪、宠物、气泡、面板、主界面各占哪。
///
/// 坐标一律用屏幕绝对坐标；界面要的是相对窗口的位置，用 [petInWindow] 这些取值。
class PetLayout {
  const PetLayout({
    required this.stage,
    required this.window,
    required this.pet,
    this.panel,
    this.main,
    this.deadlineBubble,
    this.reportBubble,
  });

  final PetStage stage;

  /// 窗口该占的矩形。除 [PetStage.collapsed] 档外都比宠物大。
  final Rect window;

  /// 宠物框。
  final Rect pet;

  /// 悬停面板框，只有 [PetStage.panel] 档有。
  final Rect? panel;

  /// 主界面框，只有 [PetStage.main] 档有。
  final Rect? main;

  /// 截止气泡框。
  final Rect? deadlineBubble;

  /// 播报气泡框。
  final Rect? reportBubble;

  /// 换一个窗口矩形，其余各块不动。
  ///
  /// 拖动桌宠时窗口要临时铺满工作区（见 `PetWindow.beginDrag`）：宠物与主界面在屏幕上
  /// 的位置不变，只是窗口这一层变大，界面按新的窗口左上角换算相对坐标。
  PetLayout withWindow(Rect next) => PetLayout(
    stage: stage,
    window: next,
    pet: pet,
    panel: panel,
    main: main,
    deadlineBubble: deadlineBubble,
    reportBubble: reportBubble,
  );

  /// 宠物在窗口内的位置，界面按它摆图。
  Rect get petInWindow => pet.shift(-window.topLeft);

  /// 面板在窗口内的位置。
  Rect? get panelInWindow => panel?.shift(-window.topLeft);

  /// 主界面在窗口内的位置。
  Rect? get mainInWindow => main?.shift(-window.topLeft);

  /// 截止气泡在窗口内的位置。
  Rect? get deadlineBubbleInWindow => deadlineBubble?.shift(-window.topLeft);

  /// 播报气泡在窗口内的位置。
  Rect? get reportBubbleInWindow => reportBubble?.shift(-window.topLeft);
}

/// 主界面档窗口该占的矩形：宽高各七成，最小 880×560，整块居中。
///
/// 以前这里是「贴屏那一侧 + 宽封顶 720」，两处都跟原型对不上：原型
/// `.main` 是 `left:50%;top:50%;translate(-50%,-50%)` 地居中；而 720 的封顶
/// 比它自己的 `min-width:880` 还小，封顶一上，最小尺寸就成了空话。
///
/// 位置固定居中，不接受偏移：使用者 2026-10-27 要求主界面不许拖动，只有桌宠能拖。
Rect mainBounds({required ScreenWorkArea area}) {
  final width = math.min(area.width, math.max(area.width * mainWidthScale, mainMinWidth));
  final height = math.min(area.height, math.max(area.height * mainHeightScale, mainMinHeight));
  final left = area.left + (area.width - width) / 2;
  final top = area.top + (area.height - height) / 2;
  return Rect.fromLTWH(left, top, width, height);
}

/// 主界面宽占工作区宽度。整体原型 `.main{width:70vw}`。
const double mainWidthScale = 0.7;

/// 主界面高占工作区高度。整体原型 `.main{height:70vh}`。
const double mainHeightScale = 0.7;

/// 主界面的最小尺寸。整体原型 `min-width:880px;min-height:560px`，PRD 412 同值。
const double mainMinWidth = 880;
const double mainMinHeight = 560;

/// 算一档的布局。
///
/// 三档的浮层都照整体原型 `positionFloating()` 摆：
/// 气泡栈底边压在宠物图头顶往里 5 像素处，放不下就夹到工作区顶部，不翻到脚下；
/// 面板顶边也从宠物图顶往下 5 像素起，有气泡时接在气泡栈下面，谁都不盖谁。
/// 横向一律以宠物图为准：气泡与面板都往屏幕内侧伸，压进图宽 15 像素。
PetLayout petLayout({
  required ScreenWorkArea area,
  required WindowEdge edge,
  required double anchorY,
  required PetStage stage,
  Rect? petOverride,
  Rect? windowOverride,
  bool showDeadlineBubble = false,
  bool showReportBubble = false,
  double deadlineHeight = deadlineBubbleHeight,
  double reportHeight = reportBubbleHeight,
}) {
  final pet = petBounds(area: area, edge: edge, anchorY: anchorY, expanded: false);

  final layout = stage == PetStage.main
      ? _mainStage(area: area, edge: edge, anchorY: anchorY, petOverride: petOverride)
      : _compose(
          area: area,
          edge: edge,
          stage: stage,
          pet: pet,
          withPanel: stage == PetStage.panel,
          showDeadline: showDeadlineBubble,
          showReport: showReportBubble,
          deadlineHeight: deadlineHeight,
          reportHeight: reportHeight,
        );

  return windowOverride == null ? layout : layout.withWindow(windowOverride);
}

/// 主界面档：宠物不再坐在主界面里，而是自己贴到桌面边缘，气泡与面板都不出现。
///
/// 单窗口下要让宠物落在桌面边缘又不遮主界面，只能把窗口扩成「主界面 ∪ 宠物」：
/// 主界面固定居中，宠物在窗口里落在屏幕边上。主界面宽七成、两侧各留一成半，
/// 收起态缩到一成半之后宠物刚好落在这条空当里，几乎没有多出来的死区。
///
/// [petOverride] 是拖动中的宠物框（屏幕绝对坐标）：这时窗口被临时铺满，
/// 宠物按指针走、主界面还在原位，松手后这个值被清空，宠物吸回右缘。
PetLayout _mainStage({
  required ScreenWorkArea area,
  required WindowEdge edge,
  required double anchorY,
  Rect? petOverride,
}) {
  final main = mainBounds(area: area);
  final pet = petOverride ?? petBounds(area: area, edge: edge, anchorY: anchorY, expanded: true);
  return PetLayout(
    stage: PetStage.main,
    window: main.expandToInclude(pet),
    pet: pet,
    main: main,
  );
}

/// 把宠物、气泡、面板合成一个窗口。
PetLayout _compose({
  required ScreenWorkArea area,
  required WindowEdge edge,
  required PetStage stage,
  required Rect pet,
  required bool withPanel,
  required bool showDeadline,
  required bool showReport,
  required double deadlineHeight,
  required double reportHeight,
}) {
  final image = petImageBounds(box: pet, edge: edge, expanded: false);
  final bubbleWidth = area.width * bubbleWidthScale;

  // 气泡贴屏那一侧的内边落点：右缘时气泡右边缘压进图左边缘 15，左缘时反过来。
  final floatingLeft = edge == WindowEdge.right
      ? image.left + floatingInset - bubbleWidth
      : image.right - floatingInset;

  Rect? deadline;
  Rect? report;
  double? stackBottom;

  if (showDeadline || showReport) {
    final deadlineH = showDeadline ? _bubbleHeight(deadlineHeight, area) : 0.0;
    final reportH = showReport ? _bubbleHeight(reportHeight, area) : 0.0;
    final stackHeight = deadlineH + reportH + (showDeadline && showReport ? bubbleGap : 0);
    // 原型是 `Math.max(6, r.top + 5 - 栈高)`：贴得太高就夹在工作区顶，不换到脚下。
    final top = math.max(area.top + floatingMargin / 2, image.top + bubbleOverlap - stackHeight);

    var y = top;
    if (showDeadline) {
      deadline = Rect.fromLTWH(floatingLeft, y, bubbleWidth, deadlineH);
      y += deadlineH + (showReport ? bubbleGap : 0);
    }
    if (showReport) {
      report = Rect.fromLTWH(floatingLeft, y, bubbleWidth, reportH);
      stackBottom = y + reportH;
    } else {
      stackBottom = y;
    }
  }

  Rect? panel;
  if (withPanel) {
    final panelWidth = area.width * panelWidthScale;
    final panelHeight = area.height * panelHeightScale;
    final panelLeft = edge == WindowEdge.right
        ? image.left + floatingInset - panelWidth
        : image.right - floatingInset;
    // 原型 `pt = Math.max(12, r.top + 5)`：面板顶也从图顶往下 5 起，盖住宠物上半。
    var top = math.max(area.top + floatingMargin, image.top + bubbleOverlap);
    // 有气泡时接在气泡栈下面：`pt = bb + GAP + 6`。
    if (stackBottom != null) {
      top = math.max(top, stackBottom + panelStackGap);
    }
    top = math.min(top, area.bottom - panelHeight - floatingMargin);
    panel = Rect.fromLTWH(panelLeft, top, panelWidth, panelHeight);
  }

  var window = pet;
  if (deadline != null) window = window.expandToInclude(deadline);
  if (report != null) window = window.expandToInclude(report);
  if (panel != null) window = window.expandToInclude(panel);

  return PetLayout(
    stage: stage,
    window: window,
    pet: pet,
    panel: panel,
    deadlineBubble: deadline,
    reportBubble: report,
  );
}

/// 气泡高度夹到工作区的 30%：原型 `max-height:30vh`，超出的在气泡内部滚动。
///
/// 没给高度就按上限占位——窗口宁可多让一点也不裁内容。
double _bubbleHeight(double wanted, ScreenWorkArea area) {
  final max = area.height * bubbleMaxHeightScale;
  final value = wanted <= 0 ? max : wanted;
  return value > max ? max : value;
}
