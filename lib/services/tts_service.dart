import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/comment_model.dart';
import '../models/tts_settings.dart';
import 'app_logger.dart';
import 'background_tts_handler.dart';

class TtsQueueItem {
  final String text;
  final int priority;
  final Map<String, String>? voice;
  final DateTime createdAt;

  const TtsQueueItem({
    required this.text,
    required this.priority,
    required this.voice,
    required this.createdAt,
  });
}

class TtsService {
  TikBoxAudioHandler? _handler;

  final List<TtsQueueItem> _queue = <TtsQueueItem>[];
  Timer? _playbackRetryTimer;

  bool _initialized = false;
  Future<void>? _initFuture;
  DateTime? _nextInitAllowedAt;
  int _initFailureStreak = 0;
  bool _isPlaying = false;
  bool _isSkipping = false;
  int _playbackGeneration = 0;
  TtsSettings _settings = const TtsSettings();
  int _maxQueueLength = 20;

  bool get isPlaying => _isPlaying;
  int get queueLength => _queue.length;

  Duration _cooldownAfterFailure() {
    final streak = _initFailureStreak.clamp(1, 8);
    final seconds = (4 * (1 << (streak - 1))).clamp(4, 120);
    return Duration(seconds: seconds);
  }

  Future<void> init() async {
    if (_initialized) return;

    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _doInit();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInit() async {
    if (_initialized) return;

    final now = DateTime.now();
    if (_nextInitAllowedAt != null && now.isBefore(_nextInitAllowedAt!)) {
      await Future.delayed(_nextInitAllowedAt!.difference(now));
      if (_initialized) return;
    }

    try {
      _handler ??= await AudioService.init(
        builder: TikBoxAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.tikbox.tts',
          androidNotificationChannelName: 'TikBox Live Reading',
          androidNotificationChannelDescription:
              'Keeps TikTok LIVE comment reading active in background',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );

      await _handler!.ensureInitialized();

      _initialized = true;
      _initFailureStreak = 0;
      _nextInitAllowedAt = null;
      _cancelPlaybackRetry();
      AppLogger.info('TTS initialized');
    } catch (e, st) {
      AppLogger.error('TTS init failed', error: e, stackTrace: st);
      _initialized = false;
      _initFailureStreak += 1;
      final wait = _cooldownAfterFailure();
      _nextInitAllowedAt = DateTime.now().add(wait);
      AppLogger.warning(
        'TTS init backoff: next attempt in ${wait.inSeconds}s '
        '(failure streak $_initFailureStreak)',
      );
    }
  }

  void setQueueLimit(int limit) {
    _maxQueueLength = limit < 1 ? 1 : limit;
    _trimQueue();
  }

  Future<void> setConnectionActive({
    required bool active,
    String? username,
  }) async {
    if (!active && !_initialized) {
      if (_handler == null) {
        return;
      }
      await _handler?.setConnectionActive(
        active: false,
      );
      return;
    }

    await init();
    if (!_initialized || _handler == null) {
      return;
    }
    await _handler?.setConnectionActive(
      active: active,
      username: username,
    );
  }

  Future<void> applySettings(TtsSettings settings) async {
    _settings = settings;
    await init();
  }

  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final rawVoices = await FlutterTts().getVoices;
      if (rawVoices is! Iterable) {
        return const [];
      }

      final voices = <Map<String, String>>[];
      final seen = <String>{};
      for (final rawVoice in rawVoices) {
        final voice = _normalizeVoice(rawVoice);
        if (voice.isEmpty) {
          continue;
        }

        final key = _voiceKey(voice);
        if (!seen.add(key)) {
          continue;
        }
        voices.add(voice);
      }

      voices.sort(_compareVoices);
      AppLogger.info('TTS voices loaded: ${voices.length}');
      return voices;
    } catch (e) {
      AppLogger.error('getVoices error', error: e);
      return const [];
    }
  }

  Map<String, String> _normalizeVoice(Object? rawVoice) {
    if (rawVoice is! Map) {
      return const {};
    }

    final voice = <String, String>{};
    for (final entry in rawVoice.entries) {
      final key = entry.key?.toString();
      final value = entry.value?.toString();
      if (key == null || value == null || value.isEmpty) {
        continue;
      }
      voice[key] = value;
    }

    final hasUsableIdentity = (voice['name']?.isNotEmpty ?? false) ||
        (voice['identifier']?.isNotEmpty ?? false) ||
        (voice['locale']?.isNotEmpty ?? false);
    return hasUsableIdentity ? voice : const {};
  }

  int _compareVoices(Map<String, String> a, Map<String, String> b) {
    final aJapanese = _isJapaneseVoice(a);
    final bJapanese = _isJapaneseVoice(b);
    if (aJapanese != bJapanese) {
      return aJapanese ? -1 : 1;
    }
    return _voiceLabel(a).toLowerCase().compareTo(_voiceLabel(b).toLowerCase());
  }

  bool _isJapaneseVoice(Map<String, String> voice) {
    final locale = voice['locale']?.toLowerCase() ?? '';
    final name = voice['name']?.toLowerCase() ?? '';
    return locale.startsWith('ja') ||
        locale.contains('jp') ||
        name.contains('japanese') ||
        name.contains('日本');
  }

  String _voiceKey(Map<String, String> voice) {
    return '${voice['name'] ?? ''}|${voice['locale'] ?? ''}|'
        '${voice['identifier'] ?? ''}';
  }

  String _voiceLabel(Map<String, String> voice) {
    final name = voice['name'] ?? voice['identifier'] ?? 'Voice';
    final locale = voice['locale'];
    return locale == null || locale.isEmpty ? name : '$name ($locale)';
  }

  Future<List<String>> getAvailableLanguages() async {
    try {
      return const ['ja-JP', 'en-US'];
    } catch (e) {
      AppLogger.error('getLanguages error', error: e);
      return const [];
    }
  }

  int getPriority(CommentModel comment) => comment.priority;

  bool hasSpeakableText(String text) => _sanitizeText(text).isNotEmpty;

  String _sanitizeText(String text) {
    if (text.isEmpty) return '';

    var cleaned = text.replaceAll(
      RegExp(r'https?://[^\s]+'),
      'URL\u7701\u7565',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[(（]\s*笑\s*[)）]'), '\u7B11');
    cleaned = cleaned.replaceAll(RegExp(r'[wWｗＷ]{3,}'), '\u7B11');
    cleaned = cleaned.replaceAll(RegExp(r'[\^＾]{2,}'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(r'[\(（][^一-龠ぁ-んァ-ヶa-zA-Z0-9０-９]{2,}[\)）]'),
      ' ',
    );
    cleaned = _removeDecorativeRunes(cleaned);
    cleaned = cleaned.replaceAll(
      RegExp(r'[!！?？。｡、,，.．…・･~〜\-_=＝+＋*＊#＃]{2,}'),
      ' ',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(.)\1{3,}', unicode: true),
      (match) => match.group(1)! * 3,
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 30) {
      cleaned = '${cleaned.substring(0, 30)} \u4EE5\u4E0B\u7701\u7565';
    }
    return cleaned.trim();
  }

  String _removeDecorativeRunes(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (_isDecorativeRune(rune)) {
        buffer.write(' ');
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  bool _isDecorativeRune(int rune) {
    return (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        (rune >= 0xFE00 && rune <= 0xFE0F) ||
        rune == 0x200D ||
        rune == 0x20E3;
  }

  Future<void> speak(String text) async {
    await enqueue(text, priority: 10);
  }

  Future<void> enqueue(
    String text, {
    required int priority,
    Map<String, String>? voice,
  }) async {
    final sanitized = _sanitizeText(text);
    if (sanitized.isEmpty) return;

    _queue.add(
      TtsQueueItem(
        text: sanitized,
        priority: priority,
        voice: voice,
        createdAt: DateTime.now(),
      ),
    );

    _trimQueue();
    _sortQueue();

    await _playNext();
  }

  Future<void> enqueueFirst(
    String text, {
    required int priority,
    Map<String, String>? voice,
  }) async {
    final sanitized = _sanitizeText(text);
    if (sanitized.isEmpty) return;

    _queue.add(
      TtsQueueItem(
        text: sanitized,
        priority: priority + 1000,
        voice: voice,
        createdAt: DateTime.now(),
      ),
    );

    _trimQueue();
    _sortQueue();

    if (_isPlaying) {
      await skip();
      return;
    }

    await _playNext();
  }

  Future<void> skip() async {
    await init();
    if (!_initialized || _handler == null) return;

    if (_isSkipping) return;

    _isSkipping = true;
    _playbackGeneration += 1;
    _isPlaying = false;

    await _handler?.stopCurrent();

    _isSkipping = false;

    await _playNext();
  }

  Future<void> stop() async {
    await stopAll();
  }

  Future<void> stopAll() async {
    _cancelPlaybackRetry();
    _playbackGeneration += 1;
    _queue.clear();
    _isPlaying = false;

    if (_handler == null) {
      return;
    }

    await _handler?.stopCurrent();
  }

  Future<void> _playNext() async {
    if (_isPlaying || _queue.isEmpty) return;

    if (!_initialized || _handler == null) {
      await init();
      if (!_initialized || _handler == null) {
        AppLogger.warning(
          'TTS not ready, keeping ${_queue.length} queued items for retry',
        );
        _schedulePlaybackRetry();
        return;
      }
    }

    _cancelPlaybackRetry();
    final item = _queue.removeAt(0);
    final playbackGeneration = ++_playbackGeneration;
    _isPlaying = true;

    try {
      await _handler?.speakItem(
        text: item.text,
        language: _settings.language,
        rate: _settings.rate,
        pitch: _settings.pitch,
        volume: _settings.ttsVolume,
        broadcastModeEnabled: _settings.broadcastModeEnabled,
        voice: item.voice,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'TTS speak failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (_playbackGeneration == playbackGeneration) {
        _isPlaying = false;

        if (_queue.isNotEmpty) {
          await _playNext();
        }
      }
    }
  }

  void _schedulePlaybackRetry() {
    if (_queue.isEmpty) return;
    if (_playbackRetryTimer?.isActive ?? false) return;

    final now = DateTime.now();
    final delay =
        _nextInitAllowedAt == null || !_nextInitAllowedAt!.isAfter(now)
            ? const Duration(seconds: 2)
            : _nextInitAllowedAt!.difference(now);

    _playbackRetryTimer = Timer(delay, () {
      _playbackRetryTimer = null;
      unawaited(_playNext());
    });
  }

  void _cancelPlaybackRetry() {
    _playbackRetryTimer?.cancel();
    _playbackRetryTimer = null;
  }

  void _trimQueue() {
    if (_queue.length <= _maxQueueLength) return;

    _sortQueue();
    _queue.removeRange(_maxQueueLength, _queue.length);
  }

  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;

      return a.createdAt.compareTo(b.createdAt);
    });
  }
}

final ttsService = TtsService();
