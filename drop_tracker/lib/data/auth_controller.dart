import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'device_reliability_service.dart';
import 'permission_service.dart';
// FCM push is disabled — see main.dart's commented-out Firebase init.
// import 'remote/fcm_service.dart';
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
/// screen, every gate — is navigable and testable with zero backend.
class AuthController extends ChangeNotifier {
  static const _sessionKey = 'droptracker_auth_session';

  late SharedPreferences _prefs;
  bool _loaded = false;

  String? _email;
  String? _userId;
  String _name = '';
  AuthProvider _provider = AuthProvider.email;
  // Driven from real OS permission status (refreshed on launch + resume).
  bool _permissionsDone = false;
  bool _exactAlarmsDone = false;
  bool _batteryDone = false;
  bool _backgroundReliabilityDone = false;
  // Set when the user opened the app via a "reset your password" email link
  // (AuthChangeEvent.passwordRecovery carries a real, valid session, so
  // signedIn is true too) — the root gate routes to NewPasswordScreen instead
  // of straight into the app until they actually set a new password.
  bool _passwordRecoveryPending = false;

  StreamSubscription<sb.AuthState>? _authSub;

  bool get loaded => _loaded;

  /// True when we have a live Supabase session *or* a restored local mirror
  /// (email/userId). Apple can omit email; session presence still counts.
  bool get signedIn {
    if (_remote) {
      try {
        if (SupabaseBootstrap.client.auth.currentSession != null) return true;
      } catch (_) {}
    }
    return (_email != null && _email!.isNotEmpty) ||
        (_userId != null && _userId!.isNotEmpty);
  }

  String? get email => _email;
  String get name => _name;
  AuthProvider get provider => _provider;
  bool get permissionsDone => _permissionsDone;
  bool get exactAlarmsDone => _exactAlarmsDone;
  bool get batteryDone => _batteryDone;
  bool get backgroundReliabilityDone => _backgroundReliabilityDone;
  bool get passwordRecoveryPending => _passwordRecoveryPending;

  bool get _remote => SupabaseConfig.isConfigured;
  sb.GoTrueClient get _auth => SupabaseBootstrap.client.auth;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    if (_remote) {
      await SupabaseBootstrap.init();

      // Optimistic restore so splash doesn't bounce a returning user to login
      // while Supabase finishes reading the secure-storage session.
      _restoreLocalSessionMirror();

      final session = _auth.currentSession;
      if (session != null) {
        _applySupabaseUser(session.user);
        await _persistSession();
      }

      final initial = Completer<void>();
      _authSub = _auth.onAuthStateChange.listen((state) async {
        switch (state.event) {
          case sb.AuthChangeEvent.initialSession:
            if (state.session != null) {
              _applySupabaseUser(state.session!.user);
              await _persistSession();
            } else if (!signedIn) {
              // No server session and no local mirror — stay signed out.
              _clearLocalIdentity();
            }
            // If mirror says signed-in but server session is briefly null
            // (cold start / flaky network), keep the mirror until a real
            // signedOut arrives — don't wipe a returning user to the login
            // screen from under them.
            if (!initial.isCompleted) initial.complete();
          case sb.AuthChangeEvent.signedIn:
          case sb.AuthChangeEvent.tokenRefreshed:
          case sb.AuthChangeEvent.userUpdated:
            if (state.session != null) {
              _applySupabaseUser(state.session!.user);
              await _persistSession();
            }
          case sb.AuthChangeEvent.passwordRecovery:
            if (state.session != null) {
              _applySupabaseUser(state.session!.user);
              await _persistSession();
            }
            _passwordRecoveryPending = true;
          case sb.AuthChangeEvent.signedOut:
            _clearLocalIdentity();
            _passwordRecoveryPending = false;
            await _prefs.remove(_sessionKey);
          default:
            break;
        }
        notifyListeners();
      });

      // Don't leave splash until we've heard initialSession (or timed out).
      await initial.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } else {
      _restoreLocalSessionMirror();
    }

