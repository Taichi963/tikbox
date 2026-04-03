import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'app_logger.dart';

class TtsQueueSnapshot {
  final bool isConnected;
  final bool isSpeaking;
  final String? username;
  final String? currentText;

  const TtsQueueSnapshot({
    required this.isConnected,
    required this.isSpeaking,
    required this.username,
    required this.currentText,
  });
}

class SpokenItem {
  final String id;
  final String text;

  const SpokenItem({
    required this.id,
    required this.text,
  });
}

class TikBoxAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isSpeaking = false;
  bool _connectionActive = false;
  String? _connectedUsername;
  SpokenItem? _currentItem;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _configureAudioSession(
      broadcastModeEnabled: false,
      volume: 1.0,
    );

    _tts.setStartHandler(() {
      _isSpeaking = true;
      _publishState();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _currentItem = null;
      _syncMediaItem();
      _publishState();
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      AppLogger.warning('Background TTS error: $message');
      _currentItem = null;
      _syncMediaItem();
      _publishState();
    });

    _initialized = true;
    _publishState();
  }

  Future<void> speakItem({
    required String text,
    required String language,
    required double rate,
    required double pitch,
    required double volume,
    required bool broadcastModeEnabled,
    Map<String, String>? voice,
  }) async {
    await ensureInitialized();
    _currentItem = SpokenItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
    );
    _syncMediaItem();
    _publishState();

    await _tts.stop();
    await _configureAudioSession(
      broadcastModeEnabled: broadcastModeEnabled,
      volume: volume,
    );
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);

    if (voice != null && voice.isNotEmpty) {
      await _tts.setVoice(voice);
    } else {
      await _tts.clearVoice();
    }

    await _tts.speak(text);
  }

  Future<void> _configureAudioSession({
    required bool broadcastModeEnabled,
    required double volume,
  }) async {
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}

    try {
      if (broadcastModeEnabled) {
        await _tts.setAudioAttributesForNavigation();
      }
    } catch (_) {}

    try {
      final options = <IosTextToSpeechAudioCategoryOptions>[
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ];
      if (broadcastModeEnabled) {
        options.add(IosTextToSpeechAudioCategoryOptions.defaultToSpeaker);
      }
      await _tts.setIosAudioCategory(
        broadcastModeEnabled
            ? IosTextToSpeechAudioCategory.playAndRecord
            : IosTextToSpeechAudioCategory.playback,
        options,
        broadcastModeEnabled
            ? IosTextToSpeechAudioMode.voicePrompt
            : IosTextToSpeechAudioMode.spokenAudio,
      );
    } catch (_) {}

    try {
      await _tts.setVolume(volume);
    } catch (_) {}
  }

  Future<void> setConnectionActive({
    required bool active,
    String? username,
  }) async {
    await ensureInitialized();
    _connectionActive = active;
    _connectedUsername = active ? username : null;
    _publishState();
  }

  Future<void> stopCurrent() async {
    await ensureInitialized();
    _currentItem = null;
    _isSpeaking = false;
    _syncMediaItem();
    await _tts.stop();
    _publishState(forceIdle: !_connectionActive);
  }

  @override
  Future<void> play() async {
    _publishState();
  }

  @override
  Future<void> stop() async {
    await stopCurrent();
  }

  @override
  Future<void> skipToNext() async {
    await stopCurrent();
  }

  void _syncMediaItem() {
    if (_currentItem == null) {
      mediaItem.add(null);
      queue.add(const []);
      return;
    }

    final item = MediaItem(
      id: _currentItem!.id,
      title: 'TikTok LIVE 読み上げ',
      artist: _connectedUsername == null ? 'TikBox' : '@$_connectedUsername',
      album: 'TikBox Background Service',
      displayDescription: _currentItem!.text,
    );
    mediaItem.add(item);
    queue.add([item]);
  }

  void _publishState({bool forceIdle = false}) {
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.stop,
          MediaAction.skipToNext,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: forceIdle
            ? AudioProcessingState.idle
            : (_isSpeaking || _connectionActive
                ? AudioProcessingState.ready
                : AudioProcessingState.idle),
        playing: _isSpeaking || _connectionActive,
        updatePosition: Duration.zero,
      ),
    );
  }
}
