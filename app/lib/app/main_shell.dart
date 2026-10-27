import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/pet/pet_frame.dart';
import '../features/pet/pet_on_main.dart';
import '../features/projects/projects_notifier.dart';
import '../features/tasks/solo_notifier.dart';
import 'routes.dart';
import 'theme.dart';

/// 主界面五标签。顺序与整体原型一致；`path` 同时是路由地址，
/// 标签跳转与「气泡点查看直接落到某一页」共用同一个字符串。
enum MainTab {
  solo('独立事项', '/main/solo'),
  projects('我的项目', '/main/projects'),
  records('我的记录', '/main/records'),
  ideas('想法盒', '/main/ideas'),
  settings('设置', '/main/settings');

  const MainTab(this.label, this.path);

  final String label;
  final String path;

  /// 按路径找回标签；不是五页之一就给 null，由调用方决定兜底。
  static MainTab? byPath(String path) {
    for (final tab in values) {
      if (tab.path == path) return tab;
    }
    return null;
  }
}

/// 主界面壳：顶部五标签，下方是页面区。
///
/// 壳就是窗口本身：窗口层已经按原型把主界面档算成「宽高各七成、最小
/// 880×560、居中」（`mainBounds`），这一层再套固定尺寸或外边距，壳就会比窗口小，
/// 四边漏出透明缝。原型第 3 页那层「桌面变暗」的遮罩没做——它要求全屏窗口，
/// 而不穿透的全屏窗口会挡住桌面操作，与 PRD 316 冲突，留到 B24 与穿透一起做；
/// 原型 `.main` 的 `box-shadow` 同理不下发，窗口正好等于壳的尺寸，画出去的影子会被裁掉。
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.tab, required this.child});

  /// 当前停在哪一页，决定哪个标签高亮。
  final MainTab tab;

  /// 当前页面的内容，由路由表给。
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 壳按窗口里「主界面那一块」摆：主界面档的窗口是「主界面 ∪ 宠物」，宠物贴在
    // 桌面边缘，主界面不再是整个窗口，壳就得按 frame.main 缩回来，否则会被撑到宠物那边。
    final frame = ref.watch(petFrameProvider);
    // 主界面那一块由窗口层算好塞进 frame.main；还没接上真窗口（widget 测试、
    // 启动第一帧）时它是空的，这时就让壳铺满窗口，不拿占位尺寸去缩。
    final area = frame.main;

    // 壳填满主界面那一块：四角透出桌面，按原型 `border-radius:18px` 圆着落在那儿。
    // 内边距取原型 `.main` 的 `padding:16px 18px 18px`：上 16，左右与下 18。
    //
    // 顶部那 16 像素只当留白，不再是拖动区：使用者 2026-10-27 要求主界面不许拖，
    // 只有桌宠能拖（主界面固定居中，位置由窗口层 `mainBounds` 算）。
    final shell = Container(
      key: const ValueKey<String>('main-shell'),
      decoration: BoxDecoration(
        color: AppTheme.shellBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusShell),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16, key: ValueKey<String>('main-shell-top')),
          Expanded(
            child: Padding(
              key: const ValueKey<String>('main-shell-body'),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 原型 `.tabs` 只有五个标签，没有产品名标题，左侧留 4 像素起头。
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        for (final item in MainTab.values)
                          _TabButton(tab: item, selected: item == tab),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    // 页面纸：原型 `.sheet` 的 `padding:26px 30px`、圆角 14、细边框。
                    child: Container(
                      key: const ValueKey<String>('main-sheet'),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPage),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // PRD 418：主界面档按 Esc 回常驻态。焦点用 autofocus 拿，不另设快捷键。
    // PRD 484：独立事项页有展开的详情时，第一下先收详情，第二下才收壳。
    // PRD 625：项目页的删除弹窗开着时 Esc 只关弹窗，其次退回列表。
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          if (tab == MainTab.solo && ref.read(soloListProvider.notifier).collapseDetail()) {
            return KeyEventResult.handled;
          }
          if (tab == MainTab.projects && ref.read(projectListProvider.notifier).collapse()) {
            return KeyEventResult.handled;
          }
          context.go(AppRoutes.pet);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (area == null) Positioned.fill(child: shell) else Positioned.fromRect(rect: area, child: shell),
            // 展开态宠物贴在桌面边缘：它同时是主界面唯一的关闭入口。
            PetOnMain(onCollapsed: () => context.go(AppRoutes.pet)),
          ],
        ),
      ),
    );
  }
}

/// 单个标签。点一下直接改路由，不在壳里存一份「当前页」的副本，
/// 免得地址与界面各说各话。
///
/// 样式照原型 `.tab`：最小高 38、水平内边距 20、圆角 12、字 14；
/// 选中态 `.tab.on` 多一层白底、细边框、字重 600 与 `0 2 8` 的浅影；
/// 悬停 `.tab:hover` 只把字色提到主墨色，底色与边框都不动。
class _TabButton extends StatefulWidget {
  const _TabButton({required this.tab, required this.selected});

  final MainTab tab;
  final bool selected;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  /// 原型 `.tab{font-size:14px}`。字号令牌里没有 14 这一档（页标题 18、事名 15、
  /// 正文 13），标签是唯一用到 14 的地方，就地写死，不为此改全站档位。
  static const double _labelSize = 14;

  /// 原型 `.tab{transition:color .15s,background .15s,border-color .15s,
  /// box-shadow .15s}`（228 行）。只补颜色、边框与阴影，尺寸不参与动画。
  static const Duration _transition = Duration(milliseconds: 150);

  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final textColor = selected || _hovering ? AppTheme.ink : AppTheme.ink2;
    final radius = BorderRadius.circular(AppTheme.radiusCard);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        // 白底改由 AnimatedContainer 画，Material 只留一层透明好接水波；
        // 原型没有水波与 hover 遮罩，两者都关掉，免得在选中白底上盖一块灰。
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: InkWell(
            key: ValueKey<String>('tab-${widget.tab.name}'),
            borderRadius: radius,
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () => context.go(widget.tab.path),
            child: AnimatedContainer(
              key: ValueKey<String>('tab-box-${widget.tab.name}'),
              duration: _transition,
              curve: Curves.ease,
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: radius,
                border: Border.all(color: selected ? AppTheme.line : Colors.transparent),
                boxShadow: selected
                    ? const [
                        BoxShadow(color: Color(0x141E3250), blurRadius: 8, offset: Offset(0, 2)),
                      ]
                    : null,
              ),
              child: AnimatedDefaultTextStyle(
                duration: _transition,
                curve: Curves.ease,
                // 字体族必须显式带上：AnimatedDefaultTextStyle 是「替换」而不是
                // 「合并」环境样式，漏了就落回系统默认字，和页面标题的字形对不上。
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: textColor,
                  fontSize: _labelSize,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(widget.tab.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
