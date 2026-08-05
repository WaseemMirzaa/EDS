import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthProvider { email, google, apple }

/// Local authentication + permission-gate state.
///
/// NOTE: this is a front-end prototype. There is no backend yet (that is
/// milestone M2 — Firebase/Supabase). Sign-in/up and social login create a
/// local session so the flow is fully navigable; wire real providers in M2.
class AuthController extends ChangeNotifier {
  static const _sessionKey = 'droptracker_auth_session';
  static const _permKey = 'droptracker_permissions_done';

  late SharedPreferences _prefs;
  bool _loaded = false;

  String? _email;
  String _name = '';
  AuthProvider _provider = AuthProvider.email;
  bool _permissionsDone = false;

  bool get loaded => _loaded;
  bool get signedIn => _email != null;
  String? get email => _email;
  String get name => _name;
  AuthProvider get provider => _provider;
  bool get permissionsDone => _permissionsDone;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    _permissionsDone = _prefs.getBool(_permKey) ?? false;
    _loaded = true;
    notifyListeners();
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

  Future<void> signUp({required String name, required String email, required String password}) async {
    _name = name.trim();
    _email = email.trim();
    _provider = AuthProvider.email;
    await _persistSession();
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _email = email.trim();
    _provider = AuthProvider.email;
    await _persistSession();
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    // Placeholder session — real Google OAuth is wired in M2.
    _email = 'you@gmail.com';
    _name = _name.isEmpty ? 'Google user' : _name;
    _provider = AuthProvider.google;
    await _persistSession();
    notifyListeners();
  }

  Future<void> signInWithApple() async {
    // Placeholder session — real Sign in with Apple is wired in M2.
    _email = 'you@icloud.com';
    _name = _name.isEmpty ? 'Apple user' : _name;
    _provider = AuthProvider.apple;
    await _persistSession();
    notifyListeners();
  }

  /// Mock password reset — always "succeeds" in the prototype.
  Future<bool> sendPasswordReset(String email) async {
    return email.contains('@');
  }

  Future<void> signOut() async {
    _email = null;
    _name = '';
    await _persistSession();
    notifyListeners();
  }

  Future<void> markPermissionsDone() async {
    _permissionsDone = true;
    await _prefs.setBool(_permKey, true);
    notifyListeners();
  }
}
