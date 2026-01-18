import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shared_prefs_provider.g.dart';

/*
使用 shared_prefs_provider 的好处：
便于测试：只需 mock 一个 provider
职责分离：业务逻辑与存储实现解耦
代码复用：共享同一个实例
统一管理：所有存储操作集中管理
易于扩展：未来换存储方案只需改一处
这是依赖注入和单一职责原则的实践，让代码更易维护和测试。
*/


/// 共享偏好设置
/// 用户设置（服务器地址、登录信息）
/// 应用偏好（主题模式）
/// 播放器状态（播放进度、播放列表、设备选择等）
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  return throw UnimplementedError();
}
