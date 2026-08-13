import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Renders the coach's tool output as a deterministic, always-visible
/// structured card rather than trusting the model to transcribe the same
/// numbers correctly in prose. Mirrors
/// `frontend/src/components/ToolResultCard.tsx`'s two known tool shapes
/// (split generation, macro calculation); unrecognized/error payloads
/// render nothing, same as web.
class ToolResultCard extends StatelessWidget {
  final String? toolName;
  final Map<String, dynamic> payload;

  const ToolResultCard({super.key, required this.toolName, required this.payload});

  @override
  Widget build(BuildContext context) {
    final result = payload['result'] as Map<String, dynamic>?;
    if (result == null || result.containsKey('error')) return const SizedBox.shrink();

    if (toolName == 'generate_workout_split' && result.containsKey('days')) {
      return _splitCard(context, result);
    }
    if (toolName == 'calculate_macros' && result.containsKey('target_calories')) {
      return _macroCard(context, result);
    }
    return const SizedBox.shrink();
  }

  Widget _splitCard(BuildContext context, Map<String, dynamic> result) {
    final days = result['days'] as List<dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((result['split_type'] as String? ?? '').toUpperCase(),
              style: TextStyle(color: context.colors.inkMuted, fontSize: 10, letterSpacing: 0.5)),
          for (final d in days) ...[
            const SizedBox(height: 8),
            Text('Day ${d['day_number']}: ${d['label']}',
                style: TextStyle(color: context.colors.ink, fontSize: 12, fontWeight: FontWeight.w600)),
            for (final ex in (d['exercises'] as List<dynamic>))
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• ${ex['name']} · ${ex['sets']}×${ex['reps']}',
                    style: TextStyle(color: context.colors.inkSecondary, fontSize: 11)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _macroCard(BuildContext context, Map<String, dynamic> result) {
    final entries = {
      'BMR': result['bmr'],
      'TDEE': result['tdee'],
      'Calories': result['target_calories'],
      'Protein': '${result['target_protein_g']}g',
      'Carbs': '${result['target_carbs_g']}g',
      'Fat': '${result['target_fat_g']}g',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.lineStrong),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 4,
        children: [
          for (final e in entries.entries)
            Text('${e.key}: ${e.value}', style: TextStyle(color: context.colors.inkSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
