enum SoundPreset {
  balanced('balanced', 'バランス'),
  flashy('flashy', 'ド派手'),
  gentle('gentle', 'やさしい');

  final String storageKey;
  final String label;

  const SoundPreset(this.storageKey, this.label);

  static SoundPreset fromStorageKey(String? value) {
    for (final preset in SoundPreset.values) {
      if (preset.storageKey == value) {
        return preset;
      }
    }
    return SoundPreset.balanced;
  }
}

class TtsSettings {
  static const String japaneseLanguage = 'ja-JP';

  final double rate;
  final double pitch;
  final double ttsVolume;
  final double effectVolume;
  final String language;
  final SoundPreset soundPreset;
  final bool keepScreenOn;
  final bool giftVibrationEnabled;
  final bool readUsernameEnabled;
  final bool broadcastModeEnabled;
  final Map<String, String>? commentVoice;
  final Map<String, String>? giftVoice;
  final List<Map<String, String>> availableVoices;

  const TtsSettings({
    this.rate = 0.5,
    this.pitch = 1.0,
    this.ttsVolume = 1.0,
    this.effectVolume = 0.85,
    this.language = japaneseLanguage,
    this.soundPreset = SoundPreset.balanced,
    this.keepScreenOn = true,
    this.giftVibrationEnabled = true,
    this.readUsernameEnabled = true,
    this.broadcastModeEnabled = false,
    this.commentVoice,
    this.giftVoice,
    this.availableVoices = const [],
  });

  TtsSettings copyWith({
    double? rate,
    double? pitch,
    double? ttsVolume,
    double? effectVolume,
    String? language,
    SoundPreset? soundPreset,
    bool? keepScreenOn,
    bool? giftVibrationEnabled,
    bool? readUsernameEnabled,
    bool? broadcastModeEnabled,
    Map<String, String>? commentVoice,
    Map<String, String>? giftVoice,
    List<Map<String, String>>? availableVoices,
    bool clearCommentVoice = false,
    bool clearGiftVoice = false,
  }) {
    return TtsSettings(
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      effectVolume: effectVolume ?? this.effectVolume,
      language: japaneseLanguage,
      soundPreset: soundPreset ?? this.soundPreset,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      giftVibrationEnabled: giftVibrationEnabled ?? this.giftVibrationEnabled,
      readUsernameEnabled: readUsernameEnabled ?? this.readUsernameEnabled,
      broadcastModeEnabled: broadcastModeEnabled ?? this.broadcastModeEnabled,
      commentVoice:
          clearCommentVoice ? null : (commentVoice ?? this.commentVoice),
      giftVoice: clearGiftVoice ? null : (giftVoice ?? this.giftVoice),
      availableVoices: availableVoices ?? this.availableVoices,
    );
  }

  TtsSettings applySoundPreset(SoundPreset preset) {
    switch (preset) {
      case SoundPreset.balanced:
        return copyWith(
          soundPreset: preset,
          rate: 0.5,
          pitch: 1.0,
          ttsVolume: 1.0,
          effectVolume: 0.85,
        );
      case SoundPreset.flashy:
        return copyWith(
          soundPreset: preset,
          rate: 0.55,
          pitch: 1.1,
          ttsVolume: 0.95,
          effectVolume: 1.0,
        );
      case SoundPreset.gentle:
        return copyWith(
          soundPreset: preset,
          rate: 0.48,
          pitch: 0.95,
          ttsVolume: 1.0,
          effectVolume: 0.6,
        );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'rate': rate,
      'pitch': pitch,
      'ttsVolume': ttsVolume,
      'effectVolume': effectVolume,
      'language': japaneseLanguage,
      'soundPreset': soundPreset.storageKey,
      'keepScreenOn': keepScreenOn,
      'giftVibrationEnabled': giftVibrationEnabled,
      'readUsernameEnabled': readUsernameEnabled,
      'broadcastModeEnabled': broadcastModeEnabled,
      'commentVoice': commentVoice,
      'giftVoice': giftVoice,
    };
  }

  static String voiceKey(Map<String, String> voice) =>
      '${voice['name'] ?? ''}|${voice['locale'] ?? ''}|'
      '${voice['identifier'] ?? ''}';

  factory TtsSettings.fromJson(Map<String, dynamic> json) {
    double clampedDouble(
      String key,
      double fallback,
      double min,
      double max,
    ) {
      final value = (json[key] as num?)?.toDouble() ?? fallback;
      return value.clamp(min, max).toDouble();
    }

    Map<String, String>? parseVoice(Object? value) {
      if (value is Map) {
        final map = value.map(
          (key, dynamic item) => MapEntry(key.toString(), item.toString()),
        );
        return map;
      }
      return null;
    }

    return TtsSettings(
      rate: clampedDouble('rate', 0.5, 0.3, 1.0),
      pitch: clampedDouble('pitch', 1.0, 0.5, 2.0),
      ttsVolume: clampedDouble('ttsVolume', 1.0, 0.0, 1.0),
      effectVolume: clampedDouble('effectVolume', 0.85, 0.0, 1.0),
      language: japaneseLanguage,
      soundPreset: SoundPreset.fromStorageKey(
        json['soundPreset']?.toString(),
      ),
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      giftVibrationEnabled: json['giftVibrationEnabled'] as bool? ?? true,
      readUsernameEnabled: json['readUsernameEnabled'] as bool? ?? true,
      broadcastModeEnabled: json['broadcastModeEnabled'] as bool? ?? false,
      commentVoice: parseVoice(json['commentVoice']),
      giftVoice: parseVoice(json['giftVoice']),
    );
  }
}
