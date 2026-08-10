import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/shop.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'drop_logo.dart';
import 'motion.dart';

/// Premium, conversion-focused store banner (Home hero). Deep-ocean surface,
/// gold brand accent, trust signals and a single strong CTA that opens
/// eyedropshop.ca in the external browser.
class ShopBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  final String campaign;
  const ShopBanner({
    super.key,
    this.title = 'Doctor-formulated eye care',
    this.subtitle = 'Dry-eye drops & essentials, shipped across Canada.',
    this.cta = 'Shop Eye Drop Shop',
    this.campaign = 'home_banner',
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        Shop.open(context, campaign: campaign);
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: BrandColors.heroGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: BrandColors.primary.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                bottom: -34,
                child: Opacity(opacity: 0.08, child: DropMark(size: 170, color: Colors.white, filled: true)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: DropMark(size: 16, color: BrandColors.gold, filled: true),
                        ),
                        const SizedBox(width: 9),
                        Text('EYE DROP SHOP',
                            style: AppTypography.body(11.5, weight: FontWeight.w700, color: BrandColors.gold, letterSpacing: 1.4)),
                        const Spacer(),
                        Text(Shop.domain,
                            style: AppTypography.body(12, weight: FontWeight.w500, color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(title,
                        style: AppTypography.display(23, weight: FontWeight.w700, color: Colors.white, height: 1.1)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: AppTypography.body(14, weight: FontWeight.w500, color: Colors.white70, height: 1.4)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _Trust('By eye doctors'),
                        _Trust('No prescription'),
                        _Trust('Canadian'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cta, style: AppTypography.body(15.5, weight: FontWeight.w700, color: BrandColors.primary)),
                          const SizedBox(width: 7),
                          const Icon(Icons.arrow_outward_rounded, size: 18, color: BrandColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trust extends StatelessWidget {
  final String text;
  const _Trust(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 13, color: BrandColors.gold),
          const SizedBox(width: 5),
          Text(text, style: AppTypography.body(12, weight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

/// Compact "restock" card for lists (Medications) and rows (Settings).
class ShopRestockCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String campaign;
  const ShopRestockCard({
    super.key,
    this.title = 'Running low on drops?',
    this.subtitle = 'Restock from Eye Drop Shop — no prescription needed.',
    this.campaign = 'restock_card',
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        Shop.open(context, campaign: campaign);
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BrandColors.cloud,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: BrandColors.primary.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: BrandColors.surface, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: DropMark(size: 24, color: BrandColors.gold, filled: true),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body(15, weight: FontWeight.w700, color: BrandColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.body(12.5, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: BrandColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_outward_rounded, size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
