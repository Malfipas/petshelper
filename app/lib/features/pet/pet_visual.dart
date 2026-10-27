import '../../domain/model/settings.dart';

/// 常驻形象：两只朝屏幕中间看，贴哪边用哪张。
const String petCollapsedLeft = 'assets/桌宠/常驻-240.png';
const String petCollapsedRight = 'assets/桌宠/常驻右-240.png';

/// 展开形象：点开主界面之后那一档。
const String petExpandedImage = 'assets/桌宠/展开-360.png';

/// 现在该显示哪张图。
///
/// 竖条图（109×240）放在正方形宠物框里会留白，所以界面按贴屏那一侧对齐，
/// 留白落在屏幕内侧，看上去仍是贴着边站的。
String petImageOf({required PetSide side, required bool expanded}) {
  if (expanded) return petExpandedImage;
  return side == PetSide.left ? petCollapsedLeft : petCollapsedRight;
}
