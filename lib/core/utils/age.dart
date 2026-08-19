/// Mirrors `backend/app/services/age_calculation.py`'s calculate_age exactly
/// (same "has the birthday happened yet this year" comparison, not a naive
/// currentYear - birthYear) — used only for the live age preview next to a
/// date-of-birth picker. The backend is still the actual source of truth;
/// this is never sent anywhere, just displayed.
int calculateAge(DateTime dateOfBirth, [DateTime? asOf]) {
  final now = asOf ?? DateTime.now();
  var age = now.year - dateOfBirth.year;
  final hadBirthdayThisYear =
      now.month > dateOfBirth.month || (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
  if (!hadBirthdayThisYear) age -= 1;
  return age;
}

/// "YYYY-MM-DD", the wire format the backend's date_of_birth field expects.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
