import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/comment_model.dart';
import '../../services/app_logger.dart';
import '../../services/effect_sound_service.dart';
import '../../services/tts_service.dart';
import '../main/main_provider.dart';
import '../main/tts_provider.dart';
import '../premium/premium_provider.dart';

const String _defaultWsUrl = 'ws://192.168.1.10:3000';
const String _wsUrl = String.fromEnvironment(
  'TIKBOX_WS_URL',
  defaultValue: _defaultWsUrl,
);

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
  final Uuid _uuid = const Uuid();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _username;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _disposed = false;

  @override
  LiveState build() {
    ref.onDispose(_dispose);
    return const LiveState();
  }

  Future<void> startLive(String rawUsername) async {
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

    _manualDisconnect = false;
    _username = username;
    _cancelReconnectTimer();

    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: 0,
      clearError: true,
    );

    AppLogger.info('Starting live connection for @$username');
    await _connect(resetReconnectCount: true);
  }

  Future<void> retryConnection() async {
    if (_username == null) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: '再接続する配信が見つかりません',
      );
      return;
    }

    _manualDisconnect = false;
    _cancelReconnectTimer();
    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      clearError: true,
    );
    await _connect(resetReconnectCount: false);
  }

  Future<void> stopLive() async {
    _manualDisconnect = true;
    _cancelReconnectTimer();
    await _disconnectChannel();
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

  Future<void> _connect({required bool resetReconnectCount}) async {
    if (_disposed || _username == null) {
      return;
    }

    if (resetReconnectCount) {
      state = state.copyWith(reconnectAttempts: 0);
    }

    await _disconnectChannel();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 8));

      _subscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: true,
      );

      _channel!.sink.add(
        jsonEncode({
          'type': 'connect',
          'username': _username,
        }),
      );

      await ttsService.setConnectionActive(
        active: true,
        username: _username,
      );

      state = state.copyWith(
        wsStatus: WsStatus.connected,
        isConnecting: false,
        clearError: true,
      );
      ref.read(mainProvider.notifier).startLive(_username!);
      AppLogger.info('Live connected for @$_username');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Live connection failed',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: '接続に失敗しました。ネットワークと配信状況を確認してください。',
      );
      await _scheduleReconnect();
    }
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = map['type']?.toString() ?? '';

      switch (type) {
        case 'comment':
          unawaited(_handleComment(map));
          break;
        case 'gift':
          unawaited(_handleGift(map));
          break;
        case 'error':
          state = state.copyWith(
            wsStatus: WsStatus.error,
            isConnecting: false,
            errorMessage: map['message']?.toString() ?? '接続エラーが発生しました',
          );
          unawaited(_scheduleReconnect());
          break;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to decode WebSocket payload',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: '受信データの解析に失敗しました',
      );
      unawaited(_scheduleReconnect());
    }
  }

  Future<void> _handleComment(Map<String, dynamic> map) async {
    final userName = map['userName']?.toString() ?? '';
    final text = map['text']?.toString() ?? '';
    if (userName.isEmpty || text.isEmpty) {
      return;
    }

    final comment = CommentModel(
      id: _uuid.v4(),
      userName: userName,
      text: text,
      type: CommentType.normal,
      createdAt: DateTime.now(),
    );

    ref.read(mainProvider.notifier).addComment(comment);
    unawaited(effectSoundService.playComment());

    final premiumNotifier = ref.read(premiumProvider.notifier);
    final canRead = await premiumNotifier.consumeTtsAllowance();
    if (!canRead) {
      return;
    }

    final settings = ref.read(ttsSettingsProvider);
    final selectedVoice = premiumNotifier.canUseVoice(settings.commentVoice)
        ? settings.commentVoice
        : null;
    await ttsService.enqueue(
      comment.ttsText,
      priority: ttsService.getPriority(comment),
      voice: selectedVoice,
    );
  }

  Future<void> _handleGift(Map<String, dynamic> map) async {
    final userName = map['userName']?.toString() ?? '';
    if (userName.isEmpty) {
      return;
    }

    final comment = CommentModel(
      id: _uuid.v4(),
      userName: userName,
      text: '',
      type: CommentType.gift,
      giftName: map['giftName']?.toString() ?? 'Gift',
      giftCount: _toInt(map['giftCount']),
      createdAt: DateTime.now(),
    );

    ref.read(mainProvider.notifier).addComment(comment);

    final premiumNotifier = ref.read(premiumProvider.notifier);
    if (premiumNotifier.hasPremiumGiftEffects) {
      unawaited(effectSoundService.playPremiumGift());
    } else {
      unawaited(effectSoundService.playGift());
    }

    final canRead = await premiumNotifier.consumeTtsAllowance();
    if (!canRead) {
      return;
    }

    final settings = ref.read(ttsSettingsProvider);
    final preferredGiftVoice = settings.giftVoice ?? settings.commentVoice;
    final selectedVoice = premiumNotifier.canUseVoice(preferredGiftVoice)
        ? preferredGiftVoice
        : null;
    await ttsService.enqueueFirst(
      comment.ttsText,
      priority:
          ttsService.getPriority(comment) + premiumNotifier.giftPriorityBoost(),
      voice: selectedVoice,
    );
  }

  void _handleSocketError(Object error) {
    if (_disposed || _manualDisconnect) {
      return;
    }

    AppLogger.warning('WebSocket error', error: error);
    state = state.copyWith(
      wsStatus: WsStatus.error,
      isConnecting: false,
      errorMessage: '接続が不安定です。再接続を試しています。',
    );
    unawaited(_scheduleReconnect());
  }

  void _handleSocketDone() {
    if (_disposed || _manualDisconnect) {
      return;
    }

    AppLogger.warning('WebSocket closed unexpectedly');
    state = state.copyWith(
      wsStatus: WsStatus.disconnected,
      isConnecting: false,
      errorMessage: '接続が切断されました',
    );
    unawaited(_scheduleReconnect());
  }

  Future<void> _scheduleReconnect() async {
    if (_manualDisconnect || _disposed || _username == null) {
      return;
    }

    if (state.reconnectAttempts >= 3) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        isConnecting: false,
        errorMessage: '再接続上限に達しました。再接続ボタンを押してください。',
      );
      await ttsService.setConnectionActive(active: false);
      ref.read(mainProvider.notifier).stopLive();
      return;
    }

    final nextAttempt = state.reconnectAttempts + 1;
    state = state.copyWith(
      wsStatus: WsStatus.connecting,
      isConnecting: true,
      reconnectAttempts: nextAttempt,
      errorMessage: '再接続中... ($nextAttempt/3)',
    );

    _cancelReconnectTimer();
    _reconnectTimer = Timer(Duration(seconds: 1 << (nextAttempt - 1)), () {
      unawaited(_connect(resetReconnectCount: false));
    });
  }

  Future<void> _disconnectChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> _dispose() async {
    _disposed = true;
    _manualDisconnect = true;
    _cancelReconnectTimer();
    await _disconnectChannel();
    await ttsService.setConnectionActive(active: false);
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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

final liveProvider =
    NotifierProvider<LiveNotifier, LiveState>(LiveNotifier.new);
