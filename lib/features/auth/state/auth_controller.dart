import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_session.dart';
import '../../../core/api/providers.dart';
import '../data/auth_api.dart';
import '../data/models.dart';

class AuthState {
  final bool isBootstrapping;
  final UserProfile? user;

  const AuthState({this.isBootstrapping = true, this.user});

  bool get isAuthenticated => user != null;
}

/// App-wide auth state — mirrors `frontend/src/store/authStore.ts` plus the
/// silent-refresh-on-launch bootstrap from `frontend/src/App.tsx`:
/// the access token itself is never persisted to disk (kept only in
/// [authSession], in memory), session persistence instead comes from the
/// refresh cookie the Dio cookie jar already keeps on disk, exactly like the
/// browser's httpOnly cookie.
class AuthController extends Notifier<AuthState> {
  late final AuthApi _authApi;

  @override
  AuthState build() {
    _authApi = ref.read(authApiProvider);

    // The API client's 401-retry interceptor also refreshes the token
    // outside of any explicit call the UI makes — these hooks keep this
    // provider's state in sync with whatever the interceptor just did.
    authSession.onTokenRefreshed = (accessToken, userJson) {
      state = AuthState(isBootstrapping: false, user: UserProfile.fromJson(userJson));
    };
    authSession.onSessionExpired = () {
      state = const AuthState(isBootstrapping: false, user: null);
    };

    _bootstrap();
    return const AuthState(isBootstrapping: true, user: null);
  }

  /// A cold Render free-tier instance can take 30-60s+ to spin back up (no
  /// persistent disk on the free plan, so it re-downloads the embedding
  /// model on every cold start) — well past the app's normal 15s/30s
  /// request timeouts. Retrying with a much longer timeout here, and only
  /// ever treating a genuine 401 as "you're actually logged out", is what
  /// stops a slow cold start from looking identical to a lost session.
  static const _bootstrapTimeout = Duration(seconds: 45);
  static const _bootstrapAttempts = 2;

  Future<void> _bootstrap() async {
    for (var attempt = 1; attempt <= _bootstrapAttempts; attempt++) {
      try {
        final result = await _authApi.refresh(
          options: Options(sendTimeout: _bootstrapTimeout, receiveTimeout: _bootstrapTimeout),
        );
        authSession.accessToken = result.accessToken;
        state = AuthState(isBootstrapping: false, user: result.user);
        return;
      } on ApiException catch (e) {
        // No valid refresh cookie (never logged in, or it genuinely expired/
        // was revoked) — a normal, expected outcome, not an error. Stop
        // immediately rather than burning a retry on a result that won't
        // change.
        if (e.statusCode == 401) break;
      } catch (_) {
        // Any other failure (timeout, connection error, 5xx) — worth one
        // more attempt before giving up, since it's more likely a slow
        // cold start than an actual problem.
      }
    }
    state = const AuthState(isBootstrapping: false, user: null);
  }

  Future<void> signup(SignupPayload payload) async {
    final result = await _authApi.signup(payload);
    authSession.accessToken = result.accessToken;
    state = AuthState(isBootstrapping: false, user: result.user);
  }

  Future<void> login({required String email, required String password, bool rememberMe = true}) async {
    final result = await _authApi.login(email: email, password: password, rememberMe: rememberMe);
    authSession.accessToken = result.accessToken;
    state = AuthState(isBootstrapping: false, user: result.user);
  }

  /// Returns the dev-only reset link (see `ForgotPasswordResponse` on the
  /// backend) so the UI can surface it when no email provider is configured;
  /// always null in production.
  Future<String?> forgotPassword(String email) => _authApi.forgotPassword(email);

  /// Returns the raw result so the UI can navigate to profile completion
  /// when [GoogleAuthResult.needsProfile] is true — auth state is only
  /// updated here for the normal-sign-in case, since a brand-new identity
  /// isn't a logged-in user yet.
  Future<GoogleAuthResult> googleAuth(String idToken) async {
    final result = await _authApi.googleAuth(idToken);
    if (!result.needsProfile) {
      authSession.accessToken = result.accessToken;
      state = AuthState(isBootstrapping: false, user: result.user);
    }
    return result;
  }

  Future<void> completeGoogleProfile(GoogleCompleteProfilePayload payload) async {
    final result = await _authApi.googleCompleteProfile(payload);
    authSession.accessToken = result.accessToken;
    state = AuthState(isBootstrapping: false, user: result.user);
  }

  Future<void> updateProfile({
    double? defaultProgressionIncrementKg,
    AppThemeMode? theme,
    AccentColor? accentColor,
  }) async {
    final updated = await _authApi.updateProfile(
      defaultProgressionIncrementKg: defaultProgressionIncrementKg,
      theme: theme,
      accentColor: accentColor,
    );
    state = AuthState(isBootstrapping: false, user: updated);
  }

  /// Applies a theme/accent change to local state immediately (before the
  /// PATCH /auth/me round trip resolves) so the UI responds the instant the
  /// user taps an option, exactly like the web app's `setTheme()` call
  /// preceding its own `persist()` fire-and-forget.
  void applyThemePreview({AppThemeMode? theme, AccentColor? accentColor}) {
    final user = state.user;
    if (user == null) return;
    state = AuthState(isBootstrapping: false, user: user.copyWithAppearance(theme: theme, accentColor: accentColor));
  }

  Future<void> logout() async {
    await _authApi.logout();
    authSession.accessToken = null;
    state = const AuthState(isBootstrapping: false, user: null);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
