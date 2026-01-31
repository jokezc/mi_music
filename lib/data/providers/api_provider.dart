import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/data/network/api_client.dart';
import 'package:mi_music/data/providers/settings_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_provider.g.dart';

final _logger = Logger();

/// 自定义日志拦截器，只打印接口、入参和响应结果
class SimpleLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 将请求信息存储到 extra 中，以便在响应时一起打印
    final uri = options.uri;
    final path = uri.path;

    String requestData = '';
    if (options.data != null) {
      if (options.data is Map || options.data is List) {
        requestData = const JsonEncoder.withIndent('  ').convert(options.data);
      } else {
        requestData = options.data.toString();
      }
    } else if (options.queryParameters.isNotEmpty) {
      requestData = const JsonEncoder.withIndent('  ').convert(options.queryParameters);
    }

    // 存储请求信息到 extra
    options.extra['_log_path'] = path;
    options.extra['_log_request'] = requestData;

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 获取请求信息
    final path = response.requestOptions.extra['_log_path'] as String? ?? '';
    final requestData = response.requestOptions.extra['_log_request'] as String? ?? '';

    // 打印响应结果
    String responseData = '';
    if (response.data != null) {
      if (response.data is Map || response.data is List) {
        responseData = const JsonEncoder.withIndent('  ').convert(response.data);
      } else {
        responseData = response.data.toString();
      }
    }

    // 一起打印请求和响应
    // 维护不打印的地址列表
    final ignorePaths = ['/musiclist', '/musicinfo', '/musicinfos', '/getsetting', '/playingmusic'];
    final ignoreAllPaths = ['/playingmusic'];

    final buffer = StringBuffer();
    buffer.writeln('接口: $path');
    if (requestData.isNotEmpty && !ignorePaths.contains(path)) {
      buffer.writeln('请求: $requestData');
    }
    if (!ignorePaths.contains(path)) {
      buffer.write('响应: $responseData');
    }

    if (!ignoreAllPaths.contains(path)) {
      _logger.d(buffer.toString());
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 获取请求信息
    final path = err.requestOptions.extra['_log_path'] as String? ?? '';
    final requestData = err.requestOptions.extra['_log_request'] as String? ?? '';

    // 打印错误响应
    String errorData = '';
    if (err.response?.data != null) {
      if (err.response!.data is Map || err.response!.data is List) {
        errorData = const JsonEncoder.withIndent('  ').convert(err.response!.data);
      } else {
        errorData = err.response!.data.toString();
      }
    }

    // 一起打印请求和错误响应
    final buffer = StringBuffer();
    buffer.writeln('接口: $path');
    if (requestData.isNotEmpty) {
      buffer.writeln('入参: $requestData');
    }
    buffer.writeln('响应结果 (错误): $errorData');
    if (err.message != null) {
      buffer.write('错误信息: ${err.message}');
    }

    _logger.e(buffer.toString());

    handler.next(err);
  }
}

/// 认证状态管理
/// true 表示已认证，false 表示未认证（需要登录）
@riverpod
class AuthState extends _$AuthState {
  @override
  bool build() => true; // 默认已认证

  /// 设置为未认证状态（触发跳转到登录页）
  void setUnauthorized() {
    state = false;
  }

  /// 设置为已认证状态
  void setAuthorized() {
    state = true;
  }
}

/// 认证拦截器，处理 401 未授权错误，更新认证状态
class AuthInterceptor extends Interceptor {
  final Ref ref;

  // 静态变量，用于防止多个 401 错误导致重复更新状态
  static DateTime? _lastUpdateTime;
  static const _updateDebounceDuration = Duration(milliseconds: 500);

  AuthInterceptor(this.ref);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 检查是否是 401 未授权错误
    if (err.response?.statusCode == 401) {
      // 防抖处理：如果距离上次更新时间太短，则忽略
      final now = DateTime.now();
      if (_lastUpdateTime != null && now.difference(_lastUpdateTime!) < _updateDebounceDuration) {
        handler.next(err);
        return;
      }

      // 更新最后更新时间，防止短时间内重复触发
      _lastUpdateTime = DateTime.now();

      // 更新认证状态，触发 router 的 redirect 逻辑
      // 注意：不需要检查当前路由，因为 router 的 redirect 已经会处理登录页的情况
      // 如果已经在登录页，redirect 不会再次跳转
      ref.read(authStateProvider.notifier).setUnauthorized();
    }

    handler.next(err);
  }
}

/// URL 修复拦截器，将后端返回的内网 URL 替换为当前配置的服务器地址
class UrlFixInterceptor extends Interceptor {
  final Ref ref;

  UrlFixInterceptor(this.ref);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final path = response.requestOptions.uri.path;

      // 优化：只解析一次 Server URL
      final serverUrl = ref.read(settingsProvider).serverUrl;
      if (serverUrl.isEmpty) {
        handler.next(response);
        return;
      }

