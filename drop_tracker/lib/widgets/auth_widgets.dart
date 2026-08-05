import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'drop_logo.dart';
import 'motion.dart';

/// Branded header for auth screens: logo badge + title + subtitle.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: BrandColors.cloud,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const DropBadge(size: 40, ringColor: BrandColors.primary, dropColor: BrandColors.gold),
        ),
        const SizedBox(height: 22),
        Text(title, style: AppTypography.display(32, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: AppTypography.body(15, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.4)),
      ],
    );
  }
}

enum SocialKind { google, apple }

/// "Continue with Google / Apple" button.
class SocialButton extends StatelessWidget {
  final SocialKind kind;
  final VoidCallback onTap;
  const SocialButton({super.key, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isApple = kind == SocialKind.apple;
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isApple ? BrandColors.ink : BrandColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: isApple ? null : Border.all(color: BrandColors.border, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isApple
                ? const Icon(Icons.apple, size: 22, color: Colors.white)
                : const _GoogleGlyph(),
            const SizedBox(width: 10),
            Text('Continue with ${isApple ? 'Apple' : 'Google'}',
                style: AppTypography.body(15.5,
                    weight: FontWeight.w600, color: isApple ? Colors.white : BrandColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();
  @override
  Widget build(BuildContext context) {
    // Simple multi-tone "G" mark.
    return SizedBox(
      width: 20,
      height: 20,
      child: Text('G',
          textAlign: TextAlign.center,
          style: AppTypography.display(20, weight: FontWeight.w700, color: const Color(0xFF4285F4))),
    );
  }
}

/// "or" divider between primary and social auth.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BrandColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: AppTypography.body(13, weight: FontWeight.w600, color: BrandColors.inkFaint)),
        ),
        const Expanded(child: Divider(color: BrandColors.border)),
      ],
    );
  }
}

/// Field with a floating label above it.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const LabeledField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(label, style: AppTypography.body(13.5, weight: FontWeight.w600, color: BrandColors.inkSoft)),
        ),
        child,
      ],
    );
  }
}
