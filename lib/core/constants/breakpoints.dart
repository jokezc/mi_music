/// 响应式布局断点
/// 用于区分手机、平板、桌面，统一使用宽度判断（窗口缩放时自动切换）
class Breakpoints {
  Breakpoints._();

  /// 超过此宽度使用侧边导航（NavigationRail）而非底部导航
  static const double navRail = 600;

  /// 超过此宽度可视为宽屏表单/详情布局
  static const double wideContent = 960;

  /// 桌面端内容区域最大宽度，避免大屏上列表/文字过宽
  static const double maxContentWidth = 1200;

  /// 全屏播放器在桌面/平板上的最大舒适宽度
  static const double maxPlayerWidth = 980;

  /// 单列表单类页面的理想最大宽度
  static const double maxFormWidth = 720;
}
