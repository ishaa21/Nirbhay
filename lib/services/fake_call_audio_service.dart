import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for managing realistic ringing audio and haptics
/// for the Nirbhay simulated Fake Call feature.
/// 
/// IMPORTANT SAFETY & COMPLIANCE NOTE:
/// This service only provides audio for simulated in-app incoming calls designed
/// for discreet emergency evasion. It is NOT a real telephone call.
class FakeCallAudioService {
  static final FakeCallAudioService _instance = FakeCallAudioService._internal();
  factory FakeCallAudioService() => _instance;

  AudioPlayer _player;
  bool _isPlaying = false;
  double _volume = 0.8;
  Timer? _vibrationTimer;

  FakeCallAudioService._internal() : _player = AudioPlayer() {
    _initPlayer();
  }

  /// Visible for testing: inject custom AudioPlayer
  FakeCallAudioService.withPlayer(AudioPlayer player) : _player = player {
    _initPlayer();
  }

  void _initPlayer() {
    try {
      _player.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('[FakeCallAudioService] Initializing player error: $e');
    }
  }

  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  /// Set the configurable volume for ringing audio (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_isPlaying) {
      try {
        await _player.setVolume(_volume);
      } catch (e) {
        debugPrint('[FakeCallAudioService] Error setting volume: $e');
      }
    }
  }

  /// Start playing the bundled realistic ringtone and triggering haptic vibration.
  /// Stops any existing playback first to prevent overlapping or leaked audio instances.
  Future<void> startRingtone({double? volume}) async {
    // 1. Immediately stop any active playback to prevent audio leaks or overlapping streams
    await stopRingtone();

    if (volume != null) {
      _volume = volume.clamp(0.0, 1.0);
    }

    _isPlaying = true;

    // 2. Play bundled ringtone asset with looping
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      await _player.play(AssetSource('audio/ringtone.wav'));
    } catch (e) {
      // In tests or headless environments, platform channel may not be registered
      debugPrint('[FakeCallAudioService] Audio playback caught: $e');
    }

    // 3. Start synchronized haptic vibration pulses
    _startVibration();
  }

  void _startVibration() {
    _vibrationTimer?.cancel();
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!_isPlaying) {
        _vibrationTimer?.cancel();
        return;
      }
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    });
  }

  /// Immediately stop ringtone playback and vibration
  Future<void> stopRingtone() async {
    _isPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[FakeCallAudioService] Error stopping audio: $e');
    }
  }

  /// Pause audio when app goes to background / interrupted
  Future<void> pauseRingtone() async {
    if (!_isPlaying) return;
    _vibrationTimer?.cancel();
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[FakeCallAudioService] Error pausing audio: $e');
    }
  }

  /// Resume audio when app returns to foreground if simulated call still incoming
  Future<void> resumeRingtone() async {
    if (!_isPlaying) return;
    try {
      await _player.resume();
      _startVibration();
    } catch (e) {
      debugPrint('[FakeCallAudioService] Error resuming audio: $e');
    }
  }

  /// Dispose player and resources
  Future<void> dispose() async {
    await stopRingtone();
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('[FakeCallAudioService] Error disposing player: $e');
    }
  }
}
