import 'package:flutter/widgets.dart';

import '../data/models.dart';
import 'forgot_password_screen.dart';
import 'google_complete_profile_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

enum _AuthScreen { login, signup, forgotPassword, googleCompleteProfile }

/// The unauthenticated part of the app — login/signup/forgot-password.
/// A plain local state switch rather than a router package: three screens
/// with no deep-linking needs don't justify the dependency yet. Real
/// in-app navigation (bottom nav, multi-tab authenticated area) lands with
/// a router in a later phase once there's enough surface to need one.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  _AuthScreen _screen = _AuthScreen.login;
  GoogleAuthResult? _pendingGoogleProfile;

  void _onGoogleNeedsProfile(GoogleAuthResult result) {
    setState(() {
      _pendingGoogleProfile = result;
      _screen = _AuthScreen.googleCompleteProfile;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_screen) {
      case _AuthScreen.login:
        return LoginScreen(
          onGoToSignup: () => setState(() => _screen = _AuthScreen.signup),
          onGoToForgotPassword: () => setState(() => _screen = _AuthScreen.forgotPassword),
          onGoogleNeedsProfile: _onGoogleNeedsProfile,
        );
      case _AuthScreen.signup:
        return SignupScreen(
          onGoToLogin: () => setState(() => _screen = _AuthScreen.login),
          onGoogleNeedsProfile: _onGoogleNeedsProfile,
        );
      case _AuthScreen.forgotPassword:
        return ForgotPasswordScreen(onBackToLogin: () => setState(() => _screen = _AuthScreen.login));
      case _AuthScreen.googleCompleteProfile:
        return GoogleCompleteProfileScreen(
          pending: _pendingGoogleProfile!,
          onCancel: () => setState(() => _screen = _AuthScreen.login),
        );
    }
  }
}