      final serverUri = Uri.tryParse(serverUrl);
      if (serverUri == null || !serverUri.hasScheme || !serverUri.hasAuthority) {
        handler.next(response);
        return;
      }

      // 针对特定接口进行特定的字段修复，避免全量递归，提高性能
      // 主要是这两个接口: /musicinfos, /musicinfo
      if (path.endsWith('/musicinfos')) {
        // List<MusicInfoItem>
        if (response.data is List) {
          final list = response.data as List;
          for (var item in list) {
            if (item is Map) {
              _fixMusicInfoMap(item, serverUri);
            }
          }
        }
      } else if (path.endsWith('/musicinfo')) {
        _logger.d("修复 /musicinfo");
        // MusicInfoResp (Map)
        if (response.data is Map) {
          _fixMusicInfoMap(response.data as Map, serverUri);
        }
      }
    } catch (e) {
      _logger.e("URL 修复失败: $e");
    }
    handler.next(response);
  }

  // 针对 MusicInfo 结构的修复 (url 和 tags.picture)
  void _fixMusicInfoMap(Map item, Uri serverUri) {
    // 修复 url
    if (item['url'] is String) {
      item['url'] = _fixUrl(item['url'], serverUri);
    }
    // 修复 tags.picture
    if (item['tags'] is Map) {
      final tags = item['tags'] as Map;
      if (tags['picture'] is String) {
        tags['picture'] = _fixUrl(tags['picture'], serverUri);
      }
    }
  }

  String _fixUrl(String url, Uri serverUri) {
    if (url.isEmpty) return url;
    // 性能优化：如果 URL 已经包含目标 host，则直接返回，避免昂贵的解析操作
    // 这是一个启发式检查，假设文件名或路径中极少包含与 host 完全相同的字符串
    // 这对于长列表（如 /musicinfos）的性能提升非常显著
    if (url.contains(serverUri.host)) return url;

    try {
      // 快速检查：如果不是 http/https 开头，直接返回（可能是相对路径或文件路径）
      if (!url.startsWith('http')) return url;

      final uri = Uri.parse(url);

      // 判断逻辑：
      // 比较 URL 中的 host 与用户设置的 serverUrl host 是否一致
      // 如果不一致（例如后端返回了内网IP 192.168.x.x，而用户设置的是域名），则进行替换
      if (uri.host != serverUri.host) {
        _logger.d("修复 URL: $url -> ${uri.replace(scheme: serverUri.scheme, host: serverUri.host, port: serverUri.port).toString()}");
        return uri.replace(scheme: serverUri.scheme, host: serverUri.host, port: serverUri.port).toString();
      }
    } catch (e) {
      // ignore
    }
    return url;
  }
}

/// API 配置（从 settingsProvider 中 select 需要的字段）
/// 只包含与 API 相关的字段：serverUrl、username、password
@riverpod
({String serverUrl, String username, String password}) apiConfig(Ref ref) {
  return ref.watch(
    settingsProvider.select((s) => (serverUrl: s.serverUrl, username: s.username, password: s.password)),
  );
}

