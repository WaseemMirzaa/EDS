/// Supabase connection settings, supplied at build time — never hardcoded and
/// never committed. Read from `--dart-define`:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// or from a `--dart-define-from-file=env.json` (see `env.example.json` at the
/// project root; keep the real `env.json` out of version control).
///
/// The project URL and anon/public key are safe to ship inside the compiled
/// app — they are what every Supabase client app embeds. Every table is
/// protected by row-level security (see db/migrations/002 and 003), so the
/// anon key alone cannot read or write another user's data. The service-role
/// key is never used from the app and must never appear here.
///
/// While these are unset, [isConfigured] is false and the app runs exactly as
/// it does today — local-only, device storage, no network calls — so nothing
/// regresses before a Supabase project exists. Once set, [AuthController] and
/// [DropStore] switch themselves over automatically; no other code changes.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Deep-link scheme used for the OAuth (Google / Apple) browser redirect
  /// back into the app. Must match:
  ///   - `CFBundleURLSchemes` in ios/Runner/Info.plist
  ///   - the `<data android:scheme=".../>` intent filter in
  ///     android/app/src/main/AndroidManifest.xml
  ///   - the Redirect URL allow-listed in Supabase → Authentication → URL
  ///     Configuration
  static const String oauthRedirect = 'com.eyedropshop.droptracker://login-callback';
}
