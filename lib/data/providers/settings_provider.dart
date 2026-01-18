import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

@riverpod
class Settings extends _$Settings {
  @override
  ({String serverUrl, String username, String password, bool pauseCurrentDeviceOnSwitch, bool syncPlaybackOnSwitch})
  build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (
      serverUrl: prefs.getString(SharedPrefKeys.serverUrl) ?? '',
      username: prefs.getString(SharedPrefKeys.username) ?? '',
      password: prefs.getString(SharedPrefKeys.password) ?? '',
      pauseCurrentDeviceOnSwitch: prefs.getBool(SharedPrefKeys.pauseCurrentDeviceOnSwitch) ?? true,
      syncPlaybackOnSwitch: prefs.getBool(SharedPrefKeys.syncPlaybackOnSwitch) ?? false,
    );
  }

  Future<void> setServerUrl(String url) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(SharedPrefKeys.serverUrl, url);
    // settingsProvider 是 autoDispose，async gap 期间可能已被销毁
    if (!ref.mounted) return;
    state = (
      serverUrl: url,
      username: state.username,
      password: state.password,
      pauseCurrentDeviceOnSwitch: state.pauseCurrentDeviceOnSwitch,
      syncPlaybackOnSwitch: state.syncPlaybackOnSwitch,
    );
  }

  Future<void> setCredentials(String username, String password) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(SharedPrefKeys.username, username);
    await prefs.setString(SharedPrefKeys.password, password);
    // settingsProvider 是 autoDispose，async gap 期间可能已被销毁
    if (!ref.mounted) return;
    state = (
      serverUrl: state.serverUrl,
      username: username,
      password: password,
      pauseCurrentDeviceOnSwitch: state.pauseCurrentDeviceOnSwitch,
      syncPlaybackOnSwitch: state.syncPlaybackOnSwitch,
    );
  }

  /// 批量设置 API 配置（URL、用户名、密码），一次性更新 state，避免多次通知
  Future<void> setApiConfig(String url, String username, String password) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(SharedPrefKeys.serverUrl, url);
    await prefs.setString(SharedPrefKeys.username, username);
    await prefs.setString(SharedPrefKeys.password, password);
    // settingsProvider 是 autoDispose，async gap 期间可能已被销毁
    if (!ref.mounted) return;
    state = (
      serverUrl: url,
      username: username,
      password: password,
      pauseCurrentDeviceOnSwitch: state.pauseCurrentDeviceOnSwitch,
      syncPlaybackOnSwitch: state.syncPlaybackOnSwitch,
    );
  }

  Future<void> setPauseCurrentDeviceOnSwitch(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPrefKeys.pauseCurrentDeviceOnSwitch, value);
    // settingsProvider 是 autoDispose，async gap 期间可能已被销毁
    if (!ref.mounted) return;
    state = (
      serverUrl: state.serverUrl,
      username: state.username,
      password: state.password,
      pauseCurrentDeviceOnSwitch: value,
      syncPlaybackOnSwitch: state.syncPlaybackOnSwitch,
    );
  }

  Future<void> setSyncPlaybackOnSwitch(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPrefKeys.syncPlaybackOnSwitch, value);
    // settingsProvider 是 autoDispose，async gap 期间可能已被销毁
    if (!ref.mounted) return;
    state = (
      serverUrl: state.serverUrl,
      username: state.username,
      password: state.password,
      pauseCurrentDeviceOnSwitch: state.pauseCurrentDeviceOnSwitch,
      syncPlaybackOnSwitch: value,
    );
  }
}
