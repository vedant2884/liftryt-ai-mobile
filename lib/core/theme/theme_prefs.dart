import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/models.dart';
import '../storage/providers.dart';

const _themeModeKey = 'liftryt.theme_mode';
const _accentColorKey = 'liftryt.accent_color';

/// Local, device-only cache of the last-known theme/accent choice — read
/// synchronously at first paint (before auth has resolved) so the login
/// screen isn't stuck on a default while the silent-refresh call is still in
/// flight, and so the choice survives logout. Once a [UserProfile] is
/// available, its `theme`/`accentColor` fields are the source of truth
/// (mirrors the web app's Zustand-persisted store, overwritten by the
/// server value once `/auth/refresh` resolves — see `app.dart`).
class ThemePrefs {
  final SharedPreferences _prefs;

  ThemePrefs(this._prefs);

  AppThemeMode get themeMode {
    final raw = _prefs.getString(_themeModeKey);
    return raw == null ? AppThemeMode.dark : AppThemeMode.fromJson(raw);
  }

  AccentColor get accentColor {
    final raw = _prefs.getString(_accentColorKey);
    return raw == null ? AccentColor.violet : AccentColor.fromJson(raw);
  }

  Future<void> save({AppThemeMode? themeMode, AccentColor? accentColor}) async {
    if (themeMode != null) await _prefs.setString(_themeModeKey, themeMode.toJson());
    if (accentColor != null) await _prefs.setString(_accentColorKey, accentColor.toJson());
  }
}

final themePrefsProvider = Provider<ThemePrefs>((ref) {
  return ThemePrefs(ref.watch(sharedPreferencesProvider));
});
