import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piratetok_live/piratetok_live.dart';
import 'package:uuid/uuid.dart';

import '../../models/comment_model.dart';
import '../../services/app_logger.dart';
import '../../services/effect_sound_service.dart';
import '../../services/tts_service.dart';
import '../main/main_provider.dart';
import '../main/tts_provider.dart';

enum WsStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class LiveState {
  final WsStatus wsStatus;
  final bool isConnecting;
  final String? errorMessage;
  final int reconnectAttempts;

  const LiveState({
    this.wsStatus = WsStatus.disconnected,
    this.isConnecting = false,
    this.errorMessage,
    this.reconnectAttempts = 0,
  });

  LiveState copyWith({
    WsStatus? wsStatus,
    bool? isConnecting,
    String? errorMessage,
    int? reconnectAttempts,
    bool clearError = false,
  }) {
    return LiveState(
      wsStatus: wsStatus ?? this.wsStatus,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

class LiveNotifier extends Notifier<LiveState> {
  static const int _maxAutoReconnectAttempts = 6;
  static const int _maxReconnectDelaySeconds = 16;

  final Uuid _uuid = const Uuid();

  TikTokLiveClient? _client;
  String? _username;
  String? _cookie;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _manualStopRequested = false;
  int _autoReconnectAttempts = 0;

  DateTime? _lastGiftTime;
  int _comboStreak = 0;

  @override
  LiveState build() {
    ref.onDispose(_dispose);
    return const LiveState();
  }

  Future<void> startLive(String rawUsername, {String? cookie}) async {
    final username = _normalizeUsername(rawUsername);
    if (username.isEmpty) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: 'Please enter a username',
      );
      return;
    }

    if (state.isConnecting) {
      return;
    }

    _username = username;
    _cookie = cookie;
    _manualStopRequested = false;
    _resetReconnectState();
    _resetGiftComboState();
    await effectSoundService.primeForPlayback();

    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: 0,
      clearError: true,
    );

    AppLogger.info('Starting native TikTok connection for @$username');
    _connectNative(username, cookie: cookie);
  }

