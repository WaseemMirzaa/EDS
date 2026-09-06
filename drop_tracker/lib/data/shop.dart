import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/shop_interstitial_sheet.dart';

/// Eye Drop Shop storefront — opened in the device's external browser.
///
/// The storefront sells over-the-counter eye care, not the doctor-prescribed
/// drops the rest of the app tracks, so the first tap through shows a
/// one-time interstitial making that distinction clear before leaving the
/// app; later taps go straight to the store.
class Shop {
  Shop._();

  static const String _domainCa = 'eyedropshop.ca';
  static const String _domainDefault = 'eyedropshop.com';

  static const String _interstitialShownKey = 'shop_interstitial_shown_v1';

  /// Routes by the device's region: Canada → eyedropshop.ca, United States
  /// (and everywhere else) → eyedropshop.com.
  static String get domain {
    final country =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return country == 'CA' ? _domainCa : _domainDefault;
  }

  /// Always shown on marketing surfaces; [domain] still drives the real URL.
  static const String displayDomain = _domainDefault;

  static String get _base => 'https://$domain';

  /// Opens the store in the external browser, tagged so the shop can
  /// attribute visits coming from the app.
  static Future<void> open(BuildContext context, {String campaign = 'in_app_banner'}) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_interstitialShownKey) ?? false;
    if (!seen) {
      if (!context.mounted) return;
      final proceed = await showShopInterstitial(context);
      await prefs.setBool(_interstitialShownKey, true);
      if (!proceed) return;
    }
    if (!context.mounted) return;
    await _launch(context, campaign);
  }

  static Future<void> _launch(BuildContext context, String campaign) async {
    final uri = Uri.parse(
      '$_base?utm_source=droptracker_app&utm_medium=in_app&utm_campaign=$campaign',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _fallback(context);
    } catch (_) {
      if (context.mounted) _fallback(context);
    }
  }

  static void _fallback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visit $domain in your browser.')),
    );
  }
}
