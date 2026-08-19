import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/age.dart';

/// Date-of-birth entry: tapping opens the native date picker (opened
/// straight to year-grid mode for fast year selection, inspired by but not
/// a copy of the iPhone date picker) — no new date-picker dependency needed,
/// [showDatePicker] already does both manual month/day taps and a year
/// grid. Reports the picked [DateTime] up via [onChanged]; the caller owns
/// the actual state so this stays a dumb, reusable field.
class DateOfBirthField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  const DateOfBirthField({super.key, required this.value, required this.onChanged, this.errorText});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      // A 120-year lower bound is basic sanity, not an arbitrary minimum
      // age — the backend enforces the real floor (13) and returns a
      // validation error the form surfaces if it's violated.
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: now,
      initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth',
          errorText: errorText,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null ? _format(value!) : 'Select date',
              style: TextStyle(
                color: value != null ? context.colors.ink : context.colors.inkMuted,
                fontSize: 14,
              ),
            ),
            if (value != null)
              Text(
                'Age ${calculateAge(value!)}',
                style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  String _format(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
