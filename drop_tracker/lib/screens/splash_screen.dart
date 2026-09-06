import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/auth_widgets.dart';

/// Independent branded splash shown on cold start while the app boots.
/// Not part of onboarding — it precedes the whole gated flow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: BrandColors.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              // Real lockup scales + fades in.
              AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final t = Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0));
                  final fade = Curves.easeOut.transform(_c.value.clamp(0.0, 1.0));
                  return Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * t,
                      child: const AppLogo(width: 240),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _FadeUp(
                controller: _c,
                delay: 0.42,
                child: Text('by Eye Drop Shop',
                    style: AppTypography.body(14.5, weight: FontWeight.w500, color: BrandColors.inkSoft)),
              ),
              const Spacer(flex: 6),
              _FadeUp(
                controller: _c,
                delay: 0.5,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: BrandColors.primary),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeUp extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;
  const _FadeUp({required this.controller, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, ch) {
        final v = ((controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final e = Curves.easeOut.transform(v);
        return Opacity(opacity: e, child: Transform.translate(offset: Offset(0, 12 * (1 - e)), child: ch));
      },
      child: child,
    );
  }
}
