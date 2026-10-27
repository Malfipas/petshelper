import 'dart:ui';

/// 桌宠贴在屏幕哪一侧。
///
/// 窗口层自己的概念，与 `domain/model/settings.dart` 的 `PetSide` 由 app 层对接；
/// 这一层不认识设置表，也不写库。
///
/// 目前只有 [right] 在用：使用者要求桌宠只出现在桌面右缘，左缘的几何留着
/// 是为了气泡与面板的横向锚点还有对称写法，不是待启用的功能。
enum WindowEdge { left, right }

/// 主显示器的工作区：桌面去掉任务栏之后，窗口能摆的那块。
///
/// 多屏时原点可能是负数（副屏在主屏左侧），这里一律用绝对坐标，不做归一化。
class ScreenWorkArea {
  const ScreenWorkArea({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// 由屏幕原点与可见尺寸构造。系统给的是可见区，任务栏已经扣掉。
  factory ScreenWorkArea.fromOrigin(Offset origin, Size size) =>
      ScreenWorkArea(left: origin.dx, top: origin.dy, width: size.width, height: size.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;

  /// 短边。宠物框是正方形，按短边取比例才不会被屏幕比例拉变形。
  double get shortSide => width < height ? width : height;
}

/// 收起态占工作区短边的比例。
///
/// PRD 第 1 页定的是 20%，实机看下来偏大：1080 高的屏上宠物占掉 216 像素，
/// 贴边一条比主界面的侧边还宽。按使用者 2026-10-25 的要求整体调低 5 个百分点。
const double collapsedScale = 0.15;

/// 展开态占工作区短边的比例。同上，PRD 的 30% 降到 25%。
const double expandedScale = 0.25;

/// 宠物框的边长。正方形，取工作区短边的比例。
double petBoxSide(ScreenWorkArea area, {required bool expanded}) =>
    area.shortSide * (expanded ? expandedScale : collapsedScale);

/// 算窗口该摆在哪。
///
/// 横向贴边：左缘贴工作区左边，右缘贴右边，不留缝。
/// 纵向按 [anchorY]（0 到 1，0 顶 1 底）分余量，屏再大也不会压在工作区正中。
/// 展开时保持贴屏那一侧的下角不动、从下往上长，切形态不跳位。
Rect petBounds({
  required ScreenWorkArea area,
  required WindowEdge edge,
  required double anchorY,
  required bool expanded,
}) {
  final collapsed = petBoxSide(area, expanded: false);
  final side = petBoxSide(area, expanded: expanded);
  final slack = _atLeastZero(area.height - collapsed);
  final collapsedTop = area.top + _clamp01(anchorY) * slack;
  final bottom = collapsedTop + collapsed;
  final top = _clamp(bottom - side, area.top, area.top + _atLeastZero(area.height - side));
  final left = edge == WindowEdge.left ? area.left : area.right - side;
  return Rect.fromLTWH(left, top, side, side);
}

/// 收起图与展开图的宽高比。素材是 `常驻-240.png` 109×240、`展开-360.png` 217×360。
const double collapsedPetAspect = 109 / 240;
const double expandedPetAspect = 217 / 360;

/// 宠物图在宠物框里的实际矩形。
///
/// 宠物框是正方形，竖条图按高度撑满、贴屏那一侧对齐（原型 `.pet` 用
/// `align-items:flex-end`，图片 `max-height:100%`）。气泡与面板的横向锚点
/// 认的是这张图，不是那个正方形框：整体原型 `placeX` 用的是图片的 `getBoundingClientRect()`。
Rect petImageBounds({required Rect box, required WindowEdge edge, required bool expanded}) {
  final width = box.height * (expanded ? expandedPetAspect : collapsedPetAspect);
  return Rect.fromLTWH(
    edge == WindowEdge.left ? box.left : box.right - width,
    box.top,
    width,
    box.height,
  );
}

/// 松手后的落位：横向一律回桌面右缘，只算纵向贴多高。
///
/// 使用者 2026-10-26 定下「只允许桌宠出现在桌面右缘，暂不做左缘」，于是换侧判定
/// 整块去掉了——没有中线、没有居中判左，拖到哪儿松手都回右缘，只剩纵向要记。
///
/// 纵向按「底边」反推，不按中心：展开态的框比收起态高，两种框的底边才是同一个
/// 锚点（`petBounds` 就是从收起态的底边往上长），按中心算会让展开态松手后上下跳。
double settleAnchorY({required ScreenWorkArea area, required Rect current}) {
  final collapsed = petBoxSide(area, expanded: false);
  final slack = _atLeastZero(area.height - collapsed);
  if (slack == 0) return 0.5;
  return _clamp01((current.bottom - collapsed - area.top) / slack);
}

double _atLeastZero(double value) => value < 0 ? 0 : value;

double _clamp01(double value) => value < 0 ? 0 : (value > 1 ? 1 : value);

double _clamp(double value, double low, double high) =>
    value < low ? low : (value > high ? high : value);
