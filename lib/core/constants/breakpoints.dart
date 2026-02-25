/// 响应式布局断点
/// 用于区分手机、平板、桌面，统一使用宽度判断（窗口缩放时自动切换）
class Breakpoints {
  Breakpoints._();

  /// 超过此宽度使用侧边导航（NavigationRail）而非底部导航
  static const double navRail = 600;

  /// 桌面端内容区域最大宽度，避免大屏上列表/文字过宽
  static const double maxContentWidth = 1200;
}
