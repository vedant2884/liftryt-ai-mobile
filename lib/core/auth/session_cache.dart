import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/models.dart';
import '../storage/providers.dart';

const _cachedUserKey = 'liftryt.cached_user';

/// A locally-cached copy of the last-known signed-in user's profile — read
/// synchronously at app launch so [AuthController] can render Dashboard (or
/// Login, if there's no cached user) on the very first frame instead of a
/// blank "Loading..." screen while the real `/auth/refresh` round trip is
/// still in flight.
///
/// Display cache only, never a security boundary: the actual access token
/// is still never persisted (see `AuthController`'s doc comment). The
/// background refresh that follows is what silently confirms this
/// optimistic guess or, if the session genuinely expired server-side,
/// corrects it.
class SessionCache {
  final SharedPreferences _prefs;

  SessionCache(this._prefs);

  UserProfile? load() {
    final raw = _prefs.getString(_cachedUserKey);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Shape changed since this was cached, or corrupted — treat as "no
      // cached session" rather than crash the app on launch.
      return null;
    }
  }

  Future<void> save(UserProfile user) => _prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));

  Future<void> clear() => _prefs.remove(_cachedUserKey);
}

final sessionCacheProvider = Provider<SessionCache>((ref) => SessionCache(ref.watch(sharedPreferencesProvider)));
