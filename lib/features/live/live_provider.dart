import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:piratetok_live/piratetok_live.dart';
import 'package:uuid/uuid.dart';

import '../../models/comment_model.dart';
import '../../services/app_logger.dart';
import '../../services/effect_sound_service.dart';
import '../../services/tts_service.dart';
import '../../services/ugc_moderation_service.dart';
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

class LikeRushTracker {
  static const Duration window = Duration(seconds: 30);
  static const int threshold = 100;

  DateTime? _windowStartedAt;
  int _likeCount = 0;

  int get likeCount => _likeCount;

  bool addIncrement(int increment, DateTime now) {
    if (increment <= 0) {
      return false;
    }

    final startedAt = _windowStartedAt;
    if (startedAt == null ||
        now.isBefore(startedAt) ||
        now.difference(startedAt) >= window) {
      _windowStartedAt = now;
      _likeCount = 0;
    }

    _likeCount += increment;
    return _likeCount >= threshold;
  }

  void reset() {
    _windowStartedAt = null;
    _likeCount = 0;
  }
}

class LiveNotifier extends Notifier<LiveState> {
  static const int _maxAutoReconnectAttempts = 6;
  static const int _maxReconnectDelaySeconds = 16;
  static const int _mediumGiftVibrationThreshold = 10;
  static const int _highGiftVibrationThreshold = 100;
  static const MethodChannel _giftVibrationChannel =
      MethodChannel('com.taichi963.tikbox/gift_vibration');
  static const Duration _resumeReconnectRetryAfter = Duration(seconds: 30);
  static const Duration _diagnosticHeartbeatInterval = Duration(seconds: 30);
  static const Duration _connectSlowLogThreshold = Duration(seconds: 20);
  static const Duration _connectTimeoutThreshold = Duration(seconds: 45);

  final Uuid _uuid = const Uuid();

  TikTokLiveClient? _client;
  String? _username;
  Timer? _reconnectTimer;
  Timer? _diagnosticHeartbeatTimer;
  Timer? _connectSlowLogTimer;
  Timer? _connectTimeoutTimer;
  bool _disposed = false;
  bool _manualStopRequested = false;
  int _autoReconnectAttempts = 0;
  DateTime? _connectRequestedAt;

  DateTime? _lastGiftTime;
  int _comboStreak = 0;
  final LikeRushTracker _likeRushTracker = LikeRushTracker();

  @override
  LiveState build() {
    ref.onDispose(_dispose);
    return const LiveState();
  }

  Future<void> startLive(String rawUsername) async {
    AppLogger.info('startLive called');
    final username = _normalizeUsername(rawUsername);
    final inputError = _usernameInputError(rawUsername, username);
    if (inputError != null) {
      AppLogger.warning('startLive rejected username input before connect');
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: inputError,
      );
      return;
    }

    if (state.isConnecting) {
      AppLogger.warning(
        'startLive ignored because connection is already in progress: '
        'status=${state.wsStatus.name} client=${_client != null} '
        'reconnectTimer=${_reconnectTimer?.isActive ?? false}',
      );
      return;
    }

