import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tts_settings.dart';
import '../../services/effect_sound_service.dart';
import '../../services/tts_service.dart';

const String _ttsSettingsKey = 'tikbox_tts_settings_v1';
const String _giftSoundEnabledKey = 'tikbox_gift_sound_enabled_v1';

class TtsSettingsNotifier extends Notifier<TtsSettings> {
  Future<void>? _loadFuture;
  SharedPreferences? _prefs;
  bool _giftSoundEnabled = true;

  bool get giftSoundEnabled => _giftSoundEnabled;

  @override
  TtsSettings build() {
    _loadFuture ??= _load();
    return const TtsSettings();
  }

  Future<void> _ensureLoaded() async {
    _loadFuture ??= _load();
    await _loadFuture;
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_ttsSettingsKey);
    _giftSoundEnabled = _prefs?.getBool(_giftSoundEnabledKey) ?? true;
    TtsSettings settings = const TtsSettings();
    if (raw != null) {
      try {
        settings = TtsSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        settings = const TtsSettings();
      }
    }

    final voices = await ttsService.getAvailableVoices();
    final availableVoiceKeys = voices.map(_voiceKey).toSet();
    settings = settings.copyWith(
      availableVoices: voices,
      clearCommentVoice: !_isAvailableVoice(
        settings.commentVoice,
        availableVoiceKeys,
      ),
      clearGiftVoice: !_isAvailableVoice(
        settings.giftVoice,
        availableVoiceKeys,
      ),
    );
    await _prefs?.setString(_ttsSettingsKey, jsonEncode(settings.toJson()));

    state = settings;
    effectSoundService.setVolume(settings.effectVolume);
    effectSoundService.setGiftSoundEnabled(_giftSoundEnabled);
    await ttsService.applySettings(settings);
  }

  Future<void> _persist(TtsSettings settings) async {
    await _ensureLoaded();
    state = settings;
    await _prefs?.setString(_ttsSettingsKey, jsonEncode(settings.toJson()));
    effectSoundService.setVolume(settings.effectVolume);
    effectSoundService.setGiftSoundEnabled(_giftSoundEnabled);
    await ttsService.applySettings(settings);
  }

  Future<void> setGiftSoundEnabled(bool value) async {
    await _ensureLoaded();
    _giftSoundEnabled = value;
    state = state.copyWith();
    await _prefs?.setBool(_giftSoundEnabledKey, value);
    effectSoundService.setGiftSoundEnabled(value);
  }

  Future<void> applySoundPreset(SoundPreset preset) async {
    await _persist(state.applySoundPreset(preset));
  }

  Future<void> setRate(double rate) async {
    await _persist(state.copyWith(rate: rate.clamp(0.3, 1.0)));
  }

  Future<void> setPitch(double pitch) async {
    await _persist(state.copyWith(pitch: pitch.clamp(0.5, 2.0)));
  }

  Future<void> setTtsVolume(double volume) async {
    await _persist(state.copyWith(ttsVolume: volume.clamp(0.0, 1.0)));
  }

  Future<void> setEffectVolume(double volume) async {
    await _persist(state.copyWith(effectVolume: volume.clamp(0.0, 1.0)));
  }

  Future<void> setKeepScreenOn(bool value) async {
    await _persist(state.copyWith(keepScreenOn: value));
  }

  Future<void> setGiftVibrationEnabled(bool value) async {
    await _persist(state.copyWith(giftVibrationEnabled: value));
  }

  Future<void> setReadUsernameEnabled(bool value) async {
    await _persist(state.copyWith(readUsernameEnabled: value));
  }

  Future<void> setCommentVoice(Map<String, String>? voice) async {
    await _persist(
      voice == null ||
              !_isAvailableVoice(
                  voice, state.availableVoices.map(_voiceKey).toSet())
          ? state.copyWith(clearCommentVoice: true)
          : state.copyWith(commentVoice: voice),
    );
  }

  String _voiceKey(Map<String, String> voice) {
    return '${voice['name'] ?? ''}|${voice['locale'] ?? ''}|'
        '${voice['identifier'] ?? ''}';
  }

  bool _isAvailableVoice(
    Map<String, String>? voice,
    Set<String> availableVoiceKeys,
  ) {
    if (voice == null || voice.isEmpty) {
      return false;
    }
    return availableVoiceKeys.contains(_voiceKey(voice));
  }
}

final ttsSettingsProvider = NotifierProvider<TtsSettingsNotifier, TtsSettings>(
  TtsSettingsNotifier.new,
);
