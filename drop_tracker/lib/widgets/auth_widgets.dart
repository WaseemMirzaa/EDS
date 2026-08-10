import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'drop_logo.dart';

/// Premium healthcare auth palette (spec §2) — kept local so the rest of the
/// app's tokens are untouched.
class AuthColors {
  AuthColors._();
  static const primary = Color(0xFF173F68);
  static const primaryDark = Color(0xFF123554);
  static const primaryContainer = Color(0xFFE8F1F8);
  static const secondary = Color(0xFF6D8197);
  static const background = Color(0xFFFBFCFD);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF3F6F8);
  static const outline = Color(0xFFD9E1E8);
  static const outlineVariant = Color(0xFFE8EDF1);
  static const textPrimary = Color(0xFF142B45);
  static const textSecondary = Color(0xFF6B7D90);
  static const label = Color(0xFF52677C);
  static const placeholder = Color(0xFF9AA9B8);
  static const gold = Color(0xFFE9B83F);
  static const goldSoft = Color(0xFFFFF4D8);
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF287A52);
  static const fieldBorder = Color(0xFFDCE4EA);
  static const disabled = Color(0xFFC9D3DC);
  static const dividerLine = Color(0xFFE0E6EB);
}

/// Responsive, keyboard-aware auth layout: centred on large screens, scrollable
/// on small ones, content capped at 420dp, with a whisper-soft top tint.
class AuthScaffold extends StatelessWidget {
  final List<Widget> children;
  /// Optional control pinned to the top-left (e.g. a back button), kept out of
  /// the vertically-centred content so it stays at the top.
  final Widget? leading;
  const AuthScaffold({super.key, required this.children, this.leading});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          // Extremely subtle radial tint around the top brand area.
          Positioned(
            top: -160,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 420,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [Color(0xFFF1F7FC), Color(0x00FBFCFD)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, leading != null ? 56 : 20, 24, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - (leading != null ? 84 : 48)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Pinned top-left control (independent of the centred content).
          if (leading != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: leading),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact circular brand mark (spec §4): 68dp, soft container, thin navy ring,
/// minimal gold drop.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: const BoxDecoration(color: AuthColors.primaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const DropBadge(size: 46, ringColor: AuthColors.primary, dropColor: AuthColors.gold),
    );
  }
}

/// Hero heading + subtitle (spec §5).
class AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthHero({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTypography.display(33, weight: FontWeight.w800, color: AuthColors.textPrimary, letterSpacing: -0.7)),
        const SizedBox(height: 10),
        Text(subtitle,
            style: AppTypography.body(17, weight: FontWeight.w400, color: AuthColors.textSecondary, height: 1.4)),
      ],
    );
  }
}

/// Subtle authentication surface (spec §6).
class AuthCard extends StatelessWidget {
  final List<Widget> children;
  const AuthCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AuthColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AuthColors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Premium labelled outlined field (spec §7–§10, §25, §27).
class AuthField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool password;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final Widget? helper;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.password = false,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.autofillHints,
    this.errorText,
    this.helper,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _focused = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AuthColors.error
        : _focused
            ? AuthColors.primary
            : AuthColors.fieldBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTypography.body(15, weight: FontWeight.w600, color: AuthColors.label)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 58,
          decoration: BoxDecoration(
            color: _focused && !hasError ? const Color(0xFFFCFDFE) : AuthColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: _focused || hasError ? 2 : 1),
            boxShadow: _focused && !hasError
                ? [BoxShadow(color: AuthColors.primary.withValues(alpha: 0.10), blurRadius: 8, spreadRadius: 0.5)]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.password && _obscure,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.capitalization,
                  autofillHints: widget.autofillHints,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  cursorColor: AuthColors.primary,
                  style: AppTypography.body(16.5, weight: FontWeight.w500, color: AuthColors.textPrimary),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: AppTypography.body(16.5, weight: FontWeight.w400, color: AuthColors.placeholder),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 17),
                  ),
                ),
              ),
              if (widget.password)
                Semantics(
                  button: true,
                  label: _obscure ? 'Show password' : 'Hide password',
                  child: InkResponse(
                    onTap: () => setState(() => _obscure = !_obscure),
                    radius: 24,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 22,
                        color: _focused ? AuthColors.primary : AuthColors.placeholder,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 7, left: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 15, color: AuthColors.error),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(widget.errorText!,
                            style: AppTypography.body(13, weight: FontWeight.w500, color: AuthColors.error)),
                      ),
                    ],
                  ),
                )
              : (widget.helper != null
                  ? Padding(padding: const EdgeInsets.only(top: 7, left: 2), child: widget.helper!)
                  : const SizedBox.shrink()),
        ),
      ],
    );
  }
}