@riverpod
Dio dio(Ref ref) {
  // 只 watch API 配置相关的字段，避免本地设置变化时重建
  final config = ref.watch(apiConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.serverUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  if (config.username.isNotEmpty && config.password.isNotEmpty) {
    String basicAuth = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    dio.options.headers['Authorization'] = basicAuth;
  }

  // 先添加认证拦截器（在日志拦截器之前），确保 401 错误能被正确处理
  // 传入 ref 以便更新认证状态
  dio.interceptors.add(AuthInterceptor(ref));
  // 添加 URL 修复拦截器，确保所有 API 返回的 URL 都指向当前配置的服务器
  dio.interceptors.add(UrlFixInterceptor(ref));
  // 使用自定义的简单日志拦截器
  dio.interceptors.add(SimpleLogInterceptor());

  return dio;
}

@riverpod
ApiClient apiClient(Ref ref) {
  final dio = ref.watch(dioProvider);
  // 只 watch API 配置相关的字段，避免本地设置变化时重建
  final config = ref.watch(apiConfigProvider);
  return ApiClient(dio, baseUrl: config.serverUrl);
}

/// 认证验证结果
class AuthResult {
  final bool isAuthenticated;
  final String? version;
  final String? errorMessage;

  AuthResult({required this.isAuthenticated, this.version, this.errorMessage});

  factory AuthResult.authenticated(String version) => AuthResult(isAuthenticated: true, version: version);
  factory AuthResult.notAuthenticated(String errorMessage) =>
      AuthResult(isAuthenticated: false, errorMessage: errorMessage);
  factory AuthResult.error(String errorMessage) => AuthResult(isAuthenticated: false, errorMessage: errorMessage);
}

/// 服务端 getSetting 中的 hostname/public_port 与当前连接地址不一致时的信息
/// 用于提示用户并支持「跳转服务配置」或「快速修改」（不检测内部 port）
class HostPortMismatch {
  /// serverUrl 的协议，如 'https' / 'http'，快速修改时拼到 hostname 前
  final String connectionScheme;
  /// 用户当前连接的 host（域名或 IP）
  final String connectionHost;
  /// 用户当前连接的 port（若 URL 未写端口则为标准端口 80/443）
  final int connectionPort;
  /// 服务端配置的 hostname
  final String settingHostname;
  /// 服务端配置的 public_port（对外端口）
  final int settingPublicPort;

  HostPortMismatch({
    required this.connectionScheme,
    required this.connectionHost,
    required this.connectionPort,
    required this.settingHostname,
    required this.settingPublicPort,
  });

  /// 带协议的完整 hostname，用于快速修改保存（如 https://baidu.com）
  String get connectionHostnameWithScheme => '$connectionScheme://$connectionHost';
}

/// 检查当前连接的 serverUrl 与 getSetting 返回的 hostname/public_port 是否一致。
/// 只检测对外地址（public_port），不检测内部 port。
Future<HostPortMismatch?> checkSettingHostPortMatch(dynamic ref) async {
  final serverUrl = ref.read(settingsProvider).serverUrl;
  if (serverUrl.isEmpty) return null;

  final uri = Uri.tryParse(serverUrl);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;

  final connectionScheme = uri.scheme;
  final connectionHost = uri.host;
  final connectionPort = uri.hasPort ? uri.port : connectionScheme == 'https' ? 443 : 80;

  try {
    final client = ref.read(apiClientProvider);
    final setting = await client.getSetting(false);
    final settingHostname = (setting.hostname ?? '').trim();
    final settingPublicPort = setting.publicPort ?? (connectionScheme == 'https' ? 443 : 80);
    // 比较时去掉服务端 hostname 可能带的前缀协议
    final settingHostNormalized = settingHostname.replaceFirst(RegExp(r'^https?://'), '').trim();

    final hostMatch = connectionHost == settingHostNormalized;
    final portMatch = connectionPort == settingPublicPort;
    if (hostMatch && portMatch) return null;

    return HostPortMismatch(
      connectionScheme: connectionScheme,
      connectionHost: connectionHost,
      connectionPort: connectionPort,
      settingHostname: settingHostname.isEmpty ? '(未配置)' : settingHostname,
      settingPublicPort: settingPublicPort,
    );
  } catch (e) {
    _logger.w('检查 hostname/public_port 一致性失败: $e');
    return null;
  }
}

/// 验证认证状态（通过调用 /getversion 接口）
/// 返回 AuthResult 表示认证状态
///
/// [skipStateUpdate] 如果为 true，检测到 401 时不会更新 authStateProvider
/// 用于登录页等场景，避免重复跳转，只返回错误信息供 UI 显示
Future<AuthResult> verifyAuth(WidgetRef ref, {bool skipStateUpdate = false}) async {
  final config = ref.read(apiConfigProvider);

  // 如果没有配置服务器地址，直接返回错误
  if (config.serverUrl.isEmpty) {
    return AuthResult.notAuthenticated('未配置服务器地址');
  }

  try {
    final apiClient = ref.read(apiClientProvider);
    final versionResp = await apiClient.getVersion();

    // 成功返回版本信息，表示认证成功
    // 注意：这里不自动更新 authStateProvider，由调用方决定何时更新
    // 因为 verifyAuth 可能用于登录验证，此时应该由登录逻辑控制状态更新
    return AuthResult.authenticated(versionResp.version);
  } on DioException catch (e) {
    _logger.e("验证认证失败: $e");
    // 检查是否是认证失败
    if (e.response?.statusCode == 401) {
      // 只有在非登录页场景才更新认证状态，触发 router 的 redirect 逻辑
      // 登录页场景由 UI 自己处理错误显示，不需要跳转
      if (!skipStateUpdate) {
        ref.read(authStateProvider.notifier).setUnauthorized();
      }

      // 检查响应内容是否包含 "Not authenticated"
      final responseData = e.response?.data;
      if (responseData is Map && responseData['detail'] == 'Not authenticated') {
        return AuthResult.notAuthenticated('认证失败：账号或密码错误');
      }
      return AuthResult.notAuthenticated('认证失败');
    }

    // 其他错误
    String msg = e.message ?? '网络错误';
    if (msg.contains("The connection errored") || msg.contains("Connection failed")) {
      msg = "无法连接到服务器，请检查网络设置或服务器地址";
    }
    return AuthResult.error(msg);
  } catch (e) {
    _logger.e("验证认证失败: $e");
    return AuthResult.error(e.toString());
  }
}
