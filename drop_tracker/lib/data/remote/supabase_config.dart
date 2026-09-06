/// Supabase connection settings.
///
/// Default to this project's real Supabase instance (below), so a plain
/// `flutter run` / `flutter build ios` / `flutter build appbundle` — with no
/// extra flags, on either platform — talks to the real backend out of the
/// box. That was the original design intent (see [isConfigured]'s doc), but
/// requiring every invocation to remember `--dart-define-from-file=env.json`
/// meant a platform built without it (as iOS was) silently fell back to
/// local-only guest mode while the other platform, built with the flag,
/// looked "real" — same code, different flag, confusingly different
/// behavior. Baking in the default removes that footgun.
///
/// Override at build time when needed — e.g. pointing at a staging project,
/// or a contributor's own Supabase instance:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// or `--dart-define-from-file=env.json` (see `env.example.json` at the
/// project root; keep the real `env.json` out of version control — it's
/// still useful for e.g. GOOGLE_WEB_CLIENT_ID/APPLE_SERVICE_ID below, which
/// have no default).
///
/// The project URL and anon/public key are safe to ship inside the compiled
/// app — they are what every Supabase client app embeds. Every table is
/// protected by row-level security (see db/migrations/002 and 003), so the
/// anon key alone cannot read or write another user's data. The service-role
/// key is never used from the app and must never appear here.
///
/// [isConfigured] is only false if a build explicitly overrides both values
/// to empty strings — in that case the app runs local-only, device storage,
/// no network calls, exactly as it did before a Supabase project existed.
/// [AuthController] and [DropStore] switch between the two automatically; no
/// other code changes.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bsekhzbfvgzacabgzkfw.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzZWtoemJmdmd6YWNhYmd6a2Z3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0ODE0NjEsImV4cCI6MjEwMzA1NzQ2MX0.F_kAe8hAkfQCxi3Yqb0Twwf6gsrBM_RZIVPBt6H6-eI',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Deep-link scheme used for the OAuth (Google / Apple) browser redirect
  /// back into the app. Must match:
  ///   - `CFBundleURLSchemes` in ios/Runner/Info.plist
  ///   - the `<data android:scheme=".../>` intent filter in
  ///     android/app/src/main/AndroidManifest.xml
  ///   - the Redirect URL allow-listed in Supabase → Authentication → URL
  ///     Configuration
  ///
  /// Still used as the fallback path for both providers whenever the native
  /// configuration below isn't present, and always used for Apple on
  /// non-Apple platforms (there is no native Apple credential sheet on
  /// Android).
  static const String oauthRedirect = 'com.eyedropshop.droptracker://login-callback';

  // ---- Native Google Sign-In --------------------------------------------
  //
  // The *Web* client ID from the same Google Cloud OAuth consent screen used
  // to configure Supabase's Google provider (db/README.md Part A3) — Google's
  // documented way to obtain a verifiable ID token from a mobile app without
  // provisioning a separate Android/iOS client. One value, both platforms.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get hasNativeGoogleSignIn => googleWebClientId.isNotEmpty;

  // ---- Native Sign in with Apple ----------------------------------------
  //
  // The Services ID created for Supabase's Apple provider (db/README.md Part
  // A3). Required only for the web-fallback path `sign_in_with_apple` itself
  // uses on non-Apple platforms; the native iOS credential sheet needs no
  // extra id, only the entitlement in Runner.entitlements.
  static const String appleServiceId =
      String.fromEnvironment('APPLE_SERVICE_ID');

  /// Whether the web-based Apple credential flow (used on every platform
  /// other than iOS/macOS, where a native Face ID / Touch ID sheet needs no
  /// id at all) has what it needs configured.
  static bool get hasNativeAppleWebFallback => appleServiceId.isNotEmpty;
}
