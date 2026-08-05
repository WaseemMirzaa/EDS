import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_controller.dart';
import '../../data/drop_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';

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
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
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
        ),
      ),
    );
  }
}

bool _validEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

void _toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_validEmail(_email.text)) return _toast(context, 'Enter a valid email address.');
    if (_password.text.length < 6) return _toast(context, 'Password must be at least 6 characters.');
    setState(() => _busy = true);
    await context.read<AuthController>().signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        const AuthHeader(title: 'Welcome back', subtitle: 'Log in to keep tracking your eye drops.'),
        const Gap(32),
        LabeledField(label: 'Email', child: AppField(controller: _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress)),
        const Gap(16),
        LabeledField(label: 'Password', child: AppField(controller: _password, hint: '••••••••', obscure: true)),
        const Gap(10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onForgot,
            child: Text('Forgot password?', style: AppTypography.body(13.5, weight: FontWeight.w700, color: BrandColors.primary)),
          ),
        ),
        const Gap(8),
        PrimaryButton(label: 'Log in', loading: _busy, onPressed: _submit),
        const Gap(20),
        const OrDivider(),
        const Gap(20),
        SocialButton(kind: SocialKind.google, onTap: auth.signInWithGoogle),
        const Gap(12),
        SocialButton(kind: SocialKind.apple, onTap: auth.signInWithApple),
        const Gap(24),
        _SwitchRow(prompt: "Don't have an account?", action: 'Sign up', onTap: widget.onSignup),
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return _toast(context, 'Please enter your name.');
    if (!_validEmail(_email.text)) return _toast(context, 'Enter a valid email address.');
    if (_password.text.length < 6) return _toast(context, 'Password must be at least 6 characters.');
    setState(() => _busy = true);
    await context.read<AuthController>().signUp(name: _name.text, email: _email.text, password: _password.text);
    if (mounted) {
      await context.read<DropStore>().updateUser(firstName: _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        const AuthHeader(title: 'Create account', subtitle: 'Start tracking your eye-drop schedule with confidence.'),
        const Gap(32),
        LabeledField(label: 'Name', child: AppField(controller: _name, hint: 'Your first name', capitalization: TextCapitalization.words)),
        const Gap(16),
        LabeledField(label: 'Email', child: AppField(controller: _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress)),
        const Gap(16),
        LabeledField(label: 'Password', child: AppField(controller: _password, hint: 'At least 6 characters', obscure: true)),
        const Gap(20),
        PrimaryButton(label: 'Create account', loading: _busy, onPressed: _submit),
        const Gap(20),
        const OrDivider(),
        const Gap(20),
        SocialButton(kind: SocialKind.google, onTap: auth.signInWithGoogle),
        const Gap(12),
        SocialButton(kind: SocialKind.apple, onTap: auth.signInWithApple),
        const Gap(24),
        _SwitchRow(prompt: 'Already have an account?', action: 'Log in', onTap: widget.onLogin),
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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_validEmail(_email.text)) return _toast(context, 'Enter a valid email address.');
    setState(() => _busy = true);
    final ok = await context.read<AuthController>().sendPasswordReset(_email.text);
    if (mounted) setState(() { _busy = false; _sent = ok; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        const Gap(16),
        AuthHeader(
          title: _sent ? 'Check your email' : 'Reset password',
          subtitle: _sent
              ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
              : 'Enter your email and we\'ll send you a reset link.',
        ),
        const Gap(32),
        if (!_sent) ...[
          LabeledField(label: 'Email', child: AppField(controller: _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress)),
          const Gap(20),
          PrimaryButton(label: 'Send reset link', loading: _busy, onPressed: _submit),
        ] else ...[
          PrimaryButton(label: 'Back to log in', icon: Icons.arrow_back_rounded, onPressed: widget.onBack),
        ],
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;
  const _SwitchRow({required this.prompt, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: AppTypography.body(14, weight: FontWeight.w500, color: BrandColors.inkSoft)),
        TextButton(
          onPressed: onTap,
          child: Text(action, style: AppTypography.body(14, weight: FontWeight.w700, color: BrandColors.primary)),
        ),
      ],
    );
  }
}
