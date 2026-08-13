import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import 'auth_session.dart';

/// Endpoints where a 401 means "this credential itself is invalid," not
/// "the access token expired" — retrying with a refreshed token would be
/// meaningless (or, for /auth/refresh, would recurse). Mirrors
/// `frontend/src/lib/api.ts`'s NO_REFRESH_RETRY exactly.
final _noRefreshRetry = RegExp(r'/auth/(login|signup|refresh)$');

/// Builds the app's single Dio instance. Async because the persisted cookie
/// jar (needed so the httpOnly-equivalent refresh cookie survives an app
/// restart, matching the browser's own cookie jar) needs a filesystem
/// directory that's only available after the Flutter engine is ready.
Future<Dio> createApiClient() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final docsDir = await getApplicationDocumentsDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${docsDir.path}${Platform.pathSeparator}.cookies'),
  );
  dio.interceptors.add(CookieManager(cookieJar));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = authSession.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final requestPath = error.requestOptions.path;
        final alreadyRetried = error.requestOptions.extra['retried'] == true;

        if (error.response?.statusCode == 401 &&
            !alreadyRetried &&
            !_noRefreshRetry.hasMatch(requestPath)) {
          final newToken = await refreshAccessToken(dio);
          if (newToken != null) {
            final retryOptions = error.requestOptions
              ..headers['Authorization'] = 'Bearer $newToken'
              ..extra['retried'] = true;
            try {
              final response = await dio.fetch(retryOptions);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}

/// Concurrent refresh attempts (several requests firing right as the access
/// token expires, or the app-launch bootstrap racing an early screen's own
/// first API call) must share one refresh call rather than each racing
/// their own — otherwise every refresh after the first would replay an
/// already-rotated, now-revoked cookie and fail. Same reasoning as the web
/// client's `refreshInFlight` promise. Exported (not just used by the 401
/// interceptor above) so `AuthController`'s launch-time bootstrap goes
/// through this exact same dedup instead of firing a second, independent
/// `/auth/refresh` call.
Future<String?>? _refreshInFlight;

Future<String?> refreshAccessToken(Dio dio) {
  return _refreshInFlight ??= _doRefresh(dio).whenComplete(() {
    _refreshInFlight = null;
  });
}

Future<String?> _doRefresh(Dio dio) async {
  try {
    final response = await dio.post<Map<String, dynamic>>('/auth/refresh');
    final data = response.data!;
    final accessToken = data['access_token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    authSession.accessToken = accessToken;
    authSession.onTokenRefreshed?.call(accessToken, user);
    return accessToken;
  } on DioException catch (e) {
    // Only a genuine 401 here means the refresh cookie itself is invalid or
    // expired — that's a real "you're logged out". A timeout/connection
    // error (e.g. a cold Render free-tier instance taking 30-60s+ to spin
    // back up) is not that, and must not wipe an otherwise-still-valid
    // session just because this one request couldn't complete in time.
    if (e.response?.statusCode == 401) {
      authSession.accessToken = null;
      authSession.onSessionExpired?.call();
    }
    return null;
  }
}