  Future<void> retryConnection() async {
    if (_username == null) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: 'No live target to reconnect',
      );
      return;
    }

    _manualStopRequested = false;
    _resetReconnectState();
    _resetGiftComboState();
    await effectSoundService.primeForPlayback();
    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: 0,
      clearError: true,
    );
    _connectNative(_username!, cookie: _cookie);
  }

  Future<void> stopLive() async {
    _manualStopRequested = true;
    _cancelReconnectTimer();
    _autoReconnectAttempts = 0;
    _resetGiftComboState();
    _username = null;
    _cookie = null;
    final previousClient = _client;
    _client = null;
    previousClient?.disconnect();

    await ttsService.stopAll();
    await ttsService.setConnectionActive(active: false);
    ref.read(mainProvider.notifier).stopLive();

    if (!_disposed) {
      state = state.copyWith(
        wsStatus: WsStatus.disconnected,
        isConnecting: false,
        reconnectAttempts: 0,
        clearError: true,
      );
    }
  }

  Future<void> skipCurrentTts() async {
    await ttsService.skip();
  }

  Future<void> onAppResumed() async {
    if (_disposed || _manualStopRequested || _username == null) {
      return;
    }

    await effectSoundService.primeForPlayback();
    unawaited(
      ttsService.setConnectionActive(
        active: state.wsStatus == WsStatus.connected || state.isConnecting,
        username: _username,
      ),
    );

    if (state.wsStatus == WsStatus.connecting &&
        !(_reconnectTimer?.isActive ?? false)) {
      AppLogger.info(
        'App resumed while reconnect was pending, retrying for @$_username',
      );
      _connectNative(_username!, cookie: _cookie);
    }
  }

  void _connectNative(String username, {String? cookie}) {
    _cancelReconnectTimer();
    final previousClient = _client;
    _client = null;
    previousClient?.disconnect();
    _manualStopRequested = false;
    _cookie = cookie ?? _cookie;

    final client = TikTokLiveClient(username);
    if (_cookie != null && _cookie!.isNotEmpty) {
      client.cookies(_cookie!);
    }
    _client = client;

    client.on(EventType.connected, (evt) {
      if (_disposed || !identical(_client, client)) return;
      _handleStatusConnected();
    });

    client.on(EventType.disconnected, (evt) {
      if (_disposed || !identical(_client, client)) return;
      _handleStatusDisconnected();
    });

    client.on(EventType.reconnecting, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final attempt = _toInt(evt.data?['attempt']);
      _handleStatusReconnecting(attempt);
    });

    client.on('error', (evt) {
      if (_disposed || !identical(_client, client)) return;
      _handleStatusError(evt.data?['error']?.toString() ?? 'Unknown error');
    });

    client.on(EventType.chat, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final data = evt.data;
      if (data == null) return;

      final nickname =
          data['user']?['nickname']?.toString() ??
          data['user']?['uniqueId']?.toString() ??
          '?';
      final content = data['content']?.toString() ?? '';

      _handleCommentNative(nickname, content);
    });

    client.on(EventType.gift, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final data = evt.data;
      if (data == null) return;

      final nickname =
          data['user']?['nickname']?.toString() ??
          data['user']?['uniqueId']?.toString() ??
          '?';
      final giftMap = data['gift'] as Map<String, dynamic>? ?? {};
      final giftName = giftMap['name']?.toString() ?? 'Gift';
      final repeatCount = _toInt(data['repeatCount']);
      final diamondCount = _toInt(giftMap['diamondCount']);

      _handleGiftNative(nickname, giftName, repeatCount, diamondCount);
    });

    unawaited(
      client.connect().catchError((error) {
        if (_disposed || _manualStopRequested || !identical(_client, client)) {
          return '';
        }
        AppLogger.error('TikTok connection failed totally', error: error);
        _handleStatusError('Live was not found or the connection failed');
        return '';
      }),
    );
  }

  void _handleStatusConnected() {
    if (_disposed || _username == null) return;

    _manualStopRequested = false;
    _resetReconnectState();
    unawaited(
      ttsService.setConnectionActive(
        active: true,
        username: _username,
      ),
    );
    ref.read(mainProvider.notifier).startLive(_username!);

    state = state.copyWith(
      wsStatus: WsStatus.connected,
      isConnecting: false,
      reconnectAttempts: 0,
      clearError: true,
    );
    AppLogger.info('TikTok live natively connected for @$_username');
  }

  void _handleStatusDisconnected() {
    if (_disposed) return;

    if (_manualStopRequested || _username == null) {
      _resetReconnectState();
      unawaited(ttsService.setConnectionActive(active: false));
      ref.read(mainProvider.notifier).stopLive();
      state = state.copyWith(
        wsStatus: WsStatus.disconnected,
        isConnecting: false,
        reconnectAttempts: 0,
        clearError: true,
      );
      return;
    }

    unawaited(
      ttsService.setConnectionActive(
        active: true,
        username: _username,
      ),
    );
    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      errorMessage: 'Connection lost. Waiting for reconnect',
    );
    _scheduleReconnect('Connection lost');
  }

  void _handleStatusReconnecting(int attempt) {
    if (_disposed) return;

    final trackedAttempt = attempt > state.reconnectAttempts
        ? attempt
        : state.reconnectAttempts;

    unawaited(
      ttsService.setConnectionActive(
        active: true,
        username: _username,
      ),
    );
    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: trackedAttempt,
      errorMessage:
          'Reconnecting... ($trackedAttempt/$_maxAutoReconnectAttempts)',
    );
  }

  void _handleStatusError(String message) {
    if (_disposed) return;

    if (_manualStopRequested || _username == null) {
      _resetReconnectState();
      unawaited(ttsService.setConnectionActive(active: false));
      ref.read(mainProvider.notifier).stopLive();
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: message,
      );
      return;
    }

    _scheduleReconnect(message);
  }

  void _handleCommentNative(String userName, String text) {
    if (userName.isEmpty || text.isEmpty) return;

    final comment = CommentModel(
      id: _uuid.v4(),
      userName: userName,
      text: text,
      type: CommentType.normal,
      createdAt: DateTime.now(),
    );

    ref.read(mainProvider.notifier).addComment(comment);
    unawaited(effectSoundService.playComment());

    final settings = ref.read(ttsSettingsProvider);
    _enqueueCommentTts(
      comment,
      voice: settings.commentVoice,
    );
  }

  void _handleGiftNative(
    String userName,
    String giftName,
    int repeatCount,
    int diamondCount,
  ) {
    if (userName.isEmpty) return;
    if (diamondCount < 0) return;

    final totalValue = diamondCount * repeatCount;

    final comment = CommentModel(
      id: _uuid.v4(),
      userName: userName,
      text: '',
      type: CommentType.gift,
      giftName: giftName,
      giftCount: repeatCount,
      giftValue: totalValue,
      createdAt: DateTime.now(),
    );

    ref.read(mainProvider.notifier).addComment(comment);

    final now = DateTime.now();
    if (_lastGiftTime != null &&
        now.difference(_lastGiftTime!).inSeconds <= 2) {
      _comboStreak++;
    } else {
      _comboStreak = 1;
    }
    _lastGiftTime = now;

    final soundValue = totalValue <= 0 ? 1 : totalValue;

    unawaited(
      effectSoundService.playGiftEvent(
        value: soundValue,
        comboStreak: _comboStreak,
      ),
    );

    final settings = ref.read(ttsSettingsProvider);
    final preferredGiftVoice = settings.giftVoice ?? settings.commentVoice;
    _enqueueGiftTts(
      comment,
      value: soundValue,
      voice: preferredGiftVoice,
    );
  }

  void _enqueueCommentTts(
    CommentModel comment, {
    Map<String, String>? voice,
  }) {
    final sourceClient = _client;
    unawaited(
      Future<void>.delayed(effectSoundService.commentTtsLeadIn, () async {
        if (_disposed || _manualStopRequested || !identical(_client, sourceClient)) {
          return;
        }
        await ttsService.enqueue(
          comment.ttsText,
          priority: ttsService.getPriority(comment),
          voice: voice,
        );
      }),
    );
  }

  void _enqueueGiftTts(
    CommentModel comment, {
    required int value,
    Map<String, String>? voice,
  }) {
    final sourceClient = _client;
    unawaited(
      Future<void>.delayed(effectSoundService.giftTtsLeadIn(value), () async {
        if (_disposed || _manualStopRequested || !identical(_client, sourceClient)) {
          return;
        }
        await ttsService.enqueueFirst(
          comment.ttsText,
          priority: ttsService.getPriority(comment) + 200,
          voice: voice,
        );
      }),
    );
  }

  Future<void> _dispose() async {
    _disposed = true;
    _manualStopRequested = true;
    _cancelReconnectTimer();
    _resetGiftComboState();
    final previousClient = _client;
    _client = null;
    previousClient?.disconnect();
    await ttsService.setConnectionActive(active: false);
  }

  void _scheduleReconnect(String reason) {
    if (_disposed || _manualStopRequested || _username == null) {
      return;
    }

    if (_reconnectTimer?.isActive ?? false) {
      return;
    }

    final nextAttempt = _autoReconnectAttempts + 1;
    if (nextAttempt > _maxAutoReconnectAttempts) {
      _handleReconnectExhausted(reason);
      return;
    }

    _autoReconnectAttempts = nextAttempt;
    final delay = _reconnectDelayForAttempt(nextAttempt);

    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: nextAttempt,
      errorMessage:
          '$reason. Retrying in ${delay.inSeconds}s '
          '($nextAttempt/$_maxAutoReconnectAttempts)',
    );

    AppLogger.warning(
      'Scheduling reconnect attempt $nextAttempt in ${delay.inSeconds}s '
      'for @$_username',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_disposed || _manualStopRequested || _username == null) {
        return;
      }
      _connectNative(_username!, cookie: _cookie);
    });
  }

  void _handleReconnectExhausted(String reason) {
    _cancelReconnectTimer();
    _resetGiftComboState();
    unawaited(ttsService.setConnectionActive(active: false));
    ref.read(mainProvider.notifier).stopLive();
    state = state.copyWith(
      wsStatus: WsStatus.error,
      isConnecting: false,
      errorMessage:
          '$reason. Reconnect limit reached '
          '($_maxAutoReconnectAttempts attempts)',
    );
  }

  Duration _reconnectDelayForAttempt(int attempt) {
    final seconds = 1 << (attempt - 1);
    final cappedSeconds = seconds > _maxReconnectDelaySeconds
        ? _maxReconnectDelaySeconds
        : seconds;
    return Duration(seconds: cappedSeconds);
  }

  void _resetReconnectState() {
    _autoReconnectAttempts = 0;
    _cancelReconnectTimer();
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _resetGiftComboState() {
    _lastGiftTime = null;
    _comboStreak = 0;
  }

  String _normalizeUsername(String input) {
    return input
        .trim()
        .replaceAll('@', '')
        .replaceAll(
          RegExp(r'https?://(www\.)?tiktok\.com/@?', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\?.*$'), '')
        .replaceAll('/', '');
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }
}

final liveProvider = NotifierProvider<LiveNotifier, LiveState>(
  LiveNotifier.new,
);
