import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Flutter equivalent of the web app's `DumbbellSpinner.tsx` — same
/// dumbbell shape (a bar with two plates per side), same continuous 360°
/// rotation at the same 900ms linear pace, so the "Coach is thinking"
/// moment reads identically on both platforms instead of a generic
/// CircularProgressIndicator that has nothing to do with LiftRyt.
class DumbbellSpinner extends StatefulWidget {
  const DumbbellSpinner({super.key, this.size = 20, this.label, this.color, this.labelColor});

  final double size;
  final String? label;
  /// Defaults to the current Theme's primary color if omitted — pass
  /// `context.colors.accent` explicitly to guarantee it tracks this app's
  /// purple/emerald accent choice rather than relying on that also being
  /// wired into Theme.of(context).colorScheme.primary.
  final Color? color;
  final Color? labelColor;

  @override
  State<DumbbellSpinner> createState() => _DumbbellSpinnerState();
}

class _DumbbellSpinnerState extends State<DumbbellSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _controller,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(painter: _DumbbellPainter(color: color)),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.label!,
            style: TextStyle(
              color: widget.labelColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Draws the exact same geometry as the web SVG (24x24 viewBox: a
/// horizontal bar plus two nested rounded plates on each side), scaled to
/// whatever size this is painted at.
class _DumbbellPainter extends CustomPainter {
  _DumbbellPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final barPaint = Paint()
      ..color = color
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    final platePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;

    // bar
    canvas.drawLine(Offset(7 * scale, 12 * scale), Offset(17 * scale, 12 * scale), barPaint);

    // left plates
    _drawPlate(canvas, platePaint, const Rect.fromLTWH(1, 8, 3, 8), scale);
    _drawPlate(canvas, platePaint, const Rect.fromLTWH(4.5, 6, 2.5, 12), scale);

    // right plates
    _drawPlate(canvas, platePaint, const Rect.fromLTWH(20, 8, 3, 8), scale);
    _drawPlate(canvas, platePaint, const Rect.fromLTWH(17, 6, 2.5, 12), scale);
  }

  void _drawPlate(Canvas canvas, Paint paint, Rect rect, double scale) {
    final scaled = Rect.fromLTWH(rect.left * scale, rect.top * scale, rect.width * scale, rect.height * scale);
    canvas.drawRRect(RRect.fromRectAndRadius(scaled, Radius.circular(math.min(1 * scale, scaled.shortestSide / 2))), paint);
  }

  @override
  bool shouldRepaint(covariant _DumbbellPainter oldDelegate) => oldDelegate.color != color;
}
