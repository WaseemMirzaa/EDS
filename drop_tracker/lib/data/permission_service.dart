import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Native OS permission dialogs for the gates in [PermissionScreen] /
/// [BatteryPermissionScreen]. Battery unrestricted is Android-only.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Shows the system notifications prompt (iOS + Android 13+).
  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  Future<bool> notificationsGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  /// Android only — shows the system "Allow unrestricted battery usage?" dialog.
  /// Returns true when already unrestricted or the user just allowed it.
  Future<bool> requestUnrestrictedBattery() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> batteryUnrestricted() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Android 12+ (API 31+) only — a *separate* permission from notifications,
  /// granted only via a dedicated system Settings screen (there is no
  /// runtime dialog for it). Without it, every zonedSchedule call silently
  /// falls back to an *inexact* alarm, which especially on MIUI/HyperOS can
  /// be delayed by many minutes past its real due time — confirmed on a real
  /// device via `adb shell dumpsys alarm`, where a scheduled dose reminder
  /// sat overdue with a multi-minute delivery window instead of firing
  /// on time. flutter_local_notifications exposes a request-only method for
  /// this with no way to read the current status back, so this uses
  /// permission_handler's `scheduleExactAlarm` instead, which supports both.
  Future<bool> exactAlarmsGranted() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  /// Opens the "Alarms & reminders" system Settings screen for this app.
  /// Returns the up-to-date grant state — this is a navigation, not a
  /// runtime dialog, so the return value reflects whatever was true
  /// *before* the user acts; call [exactAlarmsGranted] again on resume.
  Future<bool> requestExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// Opens the app's page in system Settings (for when the user previously denied).
  Future<bool> openSystemSettings() => openAppSettings();
}
