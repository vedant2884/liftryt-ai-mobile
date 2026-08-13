import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/google_sign_in_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../state/auth_controller.dart';

/// Mirrors `frontend/src/components/GoogleSignInButton.tsx` — same
/// "Continue with Google" affordance and the same `/auth/google` round trip,
/// just via the native account picker instead of a popup. A normal sign-in
/// resolves through [AuthController]'s state (the rest of the app reacts to
/// that as usual); a brand-new identity is handed to [onNeedsProfile] so the
/// caller can push the profile-completion screen.
class GoogleSignInButton extends ConsumerStatefulWidget {
  final void Function(GoogleAuthResult result) onNeedsProfile;

  const GoogleSignInButton({super.key, required this.onNeedsProfile});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;

  Future<void> _handlePress() async {
    setState(() => _loading = true);
    try {
      final idToken = await GoogleSignInService.signInAndGetFirebaseIdToken();
      if (idToken == null) return; // user cancelled the account picker
      final result = await ref.read(authControllerProvider.notifier).googleAuth(idToken);
      if (result.needsProfile) widget.onNeedsProfile(result);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in failed')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _handlePress,
        icon: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Image.asset('assets/branding/google_g.png', width: 18, height: 18),
        label: Text(_loading ? 'Connecting...' : 'Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.ink,
          side: BorderSide(color: context.colors.lineStrong),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
