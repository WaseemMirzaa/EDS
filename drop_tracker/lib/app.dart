import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth_controller.dart';
import 'data/drop_store.dart';
import 'data/notification_service.dart';
import 'screens/auth/auth_flow.dart';
import 'screens/auth/new_password_screen.dart';
import 'screens/background_reliability_screen.dart';
import 'screens/battery_permission_screen.dart';
import 'screens/exact_alarm_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/splash_screen.dart';
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
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(gradient: BrandColors.pageGradient),
        child: child,
      ),
      home: const _RootGate(),
    );
  }
}

/// Cold-start gate: splash → mandatory permissions → auth/home.
/// Logged-in users with a restored session land on home after splash
/// (and after any missing OS permissions are granted).
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> with WidgetsBindingObserver {
  bool _splashElapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splashElapsed = true);
    });
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
      final auth = context.read<AuthController>();
      // Re-check OS grants — if the user revoked one in Settings, re-gate.
      auth.refreshPermissionStatus();
      NotificationService.instance
          .rescheduleAll(store.medications, store.user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DropStore>();
    final auth = context.watch<AuthController>();

    // Hold splash until session + permission status are loaded and min time passes.
    if (!store.loaded || !auth.loaded || !_splashElapsed) {
      return const SplashScreen();
    }

    // The user just opened the app via a "reset your password" email link —
    // let them finish that before anything else, including the permission
    // gate (they may not have granted anything yet on a fresh install).
    if (auth.passwordRecoveryPending) return const NewPasswordScreen();

    // Mandatory: notifications (all platforms), then exact-alarm scheduling
    // and battery unrestricted (Android only), then OEM-specific
    // background-kill guidance (Android only, and only on manufacturers
    // actually known to need it — see DeviceReliabilityService). Exact
    // alarms specifically: confirmed on a real device that skipping this
    // silently downgrades every reminder to an inexact alarm the OS can
    // delay indefinitely — this is not optional for a medication app.
    if (!auth.permissionsDone) return const PermissionScreen();
    if (Platform.isAndroid && !auth.exactAlarmsDone) {
      return const ExactAlarmScreen();
    }
    if (Platform.isAndroid && !auth.batteryDone) {
      return const BatteryPermissionScreen();
    }
    if (Platform.isAndroid && !auth.backgroundReliabilityDone) {
      return const BackgroundReliabilityScreen();
    }

    // Restored session → home (or onboarding if first run for this account).
    if (!auth.signedIn) return const AuthFlow();
    if (!store.user.onboarded) return const OnboardingScreen();
    return const HomeShell();
  }
}
