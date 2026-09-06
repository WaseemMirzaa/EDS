import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'drop_logo.dart';

/// A bottle-cap colour swatch, mirroring the real medication's cap.
class CapColorDot extends StatelessWidget {
  final String colorKey;
  final double size;
  final bool selected;
  const CapColorDot({
    super.key,
    required this.colorKey,
    this.size = 28,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final spec = capSpec(colorKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Subtle top-left gloss for a tactile "cap" feel.
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.0,
          colors: [
            Color.lerp(spec.fill, Colors.white, 0.35)!,
            spec.fill,
          ],
        ),
        border: Border.all(color: spec.ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: spec.ring.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: size * 0.55, color: spec.ring)
          : null,
    );
  }
}

/// A soft round medication marker — a tinted circle holding a coloured drop.
/// Used as the hero/next-dose glyph.
class MedMarker extends StatelessWidget {
  final String colorKey;
  final double size;
  const MedMarker({super.key, required this.colorKey, this.size = 58});

  @override
  Widget build(BuildContext context) {
    final spec = capSpec(colorKey);
    final tint = Color.lerp(spec.fill, Colors.white, 0.15)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(tint, Colors.white, 0.35)!, tint],
        ),
        boxShadow: [
          BoxShadow(color: spec.ring.withValues(alpha: 0.30), blurRadius: 14, spreadRadius: -2, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: DropMark(size: size * 0.46, color: spec.ring, filled: true),
    );
  }
}

/// A layered "pill" medication indicator: a soft outer halo, a glossy inner
/// disc and a tiny highlight. Used on the Medications list.
class MedPill extends StatelessWidget {
  final String colorKey;
  final double size;
  const MedPill({super.key, required this.colorKey, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final spec = capSpec(colorKey);
    final inner = size * 0.66;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: spec.fill.withValues(alpha: 0.16),
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.45),
            colors: [Color.lerp(spec.fill, Colors.white, 0.42)!, spec.fill],
          ),
          border: Border.all(color: spec.ring, width: 2),
          boxShadow: [
            BoxShadow(color: spec.ring.withValues(alpha: 0.30), blurRadius: 8, spreadRadius: -1, offset: const Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

/// The small timeline dot that sits on the connector line.
class TimelineDot extends StatelessWidget {
  final String colorKey;
  final double size;
  const TimelineDot({super.key, required this.colorKey, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final spec = capSpec(colorKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: spec.fill,
        shape: BoxShape.circle,
        border: Border.all(color: spec.ring, width: 1.6),
        boxShadow: [
          BoxShadow(color: spec.ring.withValues(alpha: 0.35), blurRadius: 6, spreadRadius: -1),
        ],
      ),
    );
  }
}
