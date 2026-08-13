import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The app-launch branding moment — plays once per cold start, never on
/// in-app navigation (see [AuthGate] in `app.dart`, the only place this is
/// mounted). Runs for a fixed [_duration] regardless of how fast Firebase/
/// auth bootstrapping finishes underneath it, so the reveal never gets cut
/// short on a fast device — [onFinished] fires when the animation ends.
///
/// Deliberately built on nothing but [AnimationController] + [Interval]:
/// a glow fade-in, an icon scale/fade settle, then the wordmark. No
/// animation package earns its keep for something this short and simple.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1100);

  late final AnimationController _controller;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);

    _glowOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.65, curve: Curves.easeOut));
    _iconOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4, curve: Curves.easeOut));
    _iconScale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.55, curve: Curves.easeOutCubic)),
    );
    _wordmarkOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.85, curve: Curves.easeOut));
    _wordmarkOffset = Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );

    _controller.forward().whenComplete(widget.onFinished);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _glowOpacity.value,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [context.colors.accent.withValues(alpha: 0.35), context.colors.accent.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _iconOpacity.value,
                      child: Transform.scale(
                        scale: _iconScale.value,
                        child: Image.asset('assets/branding/liftryt_glyph.png', width: 96, height: 96),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: _wordmarkOpacity.value,
                      child: Transform.translate(
                        offset: _wordmarkOffset.value * 20,
                        child: Text(
                          'LiftRyt',
                          style: TextStyle(
                            color: context.colors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
