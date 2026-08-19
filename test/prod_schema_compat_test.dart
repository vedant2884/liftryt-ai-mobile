// Regression test for the mobile APK crash: production (Render) has not
// been redeployed with the date_of_birth/workout_reminders_enabled/streak
// fields these models now know about. Parsing a response in that exact
// (older) shape must degrade gracefully with sane defaults, never throw.
import 'package:flutter_test/flutter_test.dart';
import 'package:liftryt/features/analysis/data/models.dart';
import 'package:liftryt/features/auth/data/models.dart';

void main() {
  test('UserProfile.fromJson tolerates a pre-migration backend response', () {
    final json = {
      'id': '11111111-1111-1111-1111-111111111111',
      'email': 'real.user@example.com',
      'full_name': 'Real User',
      'username': 'realuser',
      'avatar_url': null,
      'google_avatar_url': null,
      'has_password': true,
      'has_completed_onboarding': true,
      'age': 29,
      'sex': 'male',
      'height_cm': 178.0,
      'goal_weight_kg': 80.0,
      'activity_level': 'moderate',
      'training_experience': 'beginner',
      'dietary_preference': 'none',
      'unit_weight': 'kg',
      'unit_length': 'cm',
      'theme': 'dark',
      'accent_color': 'violet',
      'default_progression_increment_kg': 2.5,
      'created_at': '2026-01-01T00:00:00Z',
      // no date_of_birth, no workout_reminders_enabled — matches
      // https://liftryt-backend.onrender.com/openapi.json today.
    };

    final profile = UserProfile.fromJson(json);

    expect(profile.dateOfBirth, isNull);
    expect(profile.age, 29);
    expect(profile.workoutRemindersEnabled, isTrue);
  });

  test('WorkoutOverview.fromJson tolerates a pre-migration backend response', () {
    final json = {
      'total_workouts': 3,
      'workouts_this_week': 1,
      'workouts_this_month': 3,
      'total_volume_kg': 900.0,
      'total_sets': 12,
      'most_trained_muscle': 'chest',
      'most_trained_exercise_name': 'Bench Press',
      // no current_streak_days / longest_streak_days
    };

    final overview = WorkoutOverview.fromJson(json);

    expect(overview.currentStreakDays, 0);
    expect(overview.longestStreakDays, 0);
    expect(overview.totalWorkouts, 3);
  });
}
