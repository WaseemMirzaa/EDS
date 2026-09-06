import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'motion.dart';

/// Large, high-contrast primary button — sized for comfortable tapping
/// (the audience skews older / post-surgery), with press feedback + haptics.
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
    return Pressable(
      onTap: disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        opacity: disabled ? 0.45 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -6,
                    ),
                  ],
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 22, color: foreground), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(17, weight: FontWeight.w700, color: foreground)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary outlined button (quieter, tinted fill).
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
    return Pressable(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 8)],
            Text(label, style: AppTypography.body(15, weight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Apple-Wallet-style surface: soft shadow, whisper-subtle top highlight
/// gradient and a hairline border. The app's default premium card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.onTap,
    this.shadow,
    this.radius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    final flat = color != null; // tinted cards skip the highlight gradient
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: flat ? color : null,
        gradient: flat
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [BrandColors.surfaceTint, BrandColors.surface],
                stops: [0.0, 0.4],
              ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? BrandColors.border.withValues(alpha: 0.7)),
        boxShadow: shadow ?? BrandColors.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: card);
  }
}

/// Rounded capsule chip with a soft tint and optional icon.
class Capsule extends StatelessWidget {
  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;
  const Capsule(this.text, {super.key, this.color = BrandColors.secondary, this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: icon != null ? 8 : 11, right: 11, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
          Text(text, style: AppTypography.body(12, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Standard 58-high text field with a focus glow.
class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final List<TextInputFormatter> formatters;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final bool obscure;
  const AppField({
    super.key,
    required this.controller,
    this.hint = '',
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.formatters = const [],
    this.onChanged,
    this.textAlign = TextAlign.start,
    this.obscure = false,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  final _focus = FocusNode();
  bool _focused = false;
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: _focused ? BrandColors.primary : BrandColors.border,
          width: _focused ? 1.6 : 1.2,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: BrandColors.primary.withValues(alpha: 0.12), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              textCapitalization: widget.capitalization,
              keyboardType: widget.keyboardType,
              minLines: widget.obscure ? 1 : widget.minLines,
              maxLines: widget.obscure ? 1 : widget.maxLines,
              obscureText: _hidden,
              inputFormatters: widget.formatters,
              onChanged: widget.onChanged,
              textAlign: widget.textAlign,
              cursorColor: BrandColors.primary,
              style: AppTypography.body(16, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTypography.body(16, weight: FontWeight.w500, color: BrandColors.inkFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              ),
            ),
          ),
          if (widget.obscure)
            Pressable(
              onTap: () => setState(() => _hidden = !_hidden),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: Icon(_hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20, color: BrandColors.inkFaint),
              ),
            ),
        ],
      ),
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

/// A quiet uppercase section label.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 2),
        child: Text(text.toUpperCase(),
            style: AppTypography.body(12, weight: FontWeight.w700, color: BrandColors.inkFaint, letterSpacing: 1.0)),
      );
}

/// Standard section spacing.
class Gap extends StatelessWidget {
  final double h;
  const Gap(this.h, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

/// Wraps any scaffold body with the whisper-soft page gradient.
class PageGradient extends StatelessWidget {
  final Widget child;
  const PageGradient({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: BrandColors.pageGradient),
        child: child,
      );
}
