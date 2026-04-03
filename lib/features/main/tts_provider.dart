import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tts_settings.dart';
import '../../services/effect_sound_service.dart';
import '../../services/tts_service.dart';
import '../premium/premium_provider.dart';

const String _ttsSettingsKey = 'tikbox_tts_settings_v1';

class TtsSettingsNotifier extends Notifier<TtsSettings> {
  SharedPreferences? _prefs;

  @override
  TtsSettings build() {
    _load();
    return const TtsSettings();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_ttsSettingsKey);
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
    settings = settings.copyWith(availableVoices: voices);

    state = settings;
    effectSoundService.setVolume(settings.effectVolume);
    await ttsService.applySettings(settings);
  }

  Future<void> _persist(TtsSettings settings) async {
    state = settings;
    await _prefs?.setString(_ttsSettingsKey, jsonEncode(settings.toJson()));
    effectSoundService.setVolume(settings.effectVolume);
    await ttsService.applySettings(settings);
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

  Future<void> setBroadcastModeEnabled(bool enabled) async {
    final next = enabled
        ? state.copyWith(
            broadcastModeEnabled: true,
            ttsVolume: state.ttsVolume < 0.95 ? 0.95 : state.ttsVolume,
            effectVolume:
                state.effectVolume < 0.9 ? 0.9 : state.effectVolume,
          )
        : state.copyWith(broadcastModeEnabled: false);
    await _persist(next);
  }

  Future<void> applyBroadcastClarityPreset() async {
    await _persist(
      state.copyWith(
        broadcastModeEnabled: true,
        rate: 0.58,
        pitch: 1.18,
        ttsVolume: 1.0,
        effectVolume: 0.82,
      ),
    );
  }

  Future<void> applyBroadcastBalancedPreset() async {
    await _persist(
      state.copyWith(
        broadcastModeEnabled: true,
        rate: 0.5,
        pitch: 1.05,
        ttsVolume: 0.92,
        effectVolume: 0.72,
      ),
    );
  }

  Future<void> setCommentVoice(Map<String, String>? voice) async {
    if (!ref.read(premiumProvider.notifier).canUseVoice(voice)) {
      ref
          .read(premiumProvider.notifier)
          .showUpgradePrompt('高品質ボイスはプレミアム限定です');
      return;
    }
    await _persist(
      voice == null
          ? state.copyWith(clearCommentVoice: true)
          : state.copyWith(commentVoice: voice),
    );
  }

  Future<void> setGiftVoice(Map<String, String>? voice) async {
    if (!ref.read(premiumProvider.notifier).canUseVoice(voice)) {
      ref
          .read(premiumProvider.notifier)
          .showUpgradePrompt('ギフト専用ボイスはプレミアムで解放されます');
      return;
    }
    await _persist(
      voice == null
          ? state.copyWith(clearGiftVoice: true)
          : state.copyWith(giftVoice: voice),
    );
  }

  Future<void> refreshVoices() async {
    final voices = await ttsService.getAvailableVoices();
    await _persist(state.copyWith(availableVoices: voices));
  }

  Future<void> testCurrentVoice() async {
    await ttsService.enqueue(
      '読み上げ設定のテストです',
      priority: 50,
      voice: state.commentVoice,
    );
  }

  Future<void> testGiftVoice() async {
    await ttsService.enqueueFirst(
      'ギフト読み上げのテストです',
      priority: 200,
      voice: state.giftVoice ?? state.commentVoice,
    );
  }

  Future<void> testBroadcastMode() async {
    await ttsService.enqueueFirst(
      '配信向け出力モードをテスト中です。視聴者に聞こえやすいよう音量と出力を調整しています。',
      priority: 400,
      voice: state.commentVoice,
    );
  }
}

final ttsSettingsProvider =
    NotifierProvider<TtsSettingsNotifier, TtsSettings>(
  TtsSettingsNotifier.new,
);
