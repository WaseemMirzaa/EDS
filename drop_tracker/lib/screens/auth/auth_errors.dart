import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/auth_widgets.dart';

/// Maps Supabase / network auth failures to short, user-facing copy.
String authErrorMessage(Object error) {
  // Check the more specific gotrue subclasses first — they carry a generic,
  // not-very-useful default `message` (e.g. an AuthRetryableFetchException's
  // message is literally "AuthRetryableFetchException"), which the trimmed-
  // message fallback below would otherwise show verbatim.
  if (error is AuthRetryableFetchException) {
    return 'Network error. Check your connection and try again.';
  }
  if (error is AuthSessionMissingException) {
    return 'That link has expired or was already used. Please request a new one.';
  }
  if (error is AuthWeakPasswordException) {
    return 'Choose a stronger password (at least 6 characters).';
  }
  if (error is AuthPKCEGrantCodeExchangeError) {
    return 'That link has expired or was already used. Please request a new one.';
  }

  if (error is AuthException) {
    final code = error.code?.toLowerCase() ?? '';
    final msg = error.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (code == 'user_already_exists' ||
        msg.contains('already registered') ||
        msg.contains('user already registered')) {
      return 'An account with this email already exists. Try logging in.';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (code == 'weak_password' || msg.contains('password')) {
      if (msg.contains('weak') || msg.contains('least')) {
        return 'Choose a stronger password (at least 6 characters).';
      }
    }
    if (code == 'over_request_rate_limit' || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (code == 'over_email_send_rate_limit') {
      return 'Too many reset emails requested. Please wait a few minutes and try again.';
    }
    if (code == 'same_password') {
      return 'Please choose a password different from your current one.';
    }
    if (code == 'user_not_found' || msg.contains('user not found')) {
      return 'No account found for that email.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('failed host lookup')) {
      return 'Network error. Check your connection and try again.';
    }
    // Prefer the server message when it's already readable.
    final trimmed = error.message.trim();
    if (trimmed.isNotEmpty && trimmed.length < 120) return trimmed;
  }

  if (error is SignInWithAppleAuthorizationException) {
    switch (error.code) {
      case AuthorizationErrorCode.canceled:
        // Callers generally intercept this before it reaches here (see
        // AuthController.signInWithApple), but handle it defensively too.
        return 'Sign-in with Apple was cancelled.';
      case AuthorizationErrorCode.notInteractive:
      case AuthorizationErrorCode.notHandled:
        return 'Apple sign-in isn\'t available right now. Please try again.';
      default:
        return 'Apple sign-in failed. Please try again.';
    }
  }

  if (error is PostgrestException) {
    // A signed-in user still needs their `profiles` row to exist before any
    // Supabase table write succeeds (RLS keys off auth.uid()); surface RLS
    // denials distinctly from a generic failure so they're actionable.
    if (error.code == '42501' || error.message.toLowerCase().contains('row-level security')) {
      return 'Your account isn\'t fully set up yet. Please try again in a moment.';
    }
    final msg = error.message.trim();
    if (msg.isNotEmpty && msg.length < 120) return msg;
    return 'Something went wrong saving your data. Please try again.';
  }

  final raw = error.toString();
  if (raw.contains('SocketException') ||
      raw.contains('ClientException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('TimeoutException')) {
    return 'Network error. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

void showAuthSnackBar(BuildContext context, String message, {bool error = true}) {
  // MaterialApp always provides a root ScaffoldMessenger, but guard anyway —
  // an error here would otherwise fail *silently*, which is exactly the
  // "nothing happened" symptom this function exists to prevent.
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    debugPrint('showAuthSnackBar: no ScaffoldMessenger in context — $message');
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AuthColors.error : AuthColors.success,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 4),
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
    ),
  );
}
