import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import 'auth_errors.dart';

/// Shown when the root gate sees [AuthController.passwordRecoveryPending] —
/// i.e. the user just opened the app via the "reset your password" email
/// link. Lets them actually set a new password before continuing, which is
/// the step the old flow was missing (the email sent, but nothing ever let
/// them finish the reset once they got here).
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _passErr, _confirmErr;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final passErr =
        _password.text.length >= 6 ? null : 'Password must be at least 6 characters';
    final confirmErr =
        _confirm.text == _password.text ? null : 'Passwords don\'t match';
    setState(() {
      _passErr = passErr;
      _confirmErr = confirmErr;
    });
    if (passErr != null || confirmErr != null) return;

    setState(() => _busy = true);
    try {
      await context.read<AuthController>().updatePassword(_password.text);
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (mounted) showAuthSnackBar(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    // They opened the link by mistake, or changed their mind — back out to
    // a normal signed-out state rather than leaving them stuck here.
    await context.read<AuthController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const AppLogo(),
        const SizedBox(height: 40),
        AuthHero(
          title: _done ? 'Password updated' : 'Choose a new password',
          subtitle: _done
              ? 'You can now continue into Drop Tracker.'
              : 'Enter a new password for your account.',
        ),
        const SizedBox(height: 28),
        if (!_done) ...[
          AuthCard(
            children: [
              AuthField(
                label: 'New password',
                controller: _password,
                hint: 'At least 6 characters',
                password: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _passErr,
                onChanged: (_) =>
                    _passErr == null ? null : setState(() => _passErr = null),
              ),
              const SizedBox(height: 20),
              AuthField(
                label: 'Confirm password',
                controller: _confirm,
                hint: 'Re-enter your new password',
                password: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _confirmErr,
                onChanged: (_) => _confirmErr == null
                    ? null
                    : setState(() => _confirmErr = null),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
              label: 'Update password',
              loadingLabel: 'Updating…',
              loading: _busy,
              onPressed: _submit),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _cancel,
              child: Text('Cancel',
                  style: AppTypography.body(14.5,
                      weight: FontWeight.w600, color: AuthColors.textSecondary)),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AuthColors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AuthColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Your password has been changed.',
                      style: AppTypography.body(14.5,
                          weight: FontWeight.w500,
                          color: AuthColors.textPrimary,
                          height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Continue',
            onPressed: () =>
                context.read<AuthController>().dismissPasswordRecovery(),
          ),
        ],
      ],
    );
  }
}
