import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_flow.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/navigation/presentation/main_shell.dart';
import 'features/splash/presentation/splash_screen.dart';

class LiftRytApp extends StatelessWidget {
  const LiftRytApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiftRyt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

/// Four states: the once-per-launch splash reveal, then exactly the same
/// bootstrapping -> unauthenticated -> authenticated flow that mirrors
/// `frontend/src/components/ProtectedRoute.tsx`. [_splashDone] is local
/// widget state, not tied to auth — it flips once, on the fixed-duration
/// [SplashScreen] finishing, and this widget is only ever mounted once at
/// the app root, so the splash never replays on ordinary in-app navigation.
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

    if (auth.isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: Text('Loading...', style: TextStyle(color: AppColors.inkSecondary)),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: auth.isAuthenticated ? const MainShell(key: ValueKey('main')) : const AuthFlow(key: ValueKey('auth')),
    );
  }
}
