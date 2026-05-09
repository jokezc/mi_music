import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/cache/music_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTestConfig {
  AppTestConfig._();

  static const bool enabled = bool.fromEnvironment(
    'MI_MUSIC_TEST_MODE',
    defaultValue: false,
  );

  static const String serverUrl = String.fromEnvironment(
    'MI_MUSIC_TEST_SERVER_URL',
    defaultValue: '',
  );

  static const String username = String.fromEnvironment(
    'MI_MUSIC_TEST_USERNAME',
    defaultValue: '',
  );

  static const String password = String.fromEnvironment(
    'MI_MUSIC_TEST_PASSWORD',
    defaultValue: '',
  );

  static const String playlistName = String.fromEnvironment(
    'MI_MUSIC_TEST_PLAYLIST_NAME',
    defaultValue: '',
  );

  static const String songName = String.fromEnvironment(
    'MI_MUSIC_TEST_SONG_NAME',
    defaultValue: '',
  );

  static const bool forceLocalDevice = bool.fromEnvironment(
    'MI_MUSIC_TEST_FORCE_LOCAL_DEVICE',
    defaultValue: true,
  );

  static bool get hasInjectedConnection => serverUrl.trim().isNotEmpty;

  static bool get hasPlaylistName => playlistName.trim().isNotEmpty;

  static bool get hasSongName => songName.trim().isNotEmpty;

  static Future<void> applySharedPreferences(
    SharedPreferences sharedPrefs,
  ) async {
    if (!enabled) return;

    final cacheManager = MusicCacheManager();
    await cacheManager.init();
    await cacheManager.clearPlayerStates();
    await cacheManager.close();

    if (hasInjectedConnection) {
      await sharedPrefs.setString(SharedPrefKeys.serverUrl, serverUrl.trim());
    }

    if (username.trim().isNotEmpty) {
      await sharedPrefs.setString(SharedPrefKeys.username, username.trim());
    }

    if (password.trim().isNotEmpty) {
      await sharedPrefs.setString(SharedPrefKeys.password, password.trim());
    }

    if (forceLocalDevice) {
      await sharedPrefs.setString(
        SharedPrefKeys.currentDeviceId,
        BaseConstants.webDevice,
      );
    }
  }
}
