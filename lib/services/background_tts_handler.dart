import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'app_logger.dart';

const String _keepAliveMimeType = 'audio/wav';
const double _keepAliveVolume = 0.012;
final Uint8List _keepAliveWavBytes = _buildKeepAliveWav();

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

class TikBoxAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isSpeaking = false;
  bool _speechRequestInFlight = false;
  bool _connectionActive = false;
  String? _connectedUsername;
  SpokenItem? _currentItem;
  AudioPlayer? _keepAlivePlayer;
  StreamSubscription<PlayerState>? _keepAliveStateSubscription;
  PlayerState? _lastLoggedKeepAlivePlayerState;
  bool _keepAlivePrepared = false;
  bool _keepAliveRunning = false;
  bool _keepAliveRestartScheduled = false;
  Future<void> _keepAliveSync = Future<void>.value();

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
      AppLogger.info('Background TTS start');
      _speechRequestInFlight = false;
      _isSpeaking = true;
      _publishState();
    });

    _tts.setCompletionHandler(() {
      AppLogger.info('Background TTS complete');
      _speechRequestInFlight = false;
      _isSpeaking = false;
      _currentItem = null;
      _syncMediaItem();
      _publishState();
      unawaited(_queueKeepAliveSync());
    });

    _tts.setErrorHandler((message) {
      _speechRequestInFlight = false;
      _isSpeaking = false;
      AppLogger.warning('Background TTS error: $message');
      _currentItem = null;
      _syncMediaItem();
      _publishState();
      unawaited(_queueKeepAliveSync());
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
    _speechRequestInFlight = true;
    _currentItem = SpokenItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
    );
    _syncMediaItem();
    _publishState();
    try {
      await _stopKeepAlivePlayback();
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
    } catch (error, stackTrace) {
      _speechRequestInFlight = false;
      _isSpeaking = false;
      _currentItem = null;
      _syncMediaItem();
      await _queueKeepAliveSync();
      _publishState();
      AppLogger.warning(
        'Background TTS speak setup failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _configureAudioSession({
    required bool broadcastModeEnabled,
    required double volume,
  }) async {
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}

    try {
      await _tts.setAudioAttributesForNavigation();
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
    AppLogger.info('Background connection active: $active');
    _connectionActive = active;
    _connectedUsername = active ? username : null;
    if (!active) {
      _speechRequestInFlight = false;
    }
    await _queueKeepAliveSync();
    _publishState();
  }

  Future<void> stopCurrent() async {
    await ensureInitialized();
    _speechRequestInFlight = false;
    _currentItem = null;
    _isSpeaking = false;
    _syncMediaItem();
    await _tts.stop();
    await _queueKeepAliveSync();
    _publishState(forceIdle: !_connectionActive);
  }

  @override
  Future<void> play() async {
    await ensureInitialized();
    await _queueKeepAliveSync();
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
    final shouldAppearActive =
        _isSpeaking || _speechRequestInFlight || _connectionActive;
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
            : (shouldAppearActive
                ? AudioProcessingState.ready
                : AudioProcessingState.idle),
        playing: shouldAppearActive,
        updatePosition: Duration.zero,
      ),
    );
  }

  Future<void> _queueKeepAliveSync() {
    _keepAliveSync = _keepAliveSync.then<void>(
      (_) async => _syncKeepAliveNow(),
      onError: (Object _, StackTrace __) async => _syncKeepAliveNow(),
    );
    return _keepAliveSync;
  }

  Future<void> _syncKeepAliveNow() async {
    try {
      final shouldPlay =
          _connectionActive && !_isSpeaking && !_speechRequestInFlight;
      if (shouldPlay) {
        await _startKeepAlivePlayback();
      } else {
        await _stopKeepAlivePlayback();
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Background keep-alive sync failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _startKeepAlivePlayback() async {
    if (_keepAliveRunning && _keepAlivePlayer?.state == PlayerState.playing) {
      return;
    }

    await _ensureKeepAlivePlayer();
    if (!_connectionActive || _isSpeaking || _speechRequestInFlight) {
      return;
    }

    await _keepAlivePlayer!.setVolume(_keepAliveVolume);
    await _keepAlivePlayer!.resume();
    _keepAliveRunning = true;
    AppLogger.info('Background keep-alive start');
  }

  Future<void> _stopKeepAlivePlayback() async {
    if (_keepAlivePlayer == null) {
      return;
    }
    if (!_keepAliveRunning && _keepAlivePlayer!.state != PlayerState.playing) {
      return;
    }

    await _keepAlivePlayer!.stop();
    _keepAliveRunning = false;
    AppLogger.info('Background keep-alive stop');
  }

  Future<void> _ensureKeepAlivePlayer() async {
    if (_keepAlivePlayer != null && _keepAlivePrepared) {
      return;
    }

    final player = _keepAlivePlayer ?? AudioPlayer();
    try {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await player.setSource(
        BytesSource(
          _keepAliveWavBytes,
          mimeType: _keepAliveMimeType,
        ),
      );
      _keepAliveStateSubscription ??=
          player.onPlayerStateChanged.listen(_handleKeepAlivePlayerState);
      _keepAlivePlayer = player;
      _keepAlivePrepared = true;
    } catch (_) {
      if (_keepAlivePlayer == null) {
        try {
          await player.dispose();
        } catch (_) {}
      }
      rethrow;
    }
  }

  void _handleKeepAlivePlayerState(PlayerState state) {
    if (_lastLoggedKeepAlivePlayerState != state) {
      _lastLoggedKeepAlivePlayerState = state;
      AppLogger.info('Background keep-alive player state: ${state.name}');
    }
    if (state == PlayerState.playing) {
      _keepAliveRunning = true;
      return;
    }
    if (state == PlayerState.disposed) {
      _keepAliveRunning = false;
      _keepAlivePrepared = false;
      _keepAlivePlayer = null;
      final subscription = _keepAliveStateSubscription;
      _keepAliveStateSubscription = null;
      _lastLoggedKeepAlivePlayerState = null;
      unawaited(subscription?.cancel());
      if (_connectionActive && !_isSpeaking && !_speechRequestInFlight) {
        _scheduleKeepAliveRestart(state);
      }
      return;
    }
    if (state == PlayerState.stopped || state == PlayerState.completed) {
      _keepAliveRunning = false;
      if (_connectionActive && !_isSpeaking && !_speechRequestInFlight) {
        _scheduleKeepAliveRestart(state);
      }
    }
  }

  void _scheduleKeepAliveRestart(PlayerState state) {
    if (_keepAliveRestartScheduled) {
      return;
    }
    _keepAliveRestartScheduled = true;
    AppLogger.warning(
      'Background keep-alive became ${state.name}; scheduling restart',
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        _keepAliveRestartScheduled = false;
        if (_connectionActive &&
            !_isSpeaking &&
            !_speechRequestInFlight &&
            _keepAlivePlayer?.state != PlayerState.playing) {
          await _queueKeepAliveSync();
        }
      }),
    );
  }
}

