import 'package:flutter/material.dart';

import '../theme/brand.dart';

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
        color: spec.fill,
        shape: BoxShape.circle,
        border: Border.all(color: spec.ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: spec.ring.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: selected
          ? Icon(Icons.check, size: size * 0.55, color: spec.ring)
          : null,
    );
  }
}
