import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'common.dart';
import 'drop_logo.dart';

/// One-time notice shown the first time someone taps through to Eye Drop
/// Shop: it's an over-the-counter storefront, not doctor-prescribed
/// medication, so it's not covered by the app's clinical disclaimers.
Future<bool> showShopInterstitial(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _ShopInterstitialSheet(),
  );
  return result ?? false;
}

class _ShopInterstitialSheet extends StatelessWidget {
  const _ShopInterstitialSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BrandColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: BrandColors.cloud, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const DropMark(size: 22, color: BrandColors.gold, filled: true),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Heading to Eye Drop Shop',
                    style: AppTypography.display(20, weight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "You're leaving Drop Tracker to visit Eye Drop Shop, an online store for over-the-counter eye care products. These do not replace any medication prescribed by your eye care provider.",
            style: AppTypography.body(14.5, weight: FontWeight.w500, color: BrandColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Continue to store',
            icon: Icons.arrow_outward_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Not now',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