Uint8List _buildKeepAliveWav() {
  const sampleRate = 16000;
  const channelCount = 1;
  const bitsPerSample = 16;
  const sampleCount = sampleRate;
  const frequency = 200.0;
  const amplitude = 0.0018;

  final pcm = Int16List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    final progress = i / sampleCount;
    final fade = progress < 0.02
        ? progress / 0.02
        : progress > 0.98
            ? (1.0 - progress) / 0.02
            : 1.0;
    final sample =
        math.sin((2 * math.pi * frequency * i) / sampleRate) * amplitude * fade;
    pcm[i] = _toPcm16(sample);
  }

  return _encodeWav(
    pcm,
    sampleRate: sampleRate,
    channelCount: channelCount,
    bitsPerSample: bitsPerSample,
  );
}

int _toPcm16(double sample) {
  final scaled = (sample * 32767.0).round();
  return scaled.clamp(-32768, 32767);
}

Uint8List _encodeWav(
  Int16List samples, {
  required int sampleRate,
  required int channelCount,
  required int bitsPerSample,
}) {
  final bytesPerSample = bitsPerSample ~/ 8;
  final dataLength = samples.length * bytesPerSample;
  final fileLength = 44 + dataLength;
  final bytes = Uint8List(fileLength);
  final data = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, fileLength - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channelCount, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(
    28,
    sampleRate * channelCount * bytesPerSample,
    Endian.little,
  );
  data.setUint16(32, channelCount * bytesPerSample, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataLength, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + (i * bytesPerSample), samples[i], Endian.little);
  }

  return bytes;
}
