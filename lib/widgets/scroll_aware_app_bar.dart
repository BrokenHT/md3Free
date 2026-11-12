import 'package:material_ui/material_ui.dart';

import '../core/layout/page_title_alignment.dart';

const double _kTitleTrailingGap = 8.0;

/// Transparent page header for md3Free. Scaffold places it outside the scroll
/// viewport, so the atmosphere stays continuous without a dark scroll rectangle
/// or per-pixel scroll listener. Legacy constructor arguments remain compatible.
class ScrollAwareAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final ScrollController? scrollController;
  final double fadeRange;
  final Widget? leading;

  /// 紧跟在标题右边的一枚组件（如发现页的问候胶囊），跟着标题左对齐。
  ///
  /// 宽度由它自己的内容决定，上限是标题区剩下的宽度——[AppBar] 的标题区不含
  /// actions 那一段，中间还留着 [NavigationToolbar.kMiddleSpacing]，所以它再长
  /// 也碰不到第一枚图标按钮。
  final Widget? titleTrailing;

  /// 为 true 时背景不做滚动透明度渐变：未启用自定义背景时恒为不透明
  /// surface；启用自定义背景时完全透明（与主题 appBarTheme 一致），
  /// 让顶部与页面主体的壁纸透出透明度上下一致（参照「我的收藏」页）。
  ///
  /// 用于有全局背景图/滚动时内容透出会导致标题文字与背景重叠变色的页面
  /// （如发现页顶部）。
  final bool opaque;

  /// 页面在底部导航栏中的 tab id（取值见 [kAllAvailableTabs]），用于按
  /// [centerPageTitle] 判定标题对齐：tab 可直达的一级页面左对齐，二级页面居中。
  ///
  /// 从来不作为 tab 出现的页面（各类详情页/列表页）不传，标题自动居中。
  final String? tabId;

  /// 标题**左对齐**（一级固定页）时的 `AppBar.titleSpacing`（计划 ⑦）。
  ///
  /// 默认 [AppBar] 左对齐 titleSpacing 是 [NavigationToolbar.kMiddleSpacing]（16dp），
  /// 常比页面 body 内容的左内边距（网格 12、SongListItem ~10）更宽，视觉上标题比
  /// 内容更靠右。传入页面内容的实际左内边距即可对齐（内容齐边则传 0）。
  /// 居中（二级页面）时忽略此值、用 [AppBar] 默认。null 表示保持 [AppBar] 默认。
  final double? titleSpacing;

  const ScrollAwareAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.scrollController,
    this.fadeRange = 80,
    this.leading,
    this.titleTrailing,
    this.opaque = false,
    this.tabId,
    this.titleSpacing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<ScrollAwareAppBar> createState() => _ScrollAwareAppBarState();
}

class _ScrollAwareAppBarState extends State<ScrollAwareAppBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final centerTitle = centerPageTitle(context, tabId: widget.tabId);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0, // 关闭 Material 3 自带突变变色
      surfaceTintColor: Colors.transparent, // 关闭 surfaceTint 着色
      foregroundColor: colorScheme.onSurface,
      leading: widget.leading,
      // 标题始终显示（用户反馈：初始就应可见，不依赖滚动）
      title: _buildTitle(textTheme),
      actions: widget.actions,
      // 统一对齐规则：底部导航栏可直达的一级页面左对齐，二级页面居中
      centerTitle: centerTitle,
      // 左对齐时标题左内边距对齐页面内容（计划 ⑦）；居中时用 AppBar 默认
      titleSpacing: centerTitle ? null : widget.titleSpacing,
    );
  }

  Widget _buildTitle(TextTheme textTheme) {
    final titleText =
        widget.titleWidget ??
        Text(
          widget.title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        );
    final trailing = widget.titleTrailing;
    if (trailing == null) return titleText;
    return Row(
      children: [
        titleText,
        const SizedBox(width: _kTitleTrailingGap),
        Flexible(child: trailing),
      ],
    );
  }
}
