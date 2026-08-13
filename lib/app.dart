import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_prefs.dart';
import 'features/auth/data/models.dart';
import 'features/auth/presentation/auth_flow.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/navigation/presentation/main_shell.dart';
import 'features/splash/presentation/splash_screen.dart';

extension _FlutterThemeMode on AppThemeMode {
  ThemeMode get flutter => switch (this) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}

class LiftRytApp extends ConsumerWidget {
  const LiftRytApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The authenticated user's saved preference wins once it's known (mirrors
    // web's App.tsx overwriting the theme store from the server on login);
    // before that (splash/login/signup), fall back to whatever was last
    // cached locally, so returning users don't flash back to the default.
    final user = ref.watch(authControllerProvider).user;
    final prefs = ref.watch(themePrefsProvider);
    final themeMode = user?.theme ?? prefs.themeMode;
    final accentColor = user?.accentColor ?? prefs.accentColor;
    final emeraldAccent = accentColor == AccentColor.emerald;

    return MaterialApp(
      title: 'LiftRyt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(brightness: Brightness.light, emeraldAccent: emeraldAccent),
      darkTheme: AppTheme.build(brightness: Brightness.dark, emeraldAccent: emeraldAccent),
      themeMode: themeMode.flutter,
      home: const AuthGate(),
    );
  }
}

/// Three states: the once-per-launch splash reveal, then straight to
/// unauthenticated or authenticated — no separate "loading" state in
/// between. [AuthController] resolves synchronously from a local cache of
/// the last-known session (see its doc comment), so by the time the splash
/// finishes there's already a best-guess answer to render; a background
/// refresh silently confirms or corrects it from there. [_splashDone] is
/// local widget state, not tied to auth — it flips once, on the
/// fixed-duration [SplashScreen] finishing, and this widget is only ever
/// mounted once at the app root, so the splash never replays on ordinary
/// in-app navigation.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onFinished: () => setState(() => _splashDone = true));
    }

    final auth = ref.watch(authControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: auth.isAuthenticated ? const MainShell(key: ValueKey('main')) : const AuthFlow(key: ValueKey('auth')),
    );
  }
}
