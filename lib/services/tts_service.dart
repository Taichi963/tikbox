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
  final FlutterTts _voiceProbe = FlutterTts();
  final List<TtsQueueItem> _queue = <TtsQueueItem>[];

  bool _initialized = false;
  bool _isPlaying = false;
  bool _isSkipping = false;
  TtsSettings _settings = const TtsSettings();
  int _maxQueueLength = 20;

  bool get isPlaying => _isPlaying;
  int get queueLength => _queue.length;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _handler = await AudioService.init(
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
  }

  void setQueueLimit(int limit) {
    _maxQueueLength = limit < 1 ? 1 : limit;
    _trimQueue();
  }

  Future<void> setConnectionActive({
    required bool active,
    String? username,
  }) async {
    await init();
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
    final dynamic voices = await _voiceProbe.getVoices;
    if (voices is! List) {
      return const [];
    }

    return voices
        .whereType<Map>()
        .map(
          (voice) => voice.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        )
        .where((voice) => voice.containsKey('name'))
        .toList();
  }

  Future<List<String>> getAvailableLanguages() async {
    final dynamic languages = await _voiceProbe.getLanguages;
    if (languages is! List) {
      return const [];
    }
    return languages.map((item) => item.toString()).toList();
  }

  int getPriority(CommentModel comment) => comment.priority;

  Future<void> speak(String text) async {
    await enqueue(text, priority: 10);
  }

  Future<void> enqueue(
    String text, {
    required int priority,
    Map<String, String>? voice,
  }) async {
    if (text.trim().isEmpty) {
      return;
    }

    await init();
    _queue.add(
      TtsQueueItem(
        text: text.trim(),
        priority: priority,
        voice: voice,
        createdAt: DateTime.now(),
      ),
    );
    _trimQueue();
    _sortQueue();

    if (!_isPlaying) {
      await _playNext();
    }
  }

  Future<void> enqueueFirst(
    String text, {
    required int priority,
    Map<String, String>? voice,
  }) async {
    if (text.trim().isEmpty) {
      return;
    }

    await init();
    _queue.add(
      TtsQueueItem(
        text: text.trim(),
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
    if (_isSkipping) {
      return;
    }
    _isSkipping = true;
    _isPlaying = false;
    await _handler?.stopCurrent();
    _isSkipping = false;
    await _playNext();
  }

  Future<void> stop() async {
    await stopAll();
  }

  Future<void> stopAll() async {
    await init();
    _queue.clear();
    _isPlaying = false;
    await _handler?.stopCurrent();
  }

  Future<void> _playNext() async {
    if (_isPlaying || _queue.isEmpty) {
      return;
    }

    final item = _queue.removeAt(0);
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
      _isPlaying = false;
      if (_queue.isNotEmpty) {
        await _playNext();
      }
    }
  }

  void _trimQueue() {
    if (_queue.length <= _maxQueueLength) {
      return;
    }
    _sortQueue();
    _queue.removeRange(_maxQueueLength, _queue.length);
  }

  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
  }
}

final ttsService = TtsService();
