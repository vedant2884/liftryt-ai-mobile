import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/providers.dart';
import 'core/auth/google_sign_in_service.dart';
import 'core/storage/providers.dart';

/// `runZonedGuarded` + `FlutterError.onError` together are the app's whole
/// crash boundary: with neither set, an uncaught exception anywhere in an
/// async chain (a JSON parse against a response shape the app didn't
/// expect, for instance) has nothing to catch it and takes the whole app
/// down instead of surfacing as a log line. This project has no crash
/// reporting service wired up, so for now these just print — enough to see
/// a fatal error during development/adb logcat without pulling in a new
/// dependency for it. Never print request/response bodies or tokens here.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      // Built once up front (needs a filesystem directory for the persisted
      // cookie jar — see api_client.dart) and handed to every provider that
      // makes network calls via dioProvider's override below.
      final dio = await createApiClient();
      final prefs = await SharedPreferences.getInstance();

      // Only "Continue with Google" depends on this — a failure here (no
      // Google Play Services on this device, a transient Play Services
      // hiccup, etc.) must never block email/password auth and the rest of
      // the app from launching. GoogleSignInButton already has its own
      // catch-all around the actual sign-in call for when this didn't
      // succeed.
      try {
        // Reads android/app/google-services.json via the Google Services
        // Gradle plugin — no FlutterFire-generated options needed on Android.
        await Firebase.initializeApp();
        await GoogleSignInService.ensureInitialized();
      } catch (e) {
        debugPrint('Firebase/Google Sign-In init failed (Google sign-in will be unavailable): $e');
      }

      runApp(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const LiftRytApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
    },
  );
}