/// Primary CTA (spec §12–§13): scale-press, states, loading label.
class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel = 'Please wait…',
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final bg = disabled
        ? AuthColors.disabled
        : _down
            ? AuthColors.primaryDark
            : AuthColors.primary;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.loading ? widget.loadingLabel : widget.label,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _down = true),
        onTapUp: disabled ? null : (_) => setState(() => _down = false),
        onTapCancel: disabled ? null : () => setState(() => _down = false),
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: disabled
                  ? null
                  : [BoxShadow(color: AuthColors.primary.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -4)],
            ),
            child: widget.loading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                      const SizedBox(width: 12),
                      Text(widget.loadingLabel,
                          style: AppTypography.body(17, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  )
                : Text(widget.label, style: AppTypography.body(17.5, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// "──── or ────" (spec §14).
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthColors.dividerLine, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: AppTypography.body(14, weight: FontWeight.w500, color: AuthColors.placeholder)),
        ),
        const Expanded(child: Divider(color: AuthColors.dividerLine, thickness: 1)),
      ],
    );
  }
}

enum SocialKind { google, apple }

/// Social auth buttons (spec §15–§16): identical dimensions, centred icon+text.
class SocialButton extends StatefulWidget {
  final SocialKind kind;
  final bool loading;
  final VoidCallback onTap;
  const SocialButton({super.key, required this.kind, required this.onTap, this.loading = false});

  @override
  State<SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<SocialButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final isApple = widget.kind == SocialKind.apple;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isApple ? AuthColors.textPrimary : AuthColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: isApple ? null : Border.all(color: AuthColors.fieldBorder, width: 1.2),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: isApple ? Colors.white : AuthColors.primary),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 22, height: 22, child: isApple ? const Icon(Icons.apple, size: 22, color: Colors.white) : const GoogleG()),
                    const SizedBox(width: 12),
                    Text('Continue with ${isApple ? 'Apple' : 'Google'}',
                        style: AppTypography.body(16.5,
                            weight: FontWeight.w600, color: isApple ? Colors.white : AuthColors.textPrimary)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Official 4-colour Google "G" mark.
class GoogleG extends StatelessWidget {
  const GoogleG({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(22, 22), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final stroke = size.width * 0.22;
    final rect = Rect.fromCircle(center: c, radius: r - stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    double d(double deg) => deg * math.pi / 180;
    // Red (top), yellow (left), green (bottom), blue (right) arcs.
    canvas.drawArc(rect, d(-40), d(95), false, p..color = _red);
    canvas.drawArc(rect, d(55), d(90), false, p..color = _yellow);
    canvas.drawArc(rect, d(145), d(88), false, p..color = _green);
    canvas.drawArc(rect, d(-15), d(-70), false, p..color = _blue);
    // Blue cross-bar into the centre.
    final bar = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(c.dx, c.dy - stroke / 2, r - stroke / 2, stroke), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom account switcher (spec §17).
class AuthSwitchRow extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;
  const AuthSwitchRow({super.key, required this.prompt, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: AppTypography.body(15, weight: FontWeight.w500, color: AuthColors.textSecondary)),
        const SizedBox(width: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(action, style: AppTypography.body(15, weight: FontWeight.w700, color: AuthColors.primary)),
          ),
        ),
      ],
    );
  }
}
