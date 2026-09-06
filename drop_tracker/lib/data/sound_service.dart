import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the sounds that accompany important in-app prompts — haptics alone
/// (see TodayScreen._openConfidenceCheck) aren't audible from across a room.
///
/// Deliberately NOT built on Flutter's built-in `SystemSound.play`: its
/// Android implementation only produces sound for `SystemSoundType.click`
/// (a short key-press tick), not `.alert` — calling it with `.alert` is a
/// silent no-op on Android, which is exactly the "no sound on Android" gap
/// this service exists to close. Bundling and playing an explicit audio
/// asset works the same way on both platforms.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();

  /// Fire-and-forget by design — a sound failing to play (no audio output,
  /// asset not yet decoded, plugin not ready) must never block or crash the
  /// popup it's meant to accompany.
  Future<void> playBeep() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/beep.wav'), volume: 0.85);
    } catch (e) {
      debugPrint('SoundService.playBeep failed: $e');
    }
  }

  /// Loops the alarm clip until [stopAlarm] is called — used for the
  /// Confidence Check popup, which should keep ringing (like a real alarm)
  /// for as long as it's on screen waiting for a response, not just chirp
  /// once and go quiet.
  Future<void> playAlarm() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alarm.wav'), volume: 0.9);
    } catch (e) {
      debugPrint('SoundService.playAlarm failed: $e');
    }
  }

  /// Stops a looping alarm started by [playAlarm]. Safe to call even if
  /// nothing is playing.
  Future<void> stopAlarm() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      debugPrint('SoundService.stopAlarm failed: $e');
    }
  }
}
