import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

/// Shared teardrop geometry used across the app (logo, watermarks, empty states).
Path buildDropPath(Size s) {
  final w = s.width, h = s.height;
  final cx = w / 2;
  final r = w / 2; // bottom circle radius
  final cy = h - r; // centre of the bottom circle
  final p = Path()..moveTo(cx, 0); // top tip
  // right shoulder easing into the circle
  p.cubicTo(cx + r * 0.55, h * 0.16, w, cy - r * 0.55, cx + r, cy);
  // sweep the rounded bottom
  p.arcToPoint(Offset(cx - r, cy), radius: Radius.circular(r), clockwise: true);
  // left shoulder back up to the tip
  p.cubicTo(0, cy - r * 0.55, cx - r * 0.55, h * 0.16, cx, 0);
  p.close();
  return p;
}

class _DropPainter extends CustomPainter {
  final Color color;
  final bool filled;
  final double strokeWidth;
  _DropPainter(this.color, this.filled, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildDropPath(size);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (filled) {
      paint.style = PaintingStyle.fill;
    } else {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.color != color || old.filled != filled || old.strokeWidth != strokeWidth;
}

/// A single drop mark (fill or outline).
class DropMark extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;
  final double strokeWidth;
  const DropMark({
    super.key,
    this.size = 24,
    this.color = BrandColors.sunshine,
    this.filled = false,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * 0.72, size),
        painter: _DropPainter(color, filled, strokeWidth),
      );
}

/// The badge logo: a circle outline with a drop centred inside — the primary
/// Eye Drop Shop mark.
class DropBadge extends StatelessWidget {
  final double size;
  final Color ringColor;
  final Color dropColor;
  final Color? background;
  const DropBadge({
    super.key,
    this.size = 56,
    this.ringColor = BrandColors.ocean,
    this.dropColor = BrandColors.sunshine,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: size * 0.045),
      ),
      alignment: Alignment.center,
      child: DropMark(
        size: size * 0.46,
        color: dropColor,
        strokeWidth: size * 0.04,
      ),
    );
  }
}

/// The real brand icon (navy ring + gold drop-check, assets/images/app_icon.png)
/// — the same source used to generate the native app icon — clipped to a
/// circle. Use this in place of [DropBadge] wherever the app shows its own
/// icon as a standalone mark (splash, headers, onboarding), rather than the
/// hand-drawn placeholder.
class AppIconMark extends StatelessWidget {
  final double size;
  const AppIconMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Full horizontal lockup: badge + "Eye Drop Shop" wordmark in the serif face.
class DropWordmark extends StatelessWidget {
  final double height;
  final Color textColor;
  final Color ringColor;
  final Color dropColor;
  const DropWordmark({
    super.key,
    this.height = 40,
    this.textColor = BrandColors.ocean,
    this.ringColor = BrandColors.ocean,
    this.dropColor = BrandColors.sunshine,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropBadge(size: height, ringColor: ringColor, dropColor: dropColor),
        SizedBox(width: height * 0.32),
        Text(
          'Eye Drop Shop',
          style: GoogleFonts.fraunces(
            fontSize: height * 0.62,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
