import 'package:flutter/material.dart';

/// Color tokens mirrored 1:1 from the web app's `frontend/src/index.css`
/// (`--bg`, `--surface`, `--ink`, `--accent`, `--success`, ...), including
/// its Dark/Light/System theme and purple-vs-emerald accent choice. A real
/// [ThemeExtension] (not static consts) so the palette can actually swap at
/// runtime instead of being locked to one dark palette forever — read it via
/// `context.colors.xxx`, never by constructing [AppColors] directly.
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceHover;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;

  /// The user's chosen primary accent (violet or emerald) — used for
  /// primary actions, active states, focus rings.
  final Color accent;

  /// Text/icon color on top of [accent] — always white, both accent values
  /// are dark-saturated enough for it in both themes.
  final Color onAccent;

  /// Progress/success/PR token — independent of [accent] so it stays
  /// emerald even when the user's personal accent is violet (mirrors the
  /// web app's --success token).
  final Color success;

  /// Fixed brand pair for the purple->emerald signature (Coach branding),
  /// deliberately not tied to [accent] so it doesn't collapse to a single
  /// color when the user's accent happens to already be emerald.
  final Color brandPurple;
  final Color brandEmerald;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceHover,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.brandPurple,
    required this.brandEmerald,
  });

  static const _violet = Color(0xFF8B5CF6);
  static const _emerald = Color(0xFF10B981);

  factory AppColors.dark({required bool emeraldAccent}) => AppColors(
        bg: const Color(0xFF0A0A0A),
        surface: const Color(0xFF171717),
        surfaceHover: const Color(0xFF262626),
        line: const Color(0xFF262626),
        lineStrong: const Color(0xFF404040),
        ink: const Color(0xFFF5F5F5),
        inkSecondary: const Color(0xFFA3A3A3),
        inkMuted: const Color(0xFF737373),
        accent: emeraldAccent ? _emerald : _violet,
        onAccent: Colors.white,
        success: _emerald,
        brandPurple: _violet,
        brandEmerald: _emerald,
      );

  factory AppColors.light({required bool emeraldAccent}) => AppColors(
        bg: const Color(0xFFFAFAFA),
        surface: const Color(0xFFFFFFFF),
        surfaceHover: const Color(0xFFF5F5F5),
        line: const Color(0xFFE5E5E5),
        lineStrong: const Color(0xFFD4D4D4),
        ink: const Color(0xFF171717),
        inkSecondary: const Color(0xFF525252),
        inkMuted: const Color(0xFF737373),
        accent: emeraldAccent ? _emerald : _violet,
        onAccent: Colors.white,
        // emerald-600, not -500 — #10B981 fails AA contrast as text/icon
        // color on a white surface, #059669 passes (same reasoning as web).
        success: const Color(0xFF059669),
        brandPurple: _violet,
        brandEmerald: _emerald,
      );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHover,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? brandPurple,
    Color? brandEmerald,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      brandPurple: brandPurple ?? this.brandPurple,
      brandEmerald: brandEmerald ?? this.brandEmerald,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      brandPurple: Color.lerp(brandPurple, other.brandPurple, t)!,
      brandEmerald: Color.lerp(brandEmerald, other.brandEmerald, t)!,
    );
  }

  /// Purple->emerald signature gradient (Coach branding, badges, glows).
  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandPurple, brandEmerald],
      );
}

/// `context.colors.bg` instead of a static `AppColors.bg` — the palette now
/// depends on the active theme, so it must be looked up through the
/// BuildContext's [Theme] instead of being a compile-time constant.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  AppTheme._();

  static ThemeData build({required Brightness brightness, required bool emeraldAccent}) {
    final colors =
        brightness == Brightness.dark ? AppColors.dark(emeraldAccent: emeraldAccent) : AppColors.light(emeraldAccent: emeraldAccent);

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.bg,
      colorScheme: brightness == Brightness.dark
          ? ColorScheme.dark(
              surface: colors.bg,
              primary: colors.accent,
              onPrimary: colors.onAccent,
              secondary: colors.accent,
              error: const Color(0xFFEF4444),
            )
          : ColorScheme.light(
              surface: colors.bg,
              primary: colors.accent,
              onPrimary: colors.onAccent,
              secondary: colors.accent,
              error: const Color(0xFFEF4444),
            ),
      extensions: [colors],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: colors.ink,
        displayColor: colors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.accent),
        ),
        hintStyle: TextStyle(color: colors.inkMuted),
      ),
      dividerTheme: DividerThemeData(color: colors.line, space: 1),
    );
  }
}
