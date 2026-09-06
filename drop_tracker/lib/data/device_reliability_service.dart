import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'permission_service.dart';

/// Detects OEM-level background-kill behaviour beyond stock Android's own
/// Doze/App Standby, and drives the mandatory in-app guidance for it.
///
/// Several major Android manufacturers ship a custom "battery manager" on
/// top of stock Android that can silently stop a background app — killing
/// scheduled alarms and notification delivery — even when the app has every
/// standard Android permission granted (POST_NOTIFICATIONS, exact alarms,
/// `PowerManager.isIgnoringBatteryOptimizations`). None of that is
/// controllable or even *queryable* through a public API; there is no
/// `Autostart.isEnabled()`. The only way an app can improve its odds is:
/// detect the OEM, explain what to do, deep-link to the OEM's own settings
/// screen where possible, and have the user confirm they did it — the same
/// approach documented at https://dontkillmyapp.com and used by most
/// reminder/alarm apps in practice.
class DeviceReliabilityService {
  DeviceReliabilityService._();
  static final DeviceReliabilityService instance =
      DeviceReliabilityService._();

  static const _ackKey = 'droptracker_bg_reliability_ack';

  /// OEM families with well-documented aggressive background-kill behaviour.
  /// Matched against both `manufacturer` and `brand` (sub-brands like Redmi/
  /// POCO/Honor/Realme report their own brand but the parent's manufacturer,
  /// or vice versa depending on the build).
  static const _aggressiveOems = {
    'xiaomi', 'redmi', 'poco', // MIUI / HyperOS
    'huawei', 'honor', // EMUI / MagicUI
    'oppo', 'realme', // ColorOS
    'vivo', 'iqoo', // FuntouchOS / OriginOS
    'oneplus', // OxygenOS (ColorOS-based on newer models)
    'meizu', 'asus',
  };

  static const _miuiOems = {'xiaomi', 'redmi', 'poco'};

  String _manufacturer = '';
  String _brand = '';
  bool _detected = false;

  Future<void> detect() async {
    if (_detected) return;
    if (!Platform.isAndroid) {
      _detected = true;
      return;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _manufacturer = info.manufacturer.toLowerCase();
      _brand = info.brand.toLowerCase();
    } catch (e) {
      debugPrint('DeviceReliabilityService.detect failed: $e');
    }
    _detected = true;
  }

  bool _matches(Set<String> oems) =>
      oems.any((oem) => _manufacturer.contains(oem) || _brand.contains(oem));

  /// Whether this device's OEM is known to need manual background-kill
  /// opt-out beyond what Android's own permission dialogs cover.
  bool get needsManualBackgroundSetup =>
      Platform.isAndroid && _matches(_aggressiveOems);

  bool get isMiuiFamily => Platform.isAndroid && _matches(_miuiOems);

  /// Best-effort display name for the instructions ("Xiaomi", "OPPO", ...).
  String get oemLabel {
    if (isMiuiFamily) return 'Xiaomi';
    if (_matches({'huawei', 'honor'})) return 'Huawei';
    if (_matches({'oppo', 'realme'})) return 'OPPO';
    if (_matches({'vivo', 'iqoo'})) return 'Vivo';
    if (_matches({'oneplus'})) return 'OnePlus';
    if (_matches({'asus'})) return 'Asus';
    if (_matches({'meizu'})) return 'Meizu';
    return 'this device';
  }

  Future<bool> acknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ackKey) ?? false;
  }

  Future<void> acknowledge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ackKey, true);
  }

  /// Test/debug seam and "Restart onboarding"-style reset — lets the gate be
  /// shown again deliberately.
  Future<void> resetAcknowledgement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ackKey);
  }

  /// Well-known (undocumented, OEM-specific, and not guaranteed stable
  /// across firmware versions — hence the fallback chain) autostart /
  /// background-permission manager activities. Tries each in turn and stops
  /// at the first that actually launches.
  static const _autostartActivities = <List<String>>[
    ['com.miui.securitycenter',
      'com.miui.permcenter.autostart.AutoStartManagementActivity'],
    ['com.coloros.safecenter',
      'com.coloros.safecenter.permission.startup.StartupAppListActivity'],
    ['com.oppo.safe',
      'com.oppo.safe.permission.startup.StartupAppListActivity'],
    ['com.iqoo.secure',
      'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'],
    ['com.vivo.permissionmanager',
      'com.vivo.permissionmanager.activity.BgStartUpManagerActivity'],
    ['com.huawei.systemmanager',
      'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity'],
    ['com.asus.mobilemanager',
      'com.asus.mobilemanager.autostart.AutoStartActivity'],
  ];

  /// Opens the OEM's autostart/background-permission screen if a known one
  /// exists on this build, otherwise falls back to the app's own system
  /// settings page (the one surface guaranteed to exist everywhere).
  Future<void> openAutostartSettings() async {
    if (!Platform.isAndroid) return;
    for (final activity in _autostartActivities) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: activity[0],
          componentName: activity[1],
          flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
        );
        await intent.launch();
        return;
      } catch (_) {
        continue;
      }
    }
    await PermissionService.instance.openSystemSettings();
  }

  /// Opens the OEM's battery-saver "choose apps" screen when a known one
  /// exists, otherwise the app's own battery settings page (which the
  /// mandatory [BatteryPermissionScreen] step already points at via
  /// [PermissionService.requestUnrestrictedBattery] / system Settings).
  Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;
    if (isMiuiFamily) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.miui.powerkeeper',
          componentName:
              'com.miui.powerkeeper.ui.HiddenAppsConfigActivity',
          flags: <int>[268435456],
        );
        await intent.launch();
        return;
      } catch (_) {}
    }
    await PermissionService.instance.openSystemSettings();
  }
}
