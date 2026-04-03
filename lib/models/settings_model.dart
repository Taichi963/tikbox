import 'dart:convert';

/// アプリ全体の設定モデル（Phase2フィールド保持 + Phase3 TTS追加）
class SettingsModel {
  // ── Phase2: 表示・動作設定 ────────────────────────────────
  final bool showHistory;          // 読み上げ履歴をメイン画面に表示
  final bool backgroundMode;       // バックグラウンド動作
  final List<String> soundWords;   // 効果音ワード一覧

  // ── Phase3: 表示設定 ─────────────────────────────────────
  final bool showUserName;
  final bool showGifts;
  final bool keepScreenOn;         // Phase2の wakelock に相当
  final int maxDisplayComments;

  // ── Phase3: TTS 基本設定 ──────────────────────────────────
  final bool ttsEnabled;
  final String ttsLanguage;
  final double ttsRate;            // Phase2の speed に相当
  final double ttsPitch;
  final double ttsVolume;          // Phase2の volume に相当

  // ── Phase3: TTS 読み上げ対象 ─────────────────────────────
  final bool ttsReadComments;
  final bool ttsReadGifts;         // Phase2の readGift に相当
  final bool ttsIncludeUserName;   // Phase2の readUsername に相当
  final int ttsMinLength;
  final int ttsMaxLength;

  // ── Phase3: TTS キュー設定 ───────────────────────────────
  final bool ttsAutoStart;
  final int ttsMaxQueueSize;
  final bool ttsClearOnStop;

  const SettingsModel({
    this.showHistory = true,
    this.backgroundMode = false,
    this.soundWords = const [],
    this.showUserName = true,
    this.showGifts = true,
    this.keepScreenOn = true,
    this.maxDisplayComments = 100,
    this.ttsEnabled = true,
    this.ttsLanguage = 'ja-JP',
    this.ttsRate = 1.0,
    this.ttsPitch = 1.0,
    this.ttsVolume = 1.0,
    this.ttsReadComments = true,
    this.ttsReadGifts = true,
    this.ttsIncludeUserName = true,
    this.ttsMinLength = 1,
    this.ttsMaxLength = 50,
    this.ttsAutoStart = true,
    this.ttsMaxQueueSize = 30,
    this.ttsClearOnStop = false,
  });

  SettingsModel copyWith({
    bool? showHistory,
    bool? backgroundMode,
    List<String>? soundWords,
    bool? showUserName,
    bool? showGifts,
    bool? keepScreenOn,
    int? maxDisplayComments,
    bool? ttsEnabled,
    String? ttsLanguage,
    double? ttsRate,
    double? ttsPitch,
    double? ttsVolume,
    bool? ttsReadComments,
    bool? ttsReadGifts,
    bool? ttsIncludeUserName,
    int? ttsMinLength,
    int? ttsMaxLength,
    bool? ttsAutoStart,
    int? ttsMaxQueueSize,
    bool? ttsClearOnStop,
  }) {
    return SettingsModel(
      showHistory: showHistory ?? this.showHistory,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      soundWords: soundWords ?? this.soundWords,
      showUserName: showUserName ?? this.showUserName,
      showGifts: showGifts ?? this.showGifts,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      maxDisplayComments: maxDisplayComments ?? this.maxDisplayComments,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsReadComments: ttsReadComments ?? this.ttsReadComments,
      ttsReadGifts: ttsReadGifts ?? this.ttsReadGifts,
      ttsIncludeUserName: ttsIncludeUserName ?? this.ttsIncludeUserName,
      ttsMinLength: ttsMinLength ?? this.ttsMinLength,
      ttsMaxLength: ttsMaxLength ?? this.ttsMaxLength,
      ttsAutoStart: ttsAutoStart ?? this.ttsAutoStart,
      ttsMaxQueueSize: ttsMaxQueueSize ?? this.ttsMaxQueueSize,
      ttsClearOnStop: ttsClearOnStop ?? this.ttsClearOnStop,
    );
  }

  Map<String, dynamic> toJson() => {
        'showHistory': showHistory,
        'backgroundMode': backgroundMode,
        'soundWords': soundWords,
        'showUserName': showUserName,
        'showGifts': showGifts,
        'keepScreenOn': keepScreenOn,
        'maxDisplayComments': maxDisplayComments,
        'ttsEnabled': ttsEnabled,
        'ttsLanguage': ttsLanguage,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'ttsVolume': ttsVolume,
        'ttsReadComments': ttsReadComments,
        'ttsReadGifts': ttsReadGifts,
        'ttsIncludeUserName': ttsIncludeUserName,
        'ttsMinLength': ttsMinLength,
        'ttsMaxLength': ttsMaxLength,
        'ttsAutoStart': ttsAutoStart,
        'ttsMaxQueueSize': ttsMaxQueueSize,
        'ttsClearOnStop': ttsClearOnStop,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        showHistory: json['showHistory'] as bool? ?? true,
        backgroundMode: json['backgroundMode'] as bool? ?? false,
        soundWords: (json['soundWords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        showUserName: json['showUserName'] as bool? ?? true,
        showGifts: json['showGifts'] as bool? ?? true,
        keepScreenOn: json['keepScreenOn'] as bool? ?? true,
        maxDisplayComments: json['maxDisplayComments'] as int? ?? 100,
        ttsEnabled: json['ttsEnabled'] as bool? ?? true,
        ttsLanguage: json['ttsLanguage'] as String? ?? 'ja-JP',
        ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 1.0,
        ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
        ttsVolume: (json['ttsVolume'] as num?)?.toDouble() ?? 1.0,
        ttsReadComments: json['ttsReadComments'] as bool? ?? true,
        ttsReadGifts: json['ttsReadGifts'] as bool? ?? true,
        ttsIncludeUserName: json['ttsIncludeUserName'] as bool? ?? true,
        ttsMinLength: json['ttsMinLength'] as int? ?? 1,
        ttsMaxLength: json['ttsMaxLength'] as int? ?? 50,
        ttsAutoStart: json['ttsAutoStart'] as bool? ?? true,
        ttsMaxQueueSize: json['ttsMaxQueueSize'] as int? ?? 30,
        ttsClearOnStop: json['ttsClearOnStop'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory SettingsModel.fromJsonString(String jsonString) =>
      SettingsModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
