import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

/// Mirrors `frontend/src/lib/firebase.ts`'s `signInWithGoogle` — same two
/// steps (Google identity, then hand it to Firebase Auth for a verifiable ID
/// token) via native platform packages instead of `signInWithPopup`. The
/// backend's `/auth/google` verifies a *Firebase* ID token (audience =
/// Firebase project ID), not the raw Google one `google_sign_in` returns on
/// its own, so the Firebase Auth exchange step is required, not optional.
class GoogleSignInService {
  GoogleSignInService._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: AppConfig.googleServerClientId);
    _initialized = true;
  }

  /// Returns a verified Firebase ID token, or null if the user cancelled the
  /// native account picker (not an error — same as the web's
  /// "popup-closed-by-user").
  static Future<String?> signInAndGetFirebaseIdToken() async {
    await ensureInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final googleIdToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseIdToken = await userCredential.user?.getIdToken();
    // Signing out of the local Firebase session immediately: our backend's
    // refresh cookie is the real session, exactly like on web (see
    // firebase.ts) — there's no reason to also keep a live Firebase Auth
    // session sitting around client-side.
    await FirebaseAuth.instance.signOut();
    return firebaseIdToken;
  }
}
