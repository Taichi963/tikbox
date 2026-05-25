import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
  static const int _mediumGiftVibrationThreshold = 10;
  static const int _highGiftVibrationThreshold = 100;
  static const Duration _resumeReconnectRetryAfter = Duration(seconds: 30);
  static const Duration _diagnosticHeartbeatInterval = Duration(seconds: 30);

  final Uuid _uuid = const Uuid();

  TikTokLiveClient? _client;
  String? _username;
  Timer? _reconnectTimer;
  Timer? _diagnosticHeartbeatTimer;
  bool _disposed = false;
  bool _manualStopRequested = false;
  int _autoReconnectAttempts = 0;
  DateTime? _connectRequestedAt;

  DateTime? _lastGiftTime;
  int _comboStreak = 0;

  @override
  LiveState build() {
    ref.onDispose(_dispose);
    return const LiveState();
  }

  Future<void> startLive(String rawUsername) async {
    AppLogger.info('startLive called');
    final username = _normalizeUsername(rawUsername);
    if (username.isEmpty) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: 'ユーザー名を入力してください',
      );
      return;
    }

    if (state.isConnecting) {
      return;
    }

    _username = username;
    _manualStopRequested = false;
    _resetReconnectState();
    _resetGiftComboState();

    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: 0,
      clearError: true,
    );

    _connectRequestedAt = DateTime.now();
    AppLogger.info('Starting native TikTok connection for @$username');
    _startDiagnosticHeartbeat();
    _connectNative(username);
    _primeEffectSoundAfterConnectStart();
  }

  Future<void> retryConnection() async {
    if (_username == null) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: '再接続するユーザー名がありません',
      );
      return;
    }

    _manualStopRequested = false;
    _resetReconnectState();
    _resetGiftComboState();
    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: 0,
      clearError: true,
    );
    _connectRequestedAt = DateTime.now();
    _startDiagnosticHeartbeat();
    _connectNative(_username!);
    _primeEffectSoundAfterConnectStart();
  }

  Future<void> stopLive() async {
    _manualStopRequested = true;
    _cancelReconnectTimer();
    _autoReconnectAttempts = 0;
    _resetGiftComboState();
    _username = null;
    _connectRequestedAt = null;
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
    _stopDiagnosticHeartbeat();
  }

  Future<void> skipCurrentTts() async {
    await ttsService.skip();
  }

  Future<void> onAppResumed() async {
    if (_disposed || _manualStopRequested || _username == null) {
      return;
    }

    if (state.wsStatus == WsStatus.connecting &&
        !(_reconnectTimer?.isActive ?? false)) {
      final shouldRetryConnect =
          _client == null || _isConnectAttemptStaleOnResume();
      if (shouldRetryConnect) {
        AppLogger.info(
          'App resumed while reconnect was pending, retrying for @$_username',
        );
        _connectRequestedAt = DateTime.now();
        _connectNative(_username!);
      } else {
        AppLogger.info(
          'App resumed while connection is already in progress for @$_username',
        );
      }
    }

    _primeEffectSoundAfterConnectStart();
    unawaited(
      ttsService.setConnectionActive(
        active: state.wsStatus == WsStatus.connected || state.isConnecting,
        username: _username,
      ),
    );
  }

  bool _isConnectAttemptStaleOnResume() {
    final requestedAt = _connectRequestedAt;
    if (requestedAt == null) {
      return false;
    }
    return DateTime.now().difference(requestedAt) >=
        _resumeReconnectRetryAfter;
  }

  void _primeEffectSoundAfterConnectStart() {
    unawaited(
      Future<void>(() async {
        await effectSoundService.primeForPlayback();
      }),
    );
  }

  void _connectNative(String username) {
    final connectNativeElapsedMs = _connectRequestedAt == null
        ? null
        : DateTime.now().difference(_connectRequestedAt!).inMilliseconds;
    AppLogger.info(
      connectNativeElapsedMs == null
          ? '_connectNative called for @$username'
          : '_connectNative called for @$username '
              '${connectNativeElapsedMs}ms after request',
    );

    _cancelReconnectTimer();
    final previousClient = _client;
    _client = null;
    previousClient?.disconnect();
    _manualStopRequested = false;

    final client = TikTokLiveClient(username);
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
      _handleStatusError(evt.data?['error']?.toString() ?? '不明なエラーが発生しました');
    });

    client.on(EventType.chat, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final data = evt.data;
      if (data == null) return;

      final nickname = data['user']?['nickname']?.toString() ??
          data['user']?['uniqueId']?.toString() ??
          '?';
      final content = data['content']?.toString() ?? '';

      _handleCommentNative(nickname, content);
    });

    client.on(EventType.gift, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final data = evt.data;
      if (data == null) return;

      final nickname = data['user']?['nickname']?.toString() ??
          data['user']?['uniqueId']?.toString() ??
          '?';
      final giftMap = data['gift'] as Map<String, dynamic>? ?? {};
      final giftName = giftMap['name']?.toString() ?? 'ギフト';
      final repeatCount = _toInt(data['repeatCount']);
      final diamondCount = _toInt(giftMap['diamondCount']);

      _handleGiftNative(nickname, giftName, repeatCount, diamondCount);
    });

    final connectCallElapsedMs = _connectRequestedAt == null
        ? null
        : DateTime.now().difference(_connectRequestedAt!).inMilliseconds;
    AppLogger.info(
      connectCallElapsedMs == null
          ? 'Calling TikTok client.connect for @$username'
          : 'Calling TikTok client.connect for @$username '
              '${connectCallElapsedMs}ms after request',
    );

    final clientConnectStartedAt = DateTime.now();
    unawaited(
      client.connect().then<void>((_) {
        if (_disposed || !identical(_client, client)) {
          return;
        }
        final elapsedMs =
            DateTime.now().difference(clientConnectStartedAt).inMilliseconds;
        AppLogger.info(
          'TikTok client.connect completed for @$username in ${elapsedMs}ms',
        );
      }).catchError((error) {
        if (_disposed || _manualStopRequested || !identical(_client, client)) {
          return;
        }
        AppLogger.error('TikTok connection failed totally', error: error);
        _handleStatusError('ライブが見つからないか、接続に失敗しました');
      }),
    );
  }

  void _handleStatusConnected() {
    if (_disposed || _username == null) return;

    _manualStopRequested = false;
    _resetReconnectState();
    final elapsedMs = _connectRequestedAt == null
        ? null
        : DateTime.now().difference(_connectRequestedAt!).inMilliseconds;
    _connectRequestedAt = null;
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
    _startDiagnosticHeartbeat();
    AppLogger.info(
      elapsedMs == null
          ? 'TikTok live natively connected for @$_username'
          : 'TikTok live natively connected for @$_username in ${elapsedMs}ms',
    );
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
      _stopDiagnosticHeartbeat();
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
      errorMessage: '接続が切れました。再接続を待機しています',
    );
    _scheduleReconnect('接続が切れました');
  }

  void _handleStatusReconnecting(int attempt) {
    if (_disposed) return;

    final trackedAttempt =
        attempt > state.reconnectAttempts ? attempt : state.reconnectAttempts;

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
      errorMessage: '再接続中... ($trackedAttempt/$_maxAutoReconnectAttempts)',
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
    final commentTtsText = _buildCommentTtsText(
      comment,
      readUsernameEnabled: settings.readUsernameEnabled,
    );
    if (commentTtsText != null) {
      _enqueueCommentTts(
        comment,
        ttsText: commentTtsText,
        voice: settings.commentVoice,
      );
    }
  }

  String? _buildCommentTtsText(
    CommentModel comment, {
    required bool readUsernameEnabled,
  }) {
    if (!ttsService.hasSpeakableText(comment.text)) {
      return null;
    }

    final ttsText = readUsernameEnabled ? comment.ttsText : comment.text;
    return ttsService.hasSpeakableText(ttsText) ? ttsText : null;
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
    AppLogger.info(
      'Gift event received: user=$userName gift=$giftName '
      'repeat=$repeatCount diamonds=$diamondCount total=$totalValue',
    );

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
    if (settings.giftVibrationEnabled) {
      unawaited(_playGiftVibration(soundValue));
    }
    final preferredGiftVoice = settings.giftVoice ?? settings.commentVoice;
    _enqueueGiftTts(
      comment,
      value: soundValue,
      voice: preferredGiftVoice,
    );
  }

  Future<void> _playGiftVibration(int value) async {
    try {
      AppLogger.info('Gift vibration triggered: value=$value');
      if (value >= _highGiftVibrationThreshold) {
        await HapticFeedback.heavyImpact();
      } else if (value >= _mediumGiftVibrationThreshold) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Gift vibration failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _enqueueCommentTts(
    CommentModel comment, {
    required String ttsText,
    Map<String, String>? voice,
  }) {
    final sourceClient = _client;
    unawaited(
      Future<void>.delayed(effectSoundService.commentTtsLeadIn, () async {
        if (_disposed ||
            _manualStopRequested ||
            !identical(_client, sourceClient)) {
          return;
        }
        await ttsService.enqueue(
          ttsText,
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
        if (_disposed ||
            _manualStopRequested ||
            !identical(_client, sourceClient)) {
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
    _stopDiagnosticHeartbeat();
    _connectRequestedAt = null;
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
    _connectRequestedAt = DateTime.now().add(delay);

    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: nextAttempt,
      errorMessage: '$reason。${delay.inSeconds}秒後に再接続します '
          '($nextAttempt/$_maxAutoReconnectAttempts)',
    );

    _startDiagnosticHeartbeat();

    AppLogger.warning(
      'Scheduling reconnect attempt $nextAttempt in ${delay.inSeconds}s '
      'for @$_username',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_disposed || _manualStopRequested || _username == null) {
        return;
      }
      AppLogger.info('Reconnect fired for @$_username');
      _connectNative(_username!);
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
      errorMessage: '$reason。再接続の上限に達しました '
          '($_maxAutoReconnectAttempts回)',
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
    final hadActiveTimer = _reconnectTimer?.isActive ?? false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (hadActiveTimer) {
      AppLogger.info('Reconnect cancelled');
    }
  }

  void _startDiagnosticHeartbeat() {
    if (_diagnosticHeartbeatTimer?.isActive ?? false) {
      return;
    }
    _diagnosticHeartbeatTimer =
        Timer.periodic(_diagnosticHeartbeatInterval, (_) {
      if (_disposed || _manualStopRequested || _username == null) {
        _stopDiagnosticHeartbeat();
        return;
      }
      if (state.wsStatus != WsStatus.connected && !state.isConnecting) {
        _stopDiagnosticHeartbeat();
        return;
      }
      AppLogger.info(
        'Live heartbeat: status=${state.wsStatus.name} '
        'isConnecting=${state.isConnecting} client=${_client != null} '
        'reconnectTimer=${_reconnectTimer?.isActive ?? false} '
        'reconnectAttempts=$_autoReconnectAttempts '
        'ttsQueue=${ttsService.queueLength}',
      );
    });
  }

  void _stopDiagnosticHeartbeat() {
    _diagnosticHeartbeatTimer?.cancel();
    _diagnosticHeartbeatTimer = null;
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
