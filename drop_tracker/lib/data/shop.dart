import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Eye Drop Shop storefront — opened in the device's external browser.
class Shop {
  Shop._();

  static const String domain = 'eyedropshop.ca';
  static const String _base = 'https://eyedropshop.ca';

  /// Opens the store in the external browser, tagged so the shop can attribute
  /// visits coming from the app.
  static Future<void> open(BuildContext context, {String campaign = 'in_app_banner'}) async {
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
      const SnackBar(content: Text('Visit eyedropshop.ca in your browser.')),
    );
  }
}
