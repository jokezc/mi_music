import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mi_music/data/services/umeng_service.dart';

/// 友盟页面统计观察者
/// 自动追踪页面访问，需要在GoRouter中注册
class UmengPageObserver extends NavigatorObserver {
  /// 当前页面名称
  String? _currentPageName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _onPageStart(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _onPageEnd(route);
    if (previousRoute != null) {
      _onPageStart(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      _onPageEnd(oldRoute);
    }
    if (newRoute != null) {
      _onPageStart(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _onPageEnd(route);
    if (previousRoute != null) {
      _onPageStart(previousRoute);
    }
  }

  /// 页面开始
  void _onPageStart(Route<dynamic> route) {
    final pageName = _getPageName(route);
    if (pageName != null && pageName != _currentPageName) {
      // 如果之前有页面，先结束它
      if (_currentPageName != null) {
        UmengService.onPageEnd(_currentPageName!);
      }
      _currentPageName = pageName;
      UmengService.onPageStart(pageName);
    }
  }

  /// 页面结束
  void _onPageEnd(Route<dynamic> route) {
    final pageName = _getPageName(route);
    if (pageName != null && pageName == _currentPageName) {
      UmengService.onPageEnd(pageName);
      _currentPageName = null;
    }
  }

  /// 从路由中提取页面名称
  String? _getPageName(Route<dynamic> route) {
    // 尝试从GoRoute的settings中获取名称
    if (route.settings is GoRouterState) {
      final state = route.settings as GoRouterState;
      final location = state.uri.toString();
      
      // 将路径转换为友好的页面名称
      return _formatPageName(location);
    }
    
    // 如果没有GoRouterState，使用路由名称
    final routeName = route.settings.name;
    if (routeName != null) {
      return _formatPageName(routeName);
    }
    
    return null;
  }

  /// 格式化页面名称
  /// 将路径转换为友好的页面名称，例如：/playlist/我的歌单 -> playlist_detail
  String _formatPageName(String path) {
    if (path.isEmpty || path == '/') {
      return 'library'; // 首页
    }
    
    // 移除查询参数
    final uri = Uri.tryParse(path);
    if (uri != null) {
      path = uri.path;
    }
    
    // 移除前导斜杠
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    // 处理特殊路径
    if (path == 'login') {
      return 'login';
    } else if (path == 'settings') {
      return 'settings';
    } else if (path == 'player') {
      return 'player';
    } else if (path.startsWith('playlist/')) {
      return 'playlist_detail';
    } else if (path == 'search') {
      return 'search';
    } else if (path == 'download') {
      return 'download';
    } else if (path == 'functions') {
      return 'functions';
    } else if (path.startsWith('cron-task/')) {
      return 'cron_task';
    } else if (path == 'manage-playlists') {
      return 'manage_playlists';
    } else if (path == 'song-multi-select') {
      return 'song_multi_select';
    } else if (path == 'connection-config') {
      return 'connection_config';
    } else if (path == 'about') {
      return 'about';
    } else if (path == 'appearance') {
      return 'appearance';
    } else if (path == 'client-settings') {
      return 'client_settings';
    }
    
    // 默认使用路径，将斜杠替换为下划线
    return path.replaceAll('/', '_');
  }
}
