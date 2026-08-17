import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Initialises the Supabase client once, at app startup — a no-op when the
/// project isn't configured yet (see [SupabaseConfig.isConfigured]).
class SupabaseBootstrap {
  SupabaseBootstrap._();
  static bool _initialized = false;

  static Future<void> init() async {
    if (!SupabaseConfig.isConfigured || _initialized) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // Same value as the legacy "anon key" — Supabase renamed the concept,
      // not the format; SupabaseConfig.anonKey is fed straight through.
      publishableKey: SupabaseConfig.anonKey,
      // Deep-link callback for the Google / Apple OAuth browser redirect.
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: kDebugMode,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
