import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_session.dart';
import '../../../core/api/providers.dart';
import '../../../core/auth/session_cache.dart';
import '../data/auth_api.dart';
import '../data/models.dart';

class AuthState {
  final UserProfile? user;

  const AuthState({this.user});

  bool get isAuthenticated => user != null;
}

/// App-wide auth state — mirrors `frontend/src/store/authStore.ts` plus the
/// silent-refresh-on-launch bootstrap from `frontend/src/App.tsx`, with one
/// deliberate difference: the initial state is never "unknown, please
/// wait" — [build] resolves synchronously to a [SessionCache]-backed guess
/// (Dashboard for a previously-signed-in user, Login otherwise) so the app
/// never shows a blank loading screen on launch. [_bootstrap] then
/// reconciles that guess against the server in the background: the access
/// token itself is never persisted to disk (kept only in [authSession], in
/// memory), so this is purely a *display* optimization — real API calls
/// still require the background refresh (or the 401 interceptor's own
/// refresh, deduped against the same in-flight call — see
/// `core/api/api_client.dart`) to actually succeed before they're
/// authenticated.
class AuthController extends Notifier<AuthState> {
  late final AuthApi _authApi;
  late final SessionCache _sessionCache;

  @override
  AuthState build() {
    _authApi = ref.read(authApiProvider);
    _sessionCache = ref.read(sessionCacheProvider);

    // The API client's 401-retry interceptor also refreshes the token
    // outside of any explicit call the UI makes — these hooks keep this
    // provider's state (and the local display cache) in sync with whatever
    // the interceptor, or this provider's own bootstrap below, just did.
    authSession.onTokenRefreshed = (accessToken, userJson) {
      final user = UserProfile.fromJson(userJson);
      _sessionCache.save(user);
      state = AuthState(user: user);
    };
    authSession.onSessionExpired = () {
      _sessionCache.clear();
      state = const AuthState(user: null);
    };

    _bootstrap();
    return AuthState(user: _sessionCache.load());
  }

  /// Goes through the same deduped [refreshAccessToken] the 401 interceptor
  /// uses (not a second independent call) — otherwise this and an early
  /// screen's own first API call could both race a rotating refresh token,
  /// and whichever loses would fail spuriously. A timeout/connection error
  /// here (e.g. a cold Render free-tier instance taking 30-60s+ to spin
  /// back up) intentionally does nothing — see `_doRefresh` — so the
  /// optimistic state from [build] just stands until a later request
  /// (retried naturally by the interceptor, or the user's next app launch)
  /// gets through.
  Future<void> _bootstrap() async {
    await refreshAccessToken(ref.read(dioProvider));
  }

  Future<void> signup(SignupPayload payload) async {
    final result = await _authApi.signup(payload);
    authSession.accessToken = result.accessToken;
    await _sessionCache.save(result.user);
    state = AuthState(user: result.user);
  }

  Future<void> login({required String email, required String password, bool rememberMe = true}) async {
    final result = await _authApi.login(email: email, password: password, rememberMe: rememberMe);
    authSession.accessToken = result.accessToken;
    await _sessionCache.save(result.user);
    state = AuthState(user: result.user);
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
      await _sessionCache.save(result.user!);
      state = AuthState(user: result.user);
    }
    return result;
  }

  Future<void> completeGoogleProfile(GoogleCompleteProfilePayload payload) async {
    final result = await _authApi.googleCompleteProfile(payload);
    authSession.accessToken = result.accessToken;
    await _sessionCache.save(result.user);
    state = AuthState(user: result.user);
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
    await _sessionCache.save(updated);
    state = AuthState(user: updated);
  }

  /// Applies a theme/accent change to local state immediately (before the
  /// PATCH /auth/me round trip resolves) so the UI responds the instant the
  /// user taps an option, exactly like the web app's `setTheme()` call
  /// preceding its own `persist()` fire-and-forget. Not cached here — the
  /// `updateProfile` call this always precedes/follows does that once the
  /// server confirms it.
  void applyThemePreview({AppThemeMode? theme, AccentColor? accentColor}) {
    final user = state.user;
    if (user == null) return;
    state = AuthState(user: user.copyWithAppearance(theme: theme, accentColor: accentColor));
  }

  Future<void> logout() async {
    await _authApi.logout();
    authSession.accessToken = null;
    await _sessionCache.clear();
    state = const AuthState(user: null);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
