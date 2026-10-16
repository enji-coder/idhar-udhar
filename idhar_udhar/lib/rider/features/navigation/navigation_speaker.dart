import 'package:flutter_tts/flutter_tts.dart';
import 'package:idhar_udhar/shared/maps/maps_runtime.dart';

import 'route_guidance.dart';

/// Speaks a turn once. Visual navigation continues if speech is unavailable.
class NavigationSpeaker {
  NavigationSpeaker({FlutterTts? tts, bool? enabled})
      : _tts = tts,
        _enabled = enabled ?? !MapsRuntime.isFlutterTest;

  final FlutterTts? _tts;
  final bool _enabled;
  FlutterTts? _owned;
  String? lastSpokenKey;
  bool _ready = false;
  bool _muted = false;

  bool get isMuted => _muted;

  /// Mutes or restores spoken cues. GPS and route updates are unaffected.
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) {
      await stop();
    }
  }

  Future<void> cue(GuidanceBanner? banner) async {
    if (_muted || !_enabled || banner == null) {
      return;
    }
    if (!shouldSpeakCue(banner: banner, lastSpokenKey: lastSpokenKey)) {
      return;
    }
    lastSpokenKey = banner.speechKey;
    try {
      final FlutterTts engine = await _engine();
      await engine.stop();
      await engine.speak('${banner.distanceLabel}. ${banner.instruction}');
    } catch (_) {
      lastSpokenKey = banner.speechKey;
    }
  }

  Future<void> stop() async {
    final FlutterTts? engine = _owned ?? _tts;
    if (engine == null) {
      return;
    }
    try {
      await engine.stop();
    } catch (_) {}
  }

  Future<FlutterTts> _engine() async {
    final FlutterTts engine = _tts ?? (_owned ??= FlutterTts());
    if (_ready) {
      return engine;
    }
    _ready = true;
    await engine.setLanguage('en-IN');
    await engine.setSpeechRate(0.48);
    await engine.setVolume(1);
    await engine.setQueueMode(1);
    return engine;
  }
}
