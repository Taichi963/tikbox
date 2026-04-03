class TtsSettings {
  final double rate;
  final double pitch;
  final double ttsVolume;
  final double effectVolume;
  final String language;
  final bool broadcastModeEnabled;
  final Map<String, String>? commentVoice;
  final Map<String, String>? giftVoice;
  final List<Map<String, String>> availableVoices;

  const TtsSettings({
    this.rate = 0.5,
    this.pitch = 1.0,
    this.ttsVolume = 1.0,
    this.effectVolume = 0.85,
    this.language = 'ja-JP',
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
      language: language ?? this.language,
      broadcastModeEnabled:
          broadcastModeEnabled ?? this.broadcastModeEnabled,
      commentVoice:
          clearCommentVoice ? null : (commentVoice ?? this.commentVoice),
      giftVoice: clearGiftVoice ? null : (giftVoice ?? this.giftVoice),
      availableVoices: availableVoices ?? this.availableVoices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rate': rate,
      'pitch': pitch,
      'ttsVolume': ttsVolume,
      'effectVolume': effectVolume,
      'language': language,
      'broadcastModeEnabled': broadcastModeEnabled,
      'commentVoice': commentVoice,
      'giftVoice': giftVoice,
    };
  }

  factory TtsSettings.fromJson(Map<String, dynamic> json) {
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
      rate: (json['rate'] as num?)?.toDouble() ?? 0.5,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      ttsVolume: (json['ttsVolume'] as num?)?.toDouble() ?? 1.0,
      effectVolume: (json['effectVolume'] as num?)?.toDouble() ?? 0.85,
      language: json['language']?.toString() ?? 'ja-JP',
      broadcastModeEnabled: json['broadcastModeEnabled'] as bool? ?? false,
      commentVoice: parseVoice(json['commentVoice']),
      giftVoice: parseVoice(json['giftVoice']),
    );
  }
}
