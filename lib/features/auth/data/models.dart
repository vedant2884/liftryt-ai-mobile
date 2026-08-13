// Enums and DTOs mirrored field-for-field from the backend's
// `app/schemas/user.py` / `app/schemas/auth.py` / `app/models/enums.py` —
// explicit `fromJson`/`toJson` string mappings rather than relying on Dart
// enum `.name` so the wire format (snake_case, e.g. "very_active") stays
// decoupled from Dart naming conventions (camelCase enum members).

enum Sex {
  male,
  female,
  other;

  static Sex fromJson(String value) => switch (value) {
        'male' => Sex.male,
        'female' => Sex.female,
        _ => Sex.other,
      };

  String toJson() => switch (this) {
        Sex.male => 'male',
        Sex.female => 'female',
        Sex.other => 'other',
      };
}

enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  static ActivityLevel fromJson(String value) => switch (value) {
        'sedentary' => ActivityLevel.sedentary,
        'light' => ActivityLevel.light,
        'active' => ActivityLevel.active,
        'very_active' => ActivityLevel.veryActive,
        _ => ActivityLevel.moderate,
      };

  String toJson() => switch (this) {
        ActivityLevel.sedentary => 'sedentary',
        ActivityLevel.light => 'light',
        ActivityLevel.moderate => 'moderate',
        ActivityLevel.active => 'active',
        ActivityLevel.veryActive => 'very_active',
      };
}

enum ExperienceLevel {
  beginner,
  intermediate,
  advanced;

  static ExperienceLevel fromJson(String value) => switch (value) {
        'intermediate' => ExperienceLevel.intermediate,
        'advanced' => ExperienceLevel.advanced,
        _ => ExperienceLevel.beginner,
      };

  String toJson() => switch (this) {
        ExperienceLevel.beginner => 'beginner',
        ExperienceLevel.intermediate => 'intermediate',
        ExperienceLevel.advanced => 'advanced',
      };
}

enum DietaryPreference {
  none,
  vegetarian,
  vegan,
  pescatarian,
  keto,
  other;

  static DietaryPreference fromJson(String value) => switch (value) {
        'vegetarian' => DietaryPreference.vegetarian,
        'vegan' => DietaryPreference.vegan,
        'pescatarian' => DietaryPreference.pescatarian,
        'keto' => DietaryPreference.keto,
        'other' => DietaryPreference.other,
        _ => DietaryPreference.none,
      };

  String toJson() => switch (this) {
        DietaryPreference.none => 'none',
        DietaryPreference.vegetarian => 'vegetarian',
        DietaryPreference.vegan => 'vegan',
        DietaryPreference.pescatarian => 'pescatarian',
        DietaryPreference.keto => 'keto',
        DietaryPreference.other => 'other',
      };
}

// Named AppThemeMode (not ThemeMode) so it doesn't collide with Flutter's
// own material.dart ThemeMode (light/dark/system) — app.dart needs both in
// scope at once to map one onto the other for MaterialApp.themeMode.
enum AppThemeMode {
  light,
  dark,
  system;

  static AppThemeMode fromJson(String value) => switch (value) {
        'light' => AppThemeMode.light,
        'system' => AppThemeMode.system,
        _ => AppThemeMode.dark,
      };

  String toJson() => switch (this) {
        AppThemeMode.light => 'light',
        AppThemeMode.system => 'system',
        AppThemeMode.dark => 'dark',
      };
}

enum AccentColor {
  violet,
  emerald;

  static AccentColor fromJson(String value) => value == 'emerald' ? AccentColor.emerald : AccentColor.violet;

  String toJson() => this == AccentColor.emerald ? 'emerald' : 'violet';
}

