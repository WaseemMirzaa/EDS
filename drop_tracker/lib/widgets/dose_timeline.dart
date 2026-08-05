import 'package:flutter/material.dart';

import '../models/dose.dart';
import '../models/dose_event.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'motion.dart';

const double _kTimeCol = 54;
const double _kConnCol = 26;
const double _kDotY = 34;

/// One row of the Today timeline: a left time column, a vertical connector with
/// a coloured dot, and a card (or inline banner) to the right.
class TimelineRow extends StatelessWidget {
  final String? timeTop;
  final String? timeBottom;
  final String? dotColorKey; // null → no dot (used by inline banners)
  final bool extendTop;
  final bool extendBottom;
  final Widget child;
  const TimelineRow({
    super.key,
    this.timeTop,
    this.timeBottom,
    this.dotColorKey,
    this.extendTop = true,
    this.extendBottom = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kTimeCol,
            child: timeTop == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: _kDotY - 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timeTop!, style: AppTypography.body(15.5, weight: FontWeight.w700, color: BrandColors.ink)),
                        Text(timeBottom ?? '',
                            style: AppTypography.body(11.5, weight: FontWeight.w700, color: BrandColors.inkFaint, letterSpacing: 0.4)),
                      ],
                    ),
                  ),
          ),
          SizedBox(
            width: _kConnCol,
            child: CustomPaint(
              painter: _ConnectorPainter(
                dotSpec: dotColorKey == null ? null : capSpec(dotColorKey),
                extendTop: extendTop,
                extendBottom: extendBottom,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final CapColorSpec? dotSpec;
  final bool extendTop;
  final bool extendBottom;
  _ConnectorPainter({required this.dotSpec, required this.extendTop, required this.extendBottom});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final line = Paint()
      ..color = BrandColors.border
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (dotSpec == null) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), line);
      return;
    }
    final top = extendTop ? 0.0 : _kDotY;
    final bottom = extendBottom ? size.height : _kDotY;
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), line);

    // glow
    canvas.drawCircle(Offset(cx, _kDotY), 8,
        Paint()..color = dotSpec!.ring.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // fill + ring
    canvas.drawCircle(Offset(cx, _kDotY), 6.5, Paint()..color = dotSpec!.fill);
    canvas.drawCircle(Offset(cx, _kDotY), 6.5,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = dotSpec!.ring);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.dotSpec != dotSpec || old.extendTop != extendTop || old.extendBottom != extendBottom;
}

/// The card to the right of the timeline dot.
class DoseTimelineCard extends StatelessWidget {
  final Dose dose;
  final DoseEvent? event;
  final VoidCallback onCheck;
  const DoseTimelineCard({super.key, required this.dose, required this.event, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final logged = event != null;
    final chips = _chips();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: logged ? BrandColors.fill : BrandColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrandColors.primary.withValues(alpha: logged ? 0.0 : 0.06)),
          boxShadow: logged ? null : BrandColors.softShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dose.medicationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(18, weight: FontWeight.w700,
                            color: logged ? BrandColors.inkFaint : BrandColors.ink)
                        .copyWith(
                      decoration: logged ? TextDecoration.lineThrough : null,
                      decorationColor: BrandColors.inkFaint,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(spacing: 7, runSpacing: 6, children: chips),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (logged)
              _LoggedAction(event: event!, onTap: onCheck)
            else
              Pressable(onTap: onCheck, borderRadius: BorderRadius.circular(999), child: const _CheckButton()),
          ],
        ),
      ),
    );
  }

  List<Widget> _chips() {
    final out = <Widget>[_Chip(dose.eye.label, BrandColors.secondary)];
    for (final s in dose.instructions.summary.take(2)) {
      out.add(_Chip(s, _instrColor(s)));
    }
    return out;
  }

  Color _instrColor(String s) {
    if (s.startsWith('Shake')) return const Color(0xFFD08A16); // amber
    if (s.startsWith('Refrigerate')) return const Color(0xFF2E9CBF); // cyan
    if (s.startsWith('Wait')) return const Color(0xFF6E62C9); // indigo
    if (s.startsWith('Remove')) return const Color(0xFF2AA593); // teal
    return BrandColors.secondary; // press tear duct → blue
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(text, style: AppTypography.body(12.5, weight: FontWeight.w600, color: color)),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: BrandColors.heroGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: BrandColors.primary.withValues(alpha: 0.34), blurRadius: 12, offset: const Offset(0, 5), spreadRadius: -2),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
    );
  }
}

class _LoggedAction extends StatelessWidget {
  final DoseEvent event;
  final VoidCallback onTap;
  const _LoggedAction({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(event.response.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(event.response.label,
                style: AppTypography.body(11, weight: FontWeight.w700, color: event.response.color)),
          ],
        ),
        Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(Icons.more_vert_rounded, size: 20, color: BrandColors.inkFaint),
          ),
        ),
      ],
    );
  }
}

/// Inline "wait between drops" notification, aligned with the timeline cards.
class WaitBanner extends StatelessWidget {
  const WaitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: BrandColors.cloud,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 16, color: BrandColors.secondary),
            const SizedBox(width: 9),
            Expanded(
              child: Text('Wait 5 minutes between these drops',
                  style: AppTypography.body(13, weight: FontWeight.w600, color: BrandColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
