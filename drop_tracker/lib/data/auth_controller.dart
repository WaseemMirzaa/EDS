import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'remote/supabase_bootstrap.dart';
import 'remote/supabase_config.dart';

enum AuthProvider { email, google, apple }

/// Authentication + permission-gate state.
///
/// Backed by real Supabase Auth once [SupabaseConfig.isConfigured] is true —
/// email/password, Google and Apple all create a genuine server-side session,
/// and [signedIn] reflects that session rather than a local flag.
///
/// Until a Supabase project is configured, this falls back to a local mock
/// session (a name + email held in SharedPreferences) so the full app — every
/// screen, every gate — is navigable and testable with zero backend. Wiring a
/// project is then a `--dart-define` away; no screen changes.
class AuthController extends ChangeNotifier {
  static const _sessionKey = 'droptracker_auth_session';

  late SharedPreferences _prefs;
  bool _loaded = false;

  String? _email;
  String _name = '';
  AuthProvider _provider = AuthProvider.email;
  // Permission gates are intentionally NOT persisted — the permission screens
  // are mandatory on every launch (reset to false each cold start).
  bool _permissionsDone = false;
  bool _batteryDone = false;

  bool get loaded => _loaded;
  bool get signedIn => _email != null;
  String? get email => _email;
  String get name => _name;
  AuthProvider get provider => _provider;
  bool get permissionsDone => _permissionsDone;
  bool get batteryDone => _batteryDone;

  bool get _remote => SupabaseConfig.isConfigured;
  sb.GoTrueClient get _auth => SupabaseBootstrap.client.auth;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    if (_remote) {
      await SupabaseBootstrap.init();
      // Restored automatically by supabase_flutter from secure local storage;
      // this just reflects whatever session (if any) came back.
      _applySupabaseUser(_auth.currentUser);
      _auth.onAuthStateChange.listen((state) {
        _applySupabaseUser(state.session?.user);
        notifyListeners();
      });
    } else {
      final raw = _prefs.getString(_sessionKey);
      if (raw != null) {
        try {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          _email = j['email'] as String?;
          _name = (j['name'] ?? '') as String;
          _provider = AuthProvider.values.firstWhere(
            (p) => p.name == j['provider'],
            orElse: () => AuthProvider.email,
          );
        } catch (_) {}
      }
    }
    // _permissionsDone / _batteryDone stay false on every launch (not loaded).
    _loaded = true;
    notifyListeners();
  }

  void _applySupabaseUser(sb.User? user) {
    _email = user?.email;
    _name = (user?.userMetadata?['full_name'] as String?) ?? _name;
    final providerName = user?.appMetadata['provider'] as String?;
    _provider = switch (providerName) {
      'google' => AuthProvider.google,
      'apple' => AuthProvider.apple,
      _ => AuthProvider.email,
    };
  }

  Future<void> _persistSession() async {
    if (_email == null) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(
        _sessionKey,
        jsonEncode({'email': _email, 'name': _name, 'provider': _provider.name}),
      );
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_remote) {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
      _applySupabaseUser(res.user);
    } else {
      _name = name.trim();
      _email = email.trim();
      _provider = AuthProvider.email;
      await _persistSession();
    }
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_remote) {
      final res =
          await _auth.signInWithPassword(email: email.trim(), password: password);
      _applySupabaseUser(res.user);
    } else {
      _email = email.trim();
      _provider = AuthProvider.email;
      await _persistSession();
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (_remote) {
      // Browser-based OAuth redirect (PKCE flow); the app resumes on
      // SupabaseConfig.oauthRedirect and onAuthStateChange picks up the
      // session. See db/README.md for the matching platform + Supabase
      // dashboard configuration.
      await _auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: SupabaseConfig.oauthRedirect,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
      // Session lands via the onAuthStateChange listener once the redirect
      // completes; nothing more to apply synchronously here.
    } else {
      // Local mock session — no backend configured yet.
      _email = 'you@gmail.com';
      _name = _name.isEmpty ? 'Google user' : _name;
      _provider = AuthProvider.google;
      await _persistSession();
    }
    notifyListeners();
  }

  Future<void> signInWithApple() async {
    if (_remote) {
      await _auth.signInWithOAuth(
        sb.OAuthProvider.apple,
        redirectTo: SupabaseConfig.oauthRedirect,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
    } else {
      _email = 'you@icloud.com';
      _name = _name.isEmpty ? 'Apple user' : _name;
      _provider = AuthProvider.apple;
      await _persistSession();
    }
    notifyListeners();
  }

  /// Sends a password-reset email. Returns whether the request was accepted —
  /// note Supabase always returns success here regardless of whether the
  /// address has an account, by design, so this can't be used to probe which
  /// emails are registered.
  Future<bool> sendPasswordReset(String email) async {
    if (!email.contains('@')) return false;
    if (_remote) {
      try {
        await _auth.resetPasswordForEmail(email.trim());
        return true;
      } catch (e) {
        debugPrint('password reset failed: $e');
        return false;
      }
    }
    return true;
  }

  Future<void> signOut() async {
    if (_remote) {
      await _auth.signOut();
    }
    _email = null;
    _name = '';
    await _persistSession();
    notifyListeners();
  }

  // Session-only (not persisted) so the gate reappears next launch.
  Future<void> markPermissionsDone() async {
    _permissionsDone = true;
    notifyListeners();
  }

  Future<void> markBatteryDone() async {
    _batteryDone = true;
    notifyListeners();
  }
}
