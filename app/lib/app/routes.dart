/// 主界面之外的落点。
///
/// 桌宠与悬停面板是同一扇窗的两档，地址单独留在这里：路由表、主界面壳
/// 与展开态桌宠都要用它回到常驻态，谁都不手写 `'/pet'`。
class AppRoutes {
  AppRoutes._();

  static const String pet = '/pet';
  static const String panel = '/panel';
}
