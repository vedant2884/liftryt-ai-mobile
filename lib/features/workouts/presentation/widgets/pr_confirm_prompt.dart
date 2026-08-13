import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shown inline right on the set that just PR'd — never a blocking modal,
/// and never applies anything on its own. A PR only ever offers to suggest
/// a next weight; the user has to explicitly confirm or dismiss it every
/// single time, per exercise. Mirrors
/// `frontend/src/components/workout/PrConfirmPrompt.tsx` — emerald/success,
/// not amber, since PRs are a "success" moment per the app's color system.
class PrConfirmPrompt extends StatelessWidget {
  final double prWeightKg;
  final double incrementKg;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const PrConfirmPrompt({
    super.key,
    required this.prWeightKg,
    required this.incrementKg,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final nextWeight = prWeightKg + incrementKg;

    // Plays once as the prompt mounts — a brief pop-in for the "success"
    // moment, mirroring the web app's motion.div scale+fade entrance.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Opacity(
        opacity: scale.clamp(0, 1),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: _content(context, nextWeight),
    );
  }

  Widget _content(BuildContext context, double nextWeight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: context.colors.success, size: 15),
              const SizedBox(width: 6),
              Text(
                'New PR! Increase next weight?',
                style: TextStyle(color: context.colors.success, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
              children: [
                TextSpan(text: '${_fmt(prWeightKg)} kg + ${_fmt(incrementKg)} kg → next suggested '),
                TextSpan(
                  text: '${_fmt(nextWeight)} kg',
                  style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.success,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('+${_fmt(incrementKg)} kg', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.inkSecondary,
                  side: BorderSide(color: context.colors.lineStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Not now', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