    _username = username;
    _manualStopRequested = false;
    _resetReconnectState();
    _resetGiftComboState();
    _resetEngagementSoundState();

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
    AppLogger.info('retryConnection called');
    if (_username == null) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: '再接続できません。配信者の@IDまたはURLをもう一度入力してください。',
      );
      return;
    }

    _manualStopRequested = false;
    _resetReconnectState();
    _resetGiftComboState();
    _resetEngagementSoundState();
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
    final stopStartedAt = DateTime.now();
    AppLogger.info(
      'stopLive called: status=${state.wsStatus.name} '
      'isConnecting=${state.isConnecting} client=${_client != null} '
      'reconnectTimer=${_reconnectTimer?.isActive ?? false}',
    );
    _manualStopRequested = true;
    _cancelReconnectTimer();
    _cancelConnectAttemptTimers();
    _autoReconnectAttempts = 0;
    _resetGiftComboState();
    _resetEngagementSoundState();
    _username = null;
    _connectRequestedAt = null;
    final previousClient = _client;
    _client = null;
    if (previousClient != null) {
      AppLogger.info('Disconnecting current TikTok client');
    }
    _disconnectClientSafely(previousClient, 'stopLive');

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
    _cancelConnectAttemptTimers();
    AppLogger.info(
      'stopLive completed in '
      '${DateTime.now().difference(stopStartedAt).inMilliseconds}ms',
    );
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
    return DateTime.now().difference(requestedAt) >= _resumeReconnectRetryAfter;
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
    _cancelConnectAttemptTimers();
    final previousClient = _client;
    _client = null;
    if (previousClient != null) {
      AppLogger.info(
        'Disconnecting previous TikTok client before reconnect for @$username',
      );
    }
    _disconnectClientSafely(previousClient, 'before reconnect');
    _manualStopRequested = false;

    final client = TikTokLiveClient(username);
    _client = client;
    DateTime? clientConnectStartedAt;

    client.on(EventType.connected, (evt) {
      if (_disposed || !identical(_client, client)) return;
      _cancelConnectAttemptTimers();
      final elapsedMs = clientConnectStartedAt == null
          ? null
          : DateTime.now().difference(clientConnectStartedAt).inMilliseconds;
      AppLogger.info(
        elapsedMs == null
            ? 'TikTok connected event received for @$username'
            : 'TikTok connected event received for @$username '
                '${elapsedMs}ms after client.connect',
      );
      _handleStatusConnected();
    });

    client.on(EventType.disconnected, (evt) {
      if (_disposed || !identical(_client, client)) return;
      _cancelConnectAttemptTimers();
      AppLogger.warning(
        'TikTok disconnected event received for @$username data=${evt.data}',
      );
      _handleStatusDisconnected();
    });

    client.on(EventType.reconnecting, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final attempt = _toInt(evt.data?['attempt']);
      AppLogger.info(
        'TikTok reconnecting event received for @$username attempt=$attempt',
      );
      _handleStatusReconnecting(attempt);
    });

    client.on('error', (evt) {
      if (_disposed || !identical(_client, client)) return;
      _cancelConnectAttemptTimers();
      AppLogger.error(
          'TikTok client error event for @$username data=${evt.data}');
      _handleStatusError(
        evt.data?['error']?.toString() ?? '接続できませんでした。ID・配信中か・通信環境を確認してください。',
      );
    });

    client.on(EventType.chat, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final data = evt.data;
      if (data == null) return;

      final userData = data['user'];
      final userMap = userData is Map ? userData : const <String, Object?>{};
      final uniqueId = userMap['uniqueId']?.toString();
      final nickname = userMap['nickname']?.toString() ?? uniqueId ?? '?';
      final content = data['content']?.toString() ?? '';
      final identity = UgcModerationService.resolveIdentity(
        uniqueId: uniqueId,
        nickname: nickname,
      );

      _handleCommentNative(
        nickname,
        content,
        identity: identity,
      );
    });

    client.on(EventType.gift, (evt) {
      if (_disposed || !identical(_client, client)) return;
      final data = evt.data;
      if (data == null) return;

      final userData = data['user'];
      final userMap = userData is Map ? userData : const <String, Object?>{};
      final uniqueId = userMap['uniqueId']?.toString();
      final nickname = userMap['nickname']?.toString() ?? uniqueId ?? '?';
      final userId = userMap['userId']?.toString() ?? userMap['id']?.toString();
      final userKeyCandidate = _resolveGiftUserKeyCandidate(
        userId: userId,
        uniqueId: uniqueId,
        nickname: userMap['nickname']?.toString(),
      );
      AppLogger.info(
        'Gift user key candidate: source=${userKeyCandidate.source} '
        'key=${_redactUserKeyForLog(userKeyCandidate.value)} '
        'uniqueIdPresent=${_hasText(uniqueId)} '
        'nicknamePresent=${_hasText(userMap['nickname']?.toString())}',
      );
      final giftMap = data['gift'] as Map<String, dynamic>? ?? {};
      final giftName = giftMap['name']?.toString() ?? 'ギフト';
      final repeatCount = _toPositiveInt(data['repeatCount']);
      final diamondCount = _toPositiveInt(giftMap['diamondCount']);
      final diamondTotal = _toPositiveInt(data['diamondTotal']);

      _handleGiftNative(
        nickname,
        giftName,
        repeatCount,
        diamondCount,
        diamondTotal,
        userKeyCandidate: userKeyCandidate,
      );
    });

    client.on(EventType.follow, (evt) {
      if (_disposed || _manualStopRequested || !identical(_client, client)) {
        return;
      }
      AppLogger.info('Follow event received');
      ref.read(mainProvider.notifier).recordFollow(DateTime.now());
      unawaited(effectSoundService.playFollowSound());
    });

    client.on(EventType.like, (evt) {
      if (_disposed || _manualStopRequested || !identical(_client, client)) {
        return;
      }
      final data = evt.data;
      if (data == null) {
        return;
      }
      final increment = _toPositiveInt(data['count']);
      if (increment == null) {
        AppLogger.info('Like event ignored: positive count is unavailable');
        return;
      }

      ref.read(mainProvider.notifier).recordLikes(increment);
      final isRush = _likeRushTracker.addIncrement(increment, DateTime.now());
      AppLogger.info(
        'Like event received: increment=$increment '
        'windowTotal=${_likeRushTracker.likeCount}',
      );
      if (isRush && effectSoundService.canPlayLikeRushSoundNow) {
        ref.read(mainProvider.notifier).recordLikeRush(DateTime.now());
        unawaited(effectSoundService.playLikeRushSound());
      }
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

    clientConnectStartedAt = DateTime.now();
    _scheduleConnectSlowLog(username, client);
    _scheduleConnectTimeout(username, client);
    unawaited(
      client.connect().then<void>((_) {
        if (_disposed || !identical(_client, client)) {
          return;
        }
        final elapsedMs =
            DateTime.now().difference(clientConnectStartedAt!).inMilliseconds;
        AppLogger.info(
          'TikTok client.connect completed for @$username in ${elapsedMs}ms',
        );
      }).catchError((Object error, StackTrace stackTrace) {
        if (_disposed || _manualStopRequested || !identical(_client, client)) {
          return;
        }
        _cancelConnectAttemptTimers();
        AppLogger.error(
          'TikTok connection failed totally',
          error: error,
          stackTrace: stackTrace,
        );
        _handleStatusError('接続できませんでした。IDが正しいか、配信中か確認してください。');
      }),
    );
  }

  void _handleStatusConnected() {
    if (_disposed || _username == null) return;

    _manualStopRequested = false;
    _cancelConnectAttemptTimers();
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
    _playConnectionSuccessCue();
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
      errorMessage: '接続が切れました。自動で再接続します。',
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
      errorMessage: '再接続しています。しばらくお待ちください。',
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

  void _handleCommentNative(
    String userName,
    String text, {
    required UgcUserIdentity identity,
  }) {
    if (userName.isEmpty || text.isEmpty) return;

    final mainNotifier = ref.read(mainProvider.notifier);
    final moderationDecision = mainNotifier.moderationDecision(
      userKey: identity.key,
      userName: userName,
      text: text,
    );
    if (moderationDecision != UgcModerationDecision.allow) {
      AppLogger.info(
        'Comment suppressed by UGC moderation: '
        'reason=${moderationDecision.name} source=${identity.source}',
      );
      return;
    }

    final comment = CommentModel(
      id: _uuid.v4(),
      userName: userName,
      text: text,
      type: CommentType.normal,
      createdAt: DateTime.now(),
      userKey: identity.key,
      userKeySource: identity.source,
      userReference: identity.reference,
    );

    mainNotifier.addComment(comment);
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

  void _handleGiftNative(String userName, String giftName, int? repeatCount,
      int? diamondCount, int? diamondTotal,
      {required ({String source, String? value}) userKeyCandidate}) {
    if (userName.isEmpty) return;

    final resolvedRepeatCount = repeatCount ?? 1;
    final computedTotalValue =
        diamondCount == null ? null : diamondCount * resolvedRepeatCount;
    final totalValue = diamondTotal ?? computedTotalValue;
    final totalValueSource = diamondTotal != null
        ? 'diamondTotal'
        : computedTotalValue != null
            ? 'diamondCount*repeatCount'
            : 'fallback';
    AppLogger.info(
      'Gift event received: user=$userName gift=$giftName '
      'repeat=${repeatCount ?? 'unknown'} '
      'diamonds=${diamondCount ?? 'unknown'} '
      'diamondTotal=${diamondTotal ?? 'unknown'} '
      'totalValue=${totalValue ?? 'unknown'} '
      'source=$totalValueSource',
    );

    final comment = CommentModel(
      id: _uuid.v4(),
      userName: userName,
      text: '',
      type: CommentType.gift,
      giftName: giftName,
      giftCount: resolvedRepeatCount,
      giftValue: totalValue ?? 0,
      userKey: _giftRankingKey(userKeyCandidate, userName),
      userKeySource: userKeyCandidate.source,
      userReference: userKeyCandidate.value ?? userName,
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

    final soundValue = totalValue ?? 0;
    AppLogger.info(
      'Gift sound value resolved: soundValue=$soundValue '
      'source=$totalValueSource',
    );

    unawaited(
      effectSoundService.playGiftEvent(
        value: soundValue,
        comboStreak: _comboStreak,
        giftName: giftName,
      ),
    );

    final settings = ref.read(ttsSettingsProvider);
    AppLogger.info(
      'Gift vibration setting: enabled=${settings.giftVibrationEnabled}',
    );
    if (settings.giftVibrationEnabled) {
      unawaited(_playGiftVibration(totalValue ?? 1));
    } else {
      AppLogger.info('Gift vibration skipped: setting is OFF');
    }
    final preferredGiftVoice = settings.giftVoice ?? settings.commentVoice;
    _enqueueGiftTts(
      comment,
      value: soundValue,
      voice: preferredGiftVoice,
    );
  }

  String _giftRankingKey(
    ({String source, String? value}) candidate,
    String fallbackName,
  ) {
    final reference = candidate.value?.trim();
    if (reference != null && reference.isNotEmpty) {
      final normalized = candidate.source == 'nickname'
          ? UgcModerationService.normalizeText(reference)
          : reference.toLowerCase();
      return '${candidate.source}:$normalized';
    }
    final normalizedName = UgcModerationService.normalizeText(fallbackName);
    return 'nickname:${normalizedName.isEmpty ? 'anonymous' : normalizedName}';
  }

  ({String source, String? value}) _resolveGiftUserKeyCandidate({
    required String? userId,
    required String? uniqueId,
    required String? nickname,
  }) {
    if (_hasText(userId)) {
      return (source: 'userId', value: userId!.trim());
    }
    if (_hasText(uniqueId)) {
      return (source: 'uniqueId', value: uniqueId!.trim());
    }
    if (_hasText(nickname)) {
      return (source: 'nickname', value: nickname!.trim());
    }
    return (source: 'none', value: null);
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _redactUserKeyForLog(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'none';
    }
    if (trimmed.length <= 2) {
      return '*(${trimmed.length})';
    }
    if (trimmed.length <= 4) {
      return '${trimmed[0]}***(${trimmed.length})';
    }
    return '${trimmed.substring(0, 2)}***'
        '${trimmed.substring(trimmed.length - 2)}(${trimmed.length})';
  }

  Future<void> _playGiftVibration(int value) async {
    try {
      final feedback = value >= _highGiftVibrationThreshold
          ? 'heavy'
          : value >= _mediumGiftVibrationThreshold
              ? 'medium'
              : 'light';
      AppLogger.info('Gift vibration triggered: $feedback value=$value');
      final nativeVibrationTriggered =
          await _tryNativeGiftVibration(value, feedback);
      if (!nativeVibrationTriggered) {
        await _playFlutterGiftHaptic(value);
      }
      AppLogger.info(
        'Gift vibration completed: $feedback '
        'method=${nativeVibrationTriggered ? 'native' : 'flutter'} '
        'value=$value',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Gift vibration failed: error=$error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _tryNativeGiftVibration(int value, String feedback) async {
    try {
      final triggered = await _giftVibrationChannel.invokeMethod<bool>(
        'vibrateGift',
        <String, Object>{
          'value': value,
          'feedback': feedback,
        },
      );
      if (triggered == true) {
        return true;
      }
      AppLogger.info('Native gift vibration unavailable; using Flutter haptic');
      return false;
    } on MissingPluginException {
      AppLogger.info(
        'Native gift vibration plugin missing; using Flutter haptic',
      );
      return false;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.warning(
        'Native gift vibration failed; using Flutter haptic',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _playFlutterGiftHaptic(int value) async {
    if (value >= _highGiftVibrationThreshold) {
      await HapticFeedback.heavyImpact();
    } else if (value >= _mediumGiftVibrationThreshold) {
      await HapticFeedback.mediumImpact();
    } else {
      // lightImpact is easy to miss on real devices, so gifts use at least
      // medium feedback while still respecting the ON/OFF setting.
      await HapticFeedback.mediumImpact();
    }
    await HapticFeedback.vibrate();
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
    _cancelConnectAttemptTimers();
    _stopDiagnosticHeartbeat();
    _connectRequestedAt = null;
    _resetGiftComboState();
    _resetEngagementSoundState();
    final previousClient = _client;
    _client = null;
    _disconnectClientSafely(previousClient, 'dispose');
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
        AppLogger.info(
          'Reconnect fired but skipped: disposed=$_disposed '
          'manualStop=$_manualStopRequested username=${_username != null}',
        );
        return;
      }
      AppLogger.info('Reconnect fired for @$_username');
      _connectNative(_username!);
    });
  }

  void _handleReconnectExhausted(String reason) {
    _cancelReconnectTimer();
    _resetGiftComboState();
    _resetEngagementSoundState();
    unawaited(ttsService.setConnectionActive(active: false));
    ref.read(mainProvider.notifier).stopLive();
    state = state.copyWith(
      wsStatus: WsStatus.error,
      isConnecting: false,
      errorMessage: '何度か試しましたが接続できませんでした。ID・配信中か・通信環境を確認してください。',
    );
    _playConnectionFailureCue();
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

  void _scheduleConnectSlowLog(String username, TikTokLiveClient client) {
    _cancelConnectSlowLogTimer();
    _connectSlowLogTimer = Timer(_connectSlowLogThreshold, () {
      _connectSlowLogTimer = null;
      if (_disposed || _manualStopRequested || !identical(_client, client)) {
        return;
      }
      AppLogger.warning(
        'TikTok client.connect still waiting after '
        '${_connectSlowLogThreshold.inSeconds}s for @$username '
        'status=${state.wsStatus.name} isConnecting=${state.isConnecting}',
      );
      state = state.copyWith(
        errorMessage: '接続に時間がかかっています。IDが正しいか、配信中か、通信環境を確認してください。',
      );
    });
  }

  void _scheduleConnectTimeout(String username, TikTokLiveClient client) {
    _cancelConnectTimeoutTimer();
    _connectTimeoutTimer = Timer(_connectTimeoutThreshold, () {
      _connectTimeoutTimer = null;
      if (_disposed || _manualStopRequested || !identical(_client, client)) {
        return;
      }

      AppLogger.warning(
        'TikTok client.connect timed out after '
        '${_connectTimeoutThreshold.inSeconds}s for @$username '
        'status=${state.wsStatus.name} isConnecting=${state.isConnecting}',
      );

      final shouldContinueReconnect =
          state.reconnectAttempts > 0 && _username != null;
      _cancelConnectSlowLogTimer();
      _connectRequestedAt = null;
      _resetGiftComboState();
      final timedOutClient = _client;
      _client = null;
      _disconnectClientSafely(timedOutClient, 'timeout');

      if (shouldContinueReconnect) {
        _scheduleReconnect('接続できませんでした');
        return;
      }

      _resetReconnectState();
      _resetEngagementSoundState();
      unawaited(ttsService.setConnectionActive(active: false));
      ref.read(mainProvider.notifier).stopLive();
      _playConnectionFailureCue();
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        reconnectAttempts: 0,
        errorMessage: '接続できませんでした。IDが正しいか、配信中か、通信環境を確認してください。',
      );
      _stopDiagnosticHeartbeat();
    });
  }

  void _cancelConnectAttemptTimers() {
    _cancelConnectSlowLogTimer();
    _cancelConnectTimeoutTimer();
  }

  void _cancelConnectSlowLogTimer() {
    _connectSlowLogTimer?.cancel();
    _connectSlowLogTimer = null;
  }

  void _cancelConnectTimeoutTimer() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }

  void _disconnectClientSafely(TikTokLiveClient? client, String reason) {
    if (client == null) {
      return;
    }
    try {
      client.disconnect();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'TikTok client disconnect failed: $reason',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _playConnectionSuccessCue() {
    unawaited(effectSoundService.playConnectionSuccess());
  }

  void _playConnectionFailureCue() {
    unawaited(effectSoundService.playConnectionFailure());
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

  void _resetEngagementSoundState() {
    _likeRushTracker.reset();
    effectSoundService.resetEngagementSoundCooldowns();
  }

  String _normalizeUsername(String input) {
    final trimmed = input.replaceAll('\u3000', ' ').replaceAll('＠', '@').trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      if (uri.host.isEmpty) {
        return '';
      }
      final host = uri.host.toLowerCase();
      final isTikTokHost = host == 'tiktok.com' || host.endsWith('.tiktok.com');
      if (!isTikTokHost) {
        return '';
      }
      for (final segment in uri.pathSegments) {
        if (segment.startsWith('@')) {
          return segment.replaceFirst(RegExp(r'^@+'), '').trim();
        }
      }
      return '';
    }

    final withoutQuery = trimmed.split(RegExp(r'[?#]')).first;
    final withoutHost = withoutQuery.replaceFirst(
      RegExp(r'^(https?://)?(www\.)?tiktok\.com/?', caseSensitive: false),
      '',
    );
    final withoutAt = withoutHost.replaceFirst(RegExp(r'^@+'), '');
    return withoutAt.split('/').first.replaceAll('@', '').trim();
  }

  String? _usernameInputError(String rawInput, String normalizedUsername) {
    if (_isNonTikTokUrl(rawInput)) {
      return 'TikTokの配信URL、または配信ページの@IDを入力してください。';
    }
    if (normalizedUsername.isEmpty) {
      return '配信IDを入力してください。@付き、@なし、TikTok URLが使えます。';
    }
    if (!_isLikelyTikTokUsername(normalizedUsername)) {
      return '表示名ではなく、半角のTikTok IDまたはURLを入力してください。';
    }
    return null;
  }

  bool _isLikelyTikTokUsername(String username) {
    return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(username);
  }

  bool _isNonTikTokUrl(String input) {
    final trimmed = input.replaceAll('\u3000', ' ').replaceAll('＠', '@').trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final withScheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
        .hasMatch(trimmed);
    final hostLikeWithoutScheme =
        RegExp(r'^(www\.|[a-z0-9.-]+\.[a-z]{2,}/)', caseSensitive: false)
            .hasMatch(trimmed);
    if (!withScheme && !hostLikeWithoutScheme) {
      return false;
    }

    final uri = Uri.tryParse(withScheme ? trimmed : 'https://$trimmed');
    final host = uri?.host.toLowerCase() ?? '';
    return host.isNotEmpty &&
        host != 'tiktok.com' &&
        !host.endsWith('.tiktok.com');
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

  int? _toPositiveInt(Object? value) {
    final parsed = value is int
        ? value
        : value is num
            ? value.toInt()
            : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }
}

final liveProvider = NotifierProvider<LiveNotifier, LiveState>(
  LiveNotifier.new,
);
