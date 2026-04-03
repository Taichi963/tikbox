import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/settings_model.dart';

const _kSettingsKey = 'tikbox_settings_v3';

class SettingsNotifier extends Notifier<SettingsModel> {
  SharedPreferences? _prefs;
  bool _disposed = false;
  Timer? _saveDebounce;

  @override
  SettingsModel build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      if (_saveDebounce?.isActive == true) _flushSave();
      _saveDebounce?.cancel();
    });
    _load();
    return const SettingsModel();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    final jsonStr = _prefs!.getString(_kSettingsKey);
    if (jsonStr != null) {
      try {
        state = SettingsModel.fromJsonString(jsonStr);
      } catch (_) {
        state = const SettingsModel();
      }
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), _flushSave);
  }

  void _flushSave() {
    _prefs?.setString(_kSettingsKey, state.toJsonString());
  }

  Future<void> update(SettingsModel updated) async {
    state = updated;
    _scheduleSave();
  }

  Future<void> _updateImmediate(SettingsModel updated) async {
    state = updated;
    _saveDebounce?.cancel();
    _flushSave();
  }

  // ─── Phase2: スイッチ系 ───────────────────────────────────

  /// Phase2互換: バックグラウンド動作
  Future<void> setBackgroundMode(bool v) =>
      _updateImmediate(state.copyWith(backgroundMode: v));

  /// Phase2互換: 履歴表示
  Future<void> setShowHistory(bool v) =>
      _updateImmediate(state.copyWith(showHistory: v));

  /// Phase2互換: ウェイクロック → keepScreenOn
  Future<void> setWakelock(bool v) =>
      _updateImmediate(state.copyWith(keepScreenOn: v));

  /// Phase2互換: ギフト読み上げ → ttsReadGifts
  Future<void> setReadGift(bool v) =>
      _updateImmediate(state.copyWith(ttsReadGifts: v));

  /// Phase2互換: ユーザー名読み上げ → ttsIncludeUserName
  Future<void> setReadUsername(bool v) =>
      _updateImmediate(state.copyWith(ttsIncludeUserName: v));

  /// Phase2互換: 効果音ワード追加
  Future<void> addSoundWord(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return Future.value();
    if (state.soundWords.contains(trimmed)) return Future.value();
    return _updateImmediate(
        state.copyWith(soundWords: [...state.soundWords, trimmed]));
  }

  /// Phase2互換: 効果音ワード削除
  Future<void> removeSoundWord(String word) =>
      _updateImmediate(state.copyWith(
          soundWords: state.soundWords.where((w) => w != word).toList()));

  // ─── Phase2: スライダー系 ─────────────────────────────────

  /// Phase2互換: 速度 → ttsRate
  Future<void> setSpeed(double v) => update(state.copyWith(ttsRate: v));

  /// Phase2互換: 音量 → ttsVolume
  Future<void> setVolume(double v) => update(state.copyWith(ttsVolume: v));

  // ─── Phase3: スイッチ系（即時保存）──────────────────────────

  Future<void> setShowUserName(bool v) =>
      _updateImmediate(state.copyWith(showUserName: v));
  Future<void> setShowGifts(bool v) =>
      _updateImmediate(state.copyWith(showGifts: v));
  Future<void> setKeepScreenOn(bool v) =>
      _updateImmediate(state.copyWith(keepScreenOn: v));
  Future<void> setTtsEnabled(bool v) =>
      _updateImmediate(state.copyWith(ttsEnabled: v));
  Future<void> setTtsReadComments(bool v) =>
      _updateImmediate(state.copyWith(ttsReadComments: v));
  Future<void> setTtsReadGifts(bool v) =>
      _updateImmediate(state.copyWith(ttsReadGifts: v));
  Future<void> setTtsIncludeUserName(bool v) =>
      _updateImmediate(state.copyWith(ttsIncludeUserName: v));
  Future<void> setTtsAutoStart(bool v) =>
      _updateImmediate(state.copyWith(ttsAutoStart: v));
  Future<void> setTtsClearOnStop(bool v) =>
      _updateImmediate(state.copyWith(ttsClearOnStop: v));
  Future<void> setTtsLanguage(String v) =>
      _updateImmediate(state.copyWith(ttsLanguage: v));

  // ─── Phase3: スライダー系（デバウンス保存）───────────────────

  Future<void> setMaxDisplayComments(int v) =>
      update(state.copyWith(maxDisplayComments: v));
  Future<void> setTtsRate(double v) => update(state.copyWith(ttsRate: v));
  Future<void> setTtsPitch(double v) => update(state.copyWith(ttsPitch: v));
  Future<void> setTtsVolume(double v) => update(state.copyWith(ttsVolume: v));
  Future<void> setTtsMinLength(int v) => update(state.copyWith(ttsMinLength: v));
  Future<void> setTtsMaxLength(int v) => update(state.copyWith(ttsMaxLength: v));
  Future<void> setTtsMaxQueueSize(int v) =>
      update(state.copyWith(ttsMaxQueueSize: v));

  Future<void> resetToDefault() => _updateImmediate(const SettingsModel());
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsModel>(
  SettingsNotifier.new,
);

final ttsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).ttsEnabled;
});
