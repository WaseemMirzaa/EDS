import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth_controller.dart';
import 'data/drop_store.dart';
import 'data/notification_service.dart';
import 'screens/auth/auth_flow.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permission_screen.dart';
import 'theme/app_theme.dart';
import 'theme/brand.dart';

class DropTrackerApp extends StatelessWidget {
  const DropTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drop Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // One soft page gradient sits behind every (transparent) scaffold.
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(gradient: BrandColors.pageGradient),
        child: child,
      ),
      home: const _RootGate(),
    );
  }
}

/// Chooses onboarding vs. the main shell, and keeps native reminders fresh
/// whenever the app returns to the foreground (taper steps / a new day may
/// have changed the effective schedule).
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final store = context.read<DropStore>();
      NotificationService.instance
          .rescheduleAll(store.medications, store.user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final auth = context.watch<AuthController>();
    if (!store.loaded || !auth.loaded) {
      return const Scaffold(
        backgroundColor: BrandColors.background,
        body: Center(child: CircularProgressIndicator(color: BrandColors.primary)),
      );
    }
    // Gated flow: permissions (mandatory) → auth → onboarding → home.
    if (!auth.permissionsDone) return const PermissionScreen();
    if (!auth.signedIn) return const AuthFlow();
    if (!store.user.onboarded) return const OnboardingScreen();
    return const HomeShell();
  }
}