    await refreshPermissionStatus();
    _loaded = true;
    notifyListeners();
  }

  void _clearLocalIdentity() {
    _email = null;
    _userId = null;
    _name = '';
  }

  void _restoreLocalSessionMirror() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _email = j['email'] as String?;
      _userId = j['userId'] as String?;
      _name = (j['name'] ?? '') as String;
      _provider = AuthProvider.values.firstWhere(
        (p) => p.name == j['provider'],
        orElse: () => AuthProvider.email,
      );
    } catch (_) {}
  }

  void _applySupabaseUser(sb.User? user) {
    if (user == null) {
      _clearLocalIdentity();
      return;
    }
    _userId = user.id;
    // Keep prior email if this provider omits it (common on later Apple sign-ins).
    final nextEmail = user.email;
    if (nextEmail != null && nextEmail.isNotEmpty) {
      _email = nextEmail;
    }
    _name = (user.userMetadata?['full_name'] as String?) ?? _name;
    final providerName = user.appMetadata['provider'] as String?;
    _provider = switch (providerName) {
      'google' => AuthProvider.google,
      'apple' => AuthProvider.apple,
      _ => AuthProvider.email,
    };
  }

  Future<void> _persistSession() async {
    if (!signedIn) {
      await _prefs.remove(_sessionKey);
      return;
    }
    await _prefs.setString(
      _sessionKey,
      jsonEncode({
        'email': _email,
        'userId': _userId,
        'name': _name,
        'provider': _provider.name,
      }),
    );
  }

  /// Re-read OS permission state. Call on cold start, after a grant attempt,
  /// and whenever the app returns to the foreground.
  Future<void> refreshPermissionStatus() async {
    _permissionsDone =
        await PermissionService.instance.notificationsGranted();
    _exactAlarmsDone = await PermissionService.instance.exactAlarmsGranted();
    _batteryDone = await PermissionService.instance.batteryUnrestricted();
    await DeviceReliabilityService.instance.detect();
    _backgroundReliabilityDone =
        !DeviceReliabilityService.instance.needsManualBackgroundSetup ||
            await DeviceReliabilityService.instance.acknowledged();
    notifyListeners();
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
      final identities = res.user?.identities;
      if (res.user != null && (identities == null || identities.isEmpty)) {
        throw const sb.AuthException(
          'An account with this email already exists.',
          code: 'user_already_exists',
        );
      }
      if (res.session == null && res.user != null) {
        throw const sb.AuthException(
          'Check your email to confirm your account before signing in.',
          code: 'email_not_confirmed',
        );
      }
      _applySupabaseUser(res.user);
    } else {
      _name = name.trim();
      _email = email.trim();
      _userId = 'local';
      _provider = AuthProvider.email;
    }
    await _persistSession();
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_remote) {
      final res = await _auth.signInWithPassword(
          email: email.trim(), password: password);
      _applySupabaseUser(res.user);
    } else {
      _email = email.trim();
      _userId = 'local';
      _provider = AuthProvider.email;
    }
    await _persistSession();
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (_remote) {
      if (SupabaseConfig.hasNativeGoogleSignIn) {
        try {
          await _signInWithGoogleNative();
          await _persistSession();
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Native Google sign-in failed, falling back to OAuth: $e');
        }
      }
      await _auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: SupabaseConfig.oauthRedirect,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
    } else {
      _email = 'you@gmail.com';
      _userId = 'local-google';
      _name = _name.isEmpty ? 'Google user' : _name;
      _provider = AuthProvider.google;
      await _persistSession();
    }
    notifyListeners();
  }

  Future<void> _signInWithGoogleNative() async {
    final googleSignIn =
        GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in returned no ID token');
    }
    final res = await _auth.signInWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    _applySupabaseUser(res.user);
  }

  Future<void> signInWithApple() async {
    if (_remote) {
      try {
        await _signInWithAppleNative();
        await _persistSession();
        notifyListeners();
        return;
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          return;
        }
        debugPrint('Native Apple sign-in failed, falling back to OAuth: $e');
      } catch (e) {
        debugPrint('Native Apple sign-in failed, falling back to OAuth: $e');
      }
      await _auth.signInWithOAuth(
        sb.OAuthProvider.apple,
        redirectTo: SupabaseConfig.oauthRedirect,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
    } else {
      _email = 'you@icloud.com';
      _userId = 'local-apple';
      _name = _name.isEmpty ? 'Apple user' : _name;
      _provider = AuthProvider.apple;
      await _persistSession();
    }
    notifyListeners();
  }

  Future<void> _signInWithAppleNative() async {
    final isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    if (!isApplePlatform && !SupabaseConfig.hasNativeAppleWebFallback) {
      throw StateError('No Apple Services ID configured for the web fallback');
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: isApplePlatform
          ? null
          : WebAuthenticationOptions(
              clientId: SupabaseConfig.appleServiceId,
              redirectUri: Uri.parse(SupabaseConfig.oauthRedirect),
            ),
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple sign-in returned no identity token');
    }
    final res = await _auth.signInWithIdToken(
      provider: sb.OAuthProvider.apple,
      idToken: idToken,
    );
    _applySupabaseUser(res.user);
    final givenName = credential.givenName;
    if (givenName != null && givenName.isNotEmpty && _name.isEmpty) {
      _name = givenName;
      try {
        await _auth
            .updateUser(sb.UserAttributes(data: {'full_name': givenName}));
      } catch (e) {
        debugPrint('Could not persist Apple given name to profile: $e');
      }
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (_remote) {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: SupabaseConfig.oauthRedirect,
      );
    }
  }

  Future<void> updatePassword(String newPassword) async {
    if (_remote) {
      await _auth.updateUser(sb.UserAttributes(password: newPassword));
    }
  }

  void dismissPasswordRecovery() {
    _passwordRecoveryPending = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_remote) {
      await _auth.signOut();
      if (SupabaseConfig.hasNativeGoogleSignIn) {
        try {
          await GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId)
              .signOut();
        } catch (_) {}
      }
    }
    _clearLocalIdentity();
    await _persistSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<bool> markPermissionsDone() async {
    await refreshPermissionStatus();
    return _permissionsDone;
  }

  Future<bool> markExactAlarmsDone() async {
    await refreshPermissionStatus();
    return _exactAlarmsDone;
  }

  Future<bool> markBatteryDone() async {
    await refreshPermissionStatus();
    return _batteryDone;
  }

  Future<bool> markBackgroundReliabilityDone() async {
    await refreshPermissionStatus();
    return _backgroundReliabilityDone;
  }
}
