import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_controller.dart';
import '../../data/drop_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';

enum _Mode { login, signup, forgot }

/// Self-contained auth flow. Switches between login / signup / forgot via
/// internal state (no route pushes) so the root gate can swap it out cleanly
/// once a session exists.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  _Mode _mode = _Mode.login;
  void _go(_Mode m) => setState(() => _mode = m);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_mode),
        child: switch (_mode) {
          _Mode.login => _LoginForm(onSignup: () => _go(_Mode.signup), onForgot: () => _go(_Mode.forgot)),
          _Mode.signup => _SignupForm(onLogin: () => _go(_Mode.login)),
          _Mode.forgot => _ForgotForm(onBack: () => _go(_Mode.login)),
        },
      ),
    );
  }
}

bool _validEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

// ---------------------------------------------------------------- Login

class _LoginForm extends StatefulWidget {
  final VoidCallback onSignup;
  final VoidCallback onForgot;
  const _LoginForm({required this.onSignup, required this.onForgot});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _emailErr, _passErr;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailErr = _validEmail(_email.text) ? null : 'Enter a valid email address';
    final passErr = _password.text.length >= 6 ? null : 'Password must be at least 6 characters';
    setState(() {
      _emailErr = emailErr;
      _passErr = passErr;
    });
    if (emailErr != null || passErr != null) return;
    setState(() => _busy = true);
    await context.read<AuthController>().signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return AuthScaffold(
      children: [
        const Align(alignment: Alignment.centerLeft, child: AuthBrandMark()),
        const SizedBox(height: 40),
        const AuthHero(title: 'Welcome back', subtitle: 'Log in to keep tracking your eye drops.'),
        const SizedBox(height: 28),
        AuthCard(
          children: [
            AuthField(
              label: 'Email',
              controller: _email,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              errorText: _emailErr,
              onChanged: (_) => _emailErr == null ? null : setState(() => _emailErr = null),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Password',
              controller: _password,
              hint: '••••••••',
              password: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: _passErr,
              onChanged: (_) => _passErr == null ? null : setState(() => _passErr = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: _ForgotLink(onTap: widget.onForgot)),
          ],
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Log in', loadingLabel: 'Signing in…', loading: _busy, onPressed: _submit),
        const SizedBox(height: 22),
        const AuthDivider(),
        const SizedBox(height: 22),
        SocialButton(kind: SocialKind.google, onTap: auth.signInWithGoogle),
        const SizedBox(height: 12),
        SocialButton(kind: SocialKind.apple, onTap: auth.signInWithApple),
        const SizedBox(height: 24),
        AuthSwitchRow(prompt: "Don't have an account?", action: 'Sign up', onTap: widget.onSignup),
      ],
    );
  }
}

// ---------------------------------------------------------------- Signup

class _SignupForm extends StatefulWidget {
  final VoidCallback onLogin;
  const _SignupForm({required this.onLogin});

  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _nameErr, _emailErr, _passErr;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nameErr = _name.text.trim().isEmpty ? 'Please enter your name' : null;
    final emailErr = _validEmail(_email.text) ? null : 'Enter a valid email address';
    final passErr = _password.text.length >= 6 ? null : 'Password must be at least 6 characters';
    setState(() {
      _nameErr = nameErr;
      _emailErr = emailErr;
      _passErr = passErr;
    });
    if (nameErr != null || emailErr != null || passErr != null) return;
    setState(() => _busy = true);
    await context.read<AuthController>().signUp(name: _name.text, email: _email.text, password: _password.text);
    if (mounted) await context.read<DropStore>().updateUser(firstName: _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final ok = _password.text.length >= 6;
    return AuthScaffold(
      children: [
        const Align(alignment: Alignment.centerLeft, child: AuthBrandMark()),
        const SizedBox(height: 40),
        const AuthHero(title: 'Create account', subtitle: 'Start tracking your eye-drop schedule with confidence.'),
        const SizedBox(height: 28),
        AuthCard(
          children: [
            AuthField(
              label: 'Name',
              controller: _name,
              hint: 'Your first name',
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
              errorText: _nameErr,
              onChanged: (_) => _nameErr == null ? null : setState(() => _nameErr = null),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Email',
              controller: _email,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              errorText: _emailErr,
              onChanged: (_) => _emailErr == null ? null : setState(() => _emailErr = null),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Password',
              controller: _password,
              hint: 'At least 6 characters',
              password: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _passErr,
              onChanged: (_) => setState(() => _passErr = null),
              onSubmitted: (_) => _submit(),
              helper: _StrengthHint(ok: ok),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Create account', loadingLabel: 'Creating account…', loading: _busy, onPressed: _submit),
        const SizedBox(height: 22),
        const AuthDivider(),
        const SizedBox(height: 22),
        SocialButton(kind: SocialKind.google, onTap: auth.signInWithGoogle),
        const SizedBox(height: 12),
        SocialButton(kind: SocialKind.apple, onTap: auth.signInWithApple),
        const SizedBox(height: 24),
        AuthSwitchRow(prompt: 'Already have an account?', action: 'Log in', onTap: widget.onLogin),
      ],
    );
  }
}

// ---------------------------------------------------------------- Forgot

class _ForgotForm extends StatefulWidget {
  final VoidCallback onBack;
  const _ForgotForm({required this.onBack});

  @override
  State<_ForgotForm> createState() => _ForgotFormState();
}

class _ForgotFormState extends State<_ForgotForm> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _emailErr;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_validEmail(_email.text)) {
      setState(() => _emailErr = 'Enter a valid email address');
      return;
    }
    setState(() {
      _emailErr = null;
      _busy = true;
    });
    final ok = await context.read<AuthController>().sendPasswordReset(_email.text);
    if (mounted) setState(() { _busy = false; _sent = ok; });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: Semantics(
        button: true,
        label: 'Back',
        child: InkResponse(
          radius: 26,
          onTap: widget.onBack,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AuthColors.surfaceVariant, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_rounded, size: 22, color: AuthColors.textPrimary),
          ),
        ),
      ),
      children: [
        AuthHero(
          title: _sent ? 'Check your email' : 'Reset password',
          subtitle: _sent
              ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
              : 'Enter your email and we\'ll send you a link to reset your password.',
        ),
        const SizedBox(height: 28),
        if (!_sent) ...[
          AuthCard(
            children: [
              AuthField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                errorText: _emailErr,
                onChanged: (_) => _emailErr == null ? null : setState(() => _emailErr = null),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Send reset link', loadingLabel: 'Sending…', loading: _busy, onPressed: _submit),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AuthColors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: AuthColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Follow the link in the email to choose a new password.',
                      style: AppTypography.body(14.5, weight: FontWeight.w500, color: AuthColors.textPrimary, height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Back to log in', onPressed: widget.onBack),
        ],
      ],
    );
  }
}

// ---- small pieces ----------------------------------------------------------

class _ForgotLink extends StatefulWidget {
  final VoidCallback onTap;
  const _ForgotLink({required this.onTap});
  @override
  State<_ForgotLink> createState() => _ForgotLinkState();
}

class _ForgotLinkState extends State<_ForgotLink> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerRight,
        child: Opacity(
          opacity: _down ? 0.6 : 1,
          child: Text('Forgot password?',
              style: AppTypography.body(14.5,
                  weight: FontWeight.w600, color: _down ? AuthColors.primaryDark : const Color(0xFF174B7A))),
        ),
      ),
    );
  }
}

class _StrengthHint extends StatelessWidget {
  final bool ok;
  const _StrengthHint({required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AuthColors.success : AuthColors.placeholder;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: color),
        const SizedBox(width: 5),
        Text('6+ characters', style: AppTypography.body(12.5, weight: FontWeight.w500, color: color)),
      ],
    );
  }
}
