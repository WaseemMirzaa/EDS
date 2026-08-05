import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';

/// Large, high-contrast primary button — sized for comfortable tapping
/// (the audience skews older / post-surgery).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color color;
  final Color foreground;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color = BrandColors.ocean,
    this.foreground = BrandColors.white,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          disabledForegroundColor: foreground.withValues(alpha: 0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppTypography.body(17, weight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: BrandColors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Secondary outlined button.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = BrandColors.ocean,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTypography.body(15, weight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// A soft white card with a subtle border, the app's default surface.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? BrandColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? BrandColors.hairline),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

/// Small pill tag (eye label, instruction chip).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color = BrandColors.inkSoft, this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? BrandColors.cloud,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text,
              style: AppTypography.body(12, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Standard section spacing.
class Gap extends StatelessWidget {
  final double h;
  const Gap(this.h, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}
