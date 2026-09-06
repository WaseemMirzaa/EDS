import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'drop_logo.dart';

/// Immersive deep-ocean background with a large, faint drop watermark —
/// the "drop as a background texture" recommendation from the guidelines.
class BrandBackground extends StatelessWidget {
  final Widget child;
  const BrandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: BrandColors.deepGradient),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: 40,
            child: Opacity(
              opacity: 0.06,
              child: DropMark(size: 340, color: Colors.white, filled: true),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -40,
            child: Opacity(
              opacity: 0.05,
              child: DropMark(size: 240, color: Colors.white, filled: true),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
