import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small purple->emerald gradient pill, mirrors the web app's `<Badge
/// variant="beta">` next to "Gym AI Coach" — a solid gradient fill rather
/// than web's gradient-ring border (Flutter has no cheap equivalent of the
/// CSS double-background border trick, and a filled pill reads just as
/// clearly at this size).
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: context.colors.brandGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'BETA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