/// Mirrors `UserProfile` in `app/schemas/user.py` exactly.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final String? googleAvatarUrl;
  final bool hasPassword;
  final bool hasCompletedOnboarding;
  final int age;
  final Sex sex;
  final double heightCm;
  final double? goalWeightKg;
  final ActivityLevel activityLevel;
  final ExperienceLevel trainingExperience;
  final DietaryPreference dietaryPreference;
  final AppThemeMode theme;
  final AccentColor accentColor;
  final double defaultProgressionIncrementKg;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.username,
    this.avatarUrl,
    this.googleAvatarUrl,
    required this.hasPassword,
    required this.hasCompletedOnboarding,
    required this.age,
    required this.sex,
    required this.heightCm,
    this.goalWeightKg,
    required this.activityLevel,
    required this.trainingExperience,
    required this.dietaryPreference,
    required this.theme,
    required this.accentColor,
    required this.defaultProgressionIncrementKg,
  });

  /// Display avatar: a custom upload always wins over the Google picture,
  /// mirroring the web app's same priority (see `auth.py`'s upload_avatar).
  String? get displayAvatarUrl => avatarUrl ?? googleAvatarUrl;

  /// Narrow copyWith (just the appearance fields) for an optimistic local
  /// update the instant the user taps a theme/accent option, ahead of the
  /// PATCH /auth/me round trip actually confirming it server-side.
  UserProfile copyWithAppearance({AppThemeMode? theme, AccentColor? accentColor}) => UserProfile(
        id: id,
        email: email,
        fullName: fullName,
        username: username,
        avatarUrl: avatarUrl,
        googleAvatarUrl: googleAvatarUrl,
        hasPassword: hasPassword,
        hasCompletedOnboarding: hasCompletedOnboarding,
        age: age,
        sex: sex,
        heightCm: heightCm,
        goalWeightKg: goalWeightKg,
        activityLevel: activityLevel,
        trainingExperience: trainingExperience,
        dietaryPreference: dietaryPreference,
        theme: theme ?? this.theme,
        accentColor: accentColor ?? this.accentColor,
        defaultProgressionIncrementKg: defaultProgressionIncrementKg,
      );

  /// Inverse of [fromJson] — used only to persist a display copy of the
  /// profile locally (see `core/auth/session_cache.dart`), never sent back
  /// to the server as a request body.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'username': username,
        'avatar_url': avatarUrl,
        'google_avatar_url': googleAvatarUrl,
        'has_password': hasPassword,
        'has_completed_onboarding': hasCompletedOnboarding,
        'age': age,
        'sex': sex.toJson(),
        'height_cm': heightCm,
        'goal_weight_kg': goalWeightKg,
        'activity_level': activityLevel.toJson(),
        'training_experience': trainingExperience.toJson(),
        'dietary_preference': dietaryPreference.toJson(),
        'theme': theme.toJson(),
        'accent_color': accentColor.toJson(),
        'default_progression_increment_kg': defaultProgressionIncrementKg,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        googleAvatarUrl: json['google_avatar_url'] as String?,
        hasPassword: json['has_password'] as bool,
        hasCompletedOnboarding: json['has_completed_onboarding'] as bool,
        age: json['age'] as int,
        sex: Sex.fromJson(json['sex'] as String),
        heightCm: (json['height_cm'] as num).toDouble(),
        goalWeightKg: (json['goal_weight_kg'] as num?)?.toDouble(),
        activityLevel: ActivityLevel.fromJson(json['activity_level'] as String),
        trainingExperience: ExperienceLevel.fromJson(json['training_experience'] as String),
        dietaryPreference: DietaryPreference.fromJson(json['dietary_preference'] as String),
        theme: AppThemeMode.fromJson(json['theme'] as String),
        accentColor: AccentColor.fromJson(json['accent_color'] as String),
        defaultProgressionIncrementKg: (json['default_progression_increment_kg'] as num).toDouble(),
      );
}

class AuthResult {
  final String accessToken;
  final UserProfile user;

  const AuthResult({required this.accessToken, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['access_token'] as String,
        user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Mirrors `GoogleAuthResponse` in `app/schemas/auth.py` — either a normal
/// sign-in (`needsProfile: false`) or a brand-new Google identity that still
/// needs age/sex/height before an account exists.
class GoogleAuthResult {
  final bool needsProfile;
  final String? googleToken;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? accessToken;
  final UserProfile? user;

  const GoogleAuthResult({
    required this.needsProfile,
    this.googleToken,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.accessToken,
    this.user,
  });

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) => GoogleAuthResult(
        needsProfile: json['needs_profile'] as bool,
        googleToken: json['google_token'] as String?,
        email: json['email'] as String?,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        accessToken: json['access_token'] as String?,
        user: json['user'] == null ? null : UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Mirrors `GoogleCompleteProfileRequest` in `app/schemas/auth.py`.
class GoogleCompleteProfilePayload {
  final String googleToken;
  final String username;
  final int age;
  final Sex sex;
  final double heightCm;
  final double goalWeightKg;
  final double? startingWeightKg;
  final ActivityLevel activityLevel;
  final ExperienceLevel trainingExperience;
  final DietaryPreference dietaryPreference;

  const GoogleCompleteProfilePayload({
    required this.googleToken,
    required this.username,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.goalWeightKg,
    this.startingWeightKg,
    this.activityLevel = ActivityLevel.moderate,
    this.trainingExperience = ExperienceLevel.beginner,
    this.dietaryPreference = DietaryPreference.none,
  });

  Map<String, dynamic> toJson() => {
        'google_token': googleToken,
        'username': username,
        'age': age,
        'sex': sex.toJson(),
        'height_cm': heightCm,
        'goal_weight_kg': goalWeightKg,
        if (startingWeightKg != null) 'starting_weight_kg': startingWeightKg,
        'activity_level': activityLevel.toJson(),
        'training_experience': trainingExperience.toJson(),
        'dietary_preference': dietaryPreference.toJson(),
      };
}

/// Mirrors `SignupRequest` in `app/schemas/auth.py`.
class SignupPayload {
  final String email;
  final String password;
  final String fullName;
  final String username;
  final int age;
  final Sex sex;
  final double heightCm;
  final double goalWeightKg;
  final double? startingWeightKg;
  final ActivityLevel activityLevel;
  final ExperienceLevel trainingExperience;
  final DietaryPreference dietaryPreference;

  const SignupPayload({
    required this.email,
    required this.password,
    required this.fullName,
    required this.username,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.goalWeightKg,
    this.startingWeightKg,
    this.activityLevel = ActivityLevel.moderate,
    this.trainingExperience = ExperienceLevel.beginner,
    this.dietaryPreference = DietaryPreference.none,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'full_name': fullName,
        'username': username,
        'age': age,
        'sex': sex.toJson(),
        'height_cm': heightCm,
        'goal_weight_kg': goalWeightKg,
        if (startingWeightKg != null) 'starting_weight_kg': startingWeightKg,
        'activity_level': activityLevel.toJson(),
        'training_experience': trainingExperience.toJson(),
        'dietary_preference': dietaryPreference.toJson(),
      };
}
