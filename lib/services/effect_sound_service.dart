import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'tts_service.dart';

class EffectSoundService {
  EffectSoundService._();

  static final EffectSoundService instance = EffectSoundService._();

  static const String _wavMimeType = 'audio/wav';
  static const String _mp3MimeType = 'audio/mpeg';
  static const Duration _poolStopPadding = Duration(milliseconds: 24);
  static const int _mediumGiftValueThreshold = 10;
  static const int _highGiftValueThreshold = 100;
  static const int _mediumGiftSoundThreshold = 10;
  static const int _largeGiftSoundThreshold = 100;
  static const int _premiumGiftSoundThreshold = 1000;
  static const Duration followSoundCooldown = Duration(seconds: 3);
  static const Duration likeRushSoundCooldown = Duration(seconds: 15);

  final Map<String, _GeneratedEffectTone> _tones = {};
  final Map<String, AudioPool> _pools = {};
  final Map<String, AudioPool> _assetPools = {};
  final Map<String, Future<AudioPool>> _assetPoolFutures = {};
  final Set<String> _missingAssetPaths = {};

  Future<void>? _initializeFuture;
  Future<void>? _primeFuture;
  AudioContext? _audioContext;
  bool _initialized = false;
  bool _webAudioUnlocked = false;
  bool _giftSoundEnabled = true;
  double _volume = 0.85;
  DateTime? _lastFollowSoundAt;
  DateTime? _lastLikeRushSoundAt;
  int _pendingTonesGeneration = 0;

  final math.Random _random = math.Random();

  Future<void> Function(String assetPath, double volume, Duration stopAfter)?
      _debugAssetPlayback;
  Future<void> Function(String toneName, double volume)?
      _debugGeneratedPlayback;

  @visibleForTesting
  static Uint8List debugBuildCommentWav() => _buildCommentTone().bytes;

  @visibleForTesting
  static Uint8List debugBuildGiftWav() => _buildSmallCrystal().bytes;

  @visibleForTesting
  static Uint8List debugBuildConnectionSuccessWav() =>
      _buildConnectionSuccessTone().bytes;

  @visibleForTesting
  static Uint8List debugBuildConnectionFailureWav() =>
      _buildConnectionFailureTone().bytes;

  @visibleForTesting
  static String debugGiftSoundTierName(int value) =>
      _giftSoundTierForValue(value).name;

  @visibleForTesting
  static bool debugIsHeartMeGift(String? giftName) => _isHeartMeGift(giftName);

  @visibleForTesting
  static String? debugAssetPathForSoundKey(String soundKey) =>
      _assetPathForSoundKey(soundKey);

  @visibleForTesting
  bool debugClaimFollowSoundAt(DateTime now) => _claimFollowSound(now);

  @visibleForTesting
  bool debugClaimLikeRushSoundAt(DateTime now) => _claimLikeRushSound(now);

  @visibleForTesting
  void debugSetPlaybackOverrides({
    Future<void> Function(String assetPath, double volume, Duration stopAfter)?
        assetPlayback,
    Future<void> Function(String toneName, double volume)? generatedPlayback,
  }) {
    _debugAssetPlayback = assetPlayback;
    _debugGeneratedPlayback = generatedPlayback;
  }

  @visibleForTesting
  void debugResetPlaybackOverrides() {
    _debugAssetPlayback = null;
    _debugGeneratedPlayback = null;
    _missingAssetPaths.clear();
  }

  @visibleForTesting
  int get debugPendingTonesGeneration => _pendingTonesGeneration;

  Future<void> initialize() async {
    if (_initialized) return;

    if (_initializeFuture != null) {
      await _initializeFuture;
      return;
    }

    _initializeFuture = _doInitialize();
    try {
      await _initializeFuture;
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> _doInitialize() async {
    try {
      final context = _audioContext ??= _buildAudioContext();

      _tones['comment'] = _buildCommentTone();
      _tones['connection_success'] = _buildConnectionSuccessTone();
      _tones['connection_failure'] = _buildConnectionFailureTone();
      _tones['small_0'] = _buildSmallCrystal();
      _tones['small_1'] = _buildSmallBubble();
      _tones['small_2'] = _buildSmallCoin();
      _tones['small_heart_me'] = _buildHeartMeTone();
      _tones['rare_small'] = _buildRareSmallHit();
      for (int i = 1; i <= 10; i++) {
        final pitchMultiplier = 1.0 + (i * 0.05);
        _tones['small_combo_$i'] = _buildSmallComboScale(pitchMultiplier);
      }
      _tones['small_combo_3_4'] = _buildSmallComboTier1();
      _tones['small_combo_5_9'] = _buildSmallComboTier2();
      _tones['small_combo_10'] = _buildSmallComboTier3();

      _tones['medium'] = _buildMediumLevelUp();
      _tones['rare_medium'] = _buildRareFever();
      _tones['medium_combo_3_4'] = _buildMediumComboTier1();
      _tones['medium_combo_5_9'] = _buildMediumComboTier2();
      _tones['medium_combo_10'] = _buildMediumComboTier3();

      _tones['large'] = _buildLargeFanfare();
      _tones['rare_large'] = _buildRareJackpot();
      _tones['large_combo_3_4'] = _buildLargeComboTier1();
      _tones['large_combo_5_9'] = _buildLargeComboTier2();
      _tones['large_combo_10'] = _buildLargeComboTier3();

      for (final key in _tones.keys) {
        _pools[key] = await _createPool(
          _tones[key]!.bytes,
          audioContext: context,
          maxPlayers: key.contains('small') ? 6 : 3,
          minPlayers: 1,
        );
      }

      _initialized = true;
      AppLogger.info('Effect sound initialized: tones=${_tones.length}');
    } catch (error, stackTrace) {
      _initialized = false;
      final poolsToDispose = _pools.values.toList(growable: false);
      final assetPoolsToDispose = _assetPools.values.toList(growable: false);
      _pools.clear();
      _assetPools.clear();
      _assetPoolFutures.clear();
      _tones.clear();
      _audioContext = null;
      for (final pool in poolsToDispose) {
        try {
          await pool.dispose();
        } catch (disposeError, disposeStackTrace) {
          AppLogger.warning(
            'Effect sound pool dispose failed after initialization error',
            error: disposeError,
            stackTrace: disposeStackTrace,
          );
        }
      }
      for (final pool in assetPoolsToDispose) {
        try {
          await pool.dispose();
        } catch (disposeError, disposeStackTrace) {
          AppLogger.warning(
            'Effect asset sound pool dispose failed after initialization error',
            error: disposeError,
            stackTrace: disposeStackTrace,
          );
        }
      }
      AppLogger.error(
        'Effect sound initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AudioContext? _buildAudioContext() {
    if (kIsWeb) {
      return null;
    }
    return AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
      stayAwake: true,
    ).build();
  }

  Future<void> playComment() async {
    await _playTone('comment');
  }

  Future<void> playConnectionSuccess() async {
    await _playTone('connection_success');
  }

  Future<void> playConnectionFailure() async {
    await _playTone('connection_failure');
  }

  Future<void> playFollowSound() async {
    if (!_claimFollowSound(DateTime.now())) {
      AppLogger.info('Follow sound skipped: cooldown active');
      return;
    }
    try {
      await _playTone('small_1', assetKey: 'follow');
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Follow sound playback failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> playLikeRushSound() async {
    if (!_claimLikeRushSound(DateTime.now())) {
      AppLogger.info('Like rush sound skipped: cooldown active');
      return;
    }
    try {
      await _playTone('medium_combo_3_4', assetKey: 'like_rush');
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Like rush sound playback failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void resetEngagementSoundCooldowns() {
    _lastFollowSoundAt = null;
    _lastLikeRushSoundAt = null;
    _pendingTonesGeneration++;
  }

  Future<void> playGiftEvent({
    required int value,
    required int comboStreak,
    String? giftName,
  }) async {
    AppLogger.info(
      'playGiftEvent called: enabled=$_giftSoundEnabled '
      'volume=${_volume.toStringAsFixed(2)} value=$value '
      'comboStreak=$comboStreak giftName=${giftName ?? 'unknown'}',
    );
    if (!_giftSoundEnabled) {
      AppLogger.info('playGiftEvent skipped: giftSoundEnabled=false');
      return;
    }

    _pendingTonesGeneration++;
    final randomVal = _random.nextDouble();
    final comboTier = _comboTier(comboStreak);
    final giftTier = _giftSoundTier(value);

    if (_isHeartMeGift(giftName)) {
      AppLogger.info('selected gift tone tier: heartMe comboTier=$comboTier');
      await _playHeartMeGift(comboTier);
      return;
    }

    if (giftTier == _GiftSoundTier.premium) {
      AppLogger.info('selected gift tone tier: premium comboTier=$comboTier');
      await _playPremiumGift();
      return;
    }

    if (giftTier == _GiftSoundTier.gold) {
      AppLogger.info('selected gift tone tier: gold comboTier=$comboTier');
      await _playHighGiftCombo(randomVal, comboTier);
      return;
    }

    if (giftTier == _GiftSoundTier.silver) {
      AppLogger.info('selected gift tone tier: silver comboTier=$comboTier');
      await _playMediumGiftCombo(randomVal, comboTier);
      return;
    }

    if (giftTier == _GiftSoundTier.fallback) {
      AppLogger.info('selected gift tone tier: fallback');
      await _playSmallGift(randomVal, 0);
      return;
    }

    AppLogger.info('selected gift tone tier: bronze comboTier=$comboTier');
    await _playSmallGift(randomVal, comboTier);
  }

  _GiftSoundTier _giftSoundTier(int value) {
    return _giftSoundTierForValue(value);
  }

  static _GiftSoundTier _giftSoundTierForValue(int value) {
    if (value <= 0) return _GiftSoundTier.fallback;
    if (value < _mediumGiftSoundThreshold) return _GiftSoundTier.bronze;
    if (value < _largeGiftSoundThreshold) return _GiftSoundTier.silver;
    if (value < _premiumGiftSoundThreshold) return _GiftSoundTier.gold;
    return _GiftSoundTier.premium;
  }

  static bool _isHeartMeGift(String? giftName) {
    final normalized =
        (giftName ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-・･]'), '');
    return normalized.contains('heartme') ||
        normalized.contains('ハートミー') ||
        normalized.contains('はーとみー');
  }

  Future<void> _playSmallGift(double randomVal, int comboTier) async {
    if (comboTier > 0) {
      await _playSmallGiftCombo(randomVal, comboTier);
      return;
    }

    if (randomVal < 0.03) {
      AppLogger.info('selected gift tone: rare_small');
      await _playTone('rare_small');
    } else {
      final variation = _random.nextInt(3);
      final toneName = 'small_$variation';
      AppLogger.info('selected gift tone: $toneName');
      await _playTone(toneName);
    }
  }

  Future<void> _playHeartMeGift(int comboTier) async {
    await _playTone('small_heart_me');
    if (comboTier >= 2) {
      _playToneAfter(
        const Duration(milliseconds: 54),
        'small_1',
        volumeScale: 0.56,
      );
    }
  }

  Future<void> primeForPlayback() async {
    if (_primeFuture != null) {
      await _primeFuture;
      return;
    }

    _primeFuture = _doPrimeForPlayback();
    try {
      await _primeFuture;
    } finally {
      _primeFuture = null;
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    AppLogger.info('Effect sound volume set: ${_volume.toStringAsFixed(2)}');
  }

  double get volume => _volume;

  bool get canPlayLikeRushSoundNow {
    final lastPlayedAt = _lastLikeRushSoundAt;
    return lastPlayedAt == null ||
        DateTime.now().difference(lastPlayedAt) >= likeRushSoundCooldown;
  }

  void setGiftSoundEnabled(bool enabled) {
    _giftSoundEnabled = enabled;
    AppLogger.info('Gift sound enabled set: $_giftSoundEnabled');
  }

  bool _claimFollowSound(DateTime now) {
    final lastPlayedAt = _lastFollowSoundAt;
    if (lastPlayedAt != null &&
        now.difference(lastPlayedAt) < followSoundCooldown) {
      return false;
    }
    _lastFollowSoundAt = now;
    return true;
  }

  bool _claimLikeRushSound(DateTime now) {
    final lastPlayedAt = _lastLikeRushSoundAt;
    if (lastPlayedAt != null &&
        now.difference(lastPlayedAt) < likeRushSoundCooldown) {
      return false;
    }
    _lastLikeRushSoundAt = now;
    return true;
  }

  Duration get commentTtsLeadIn => const Duration(milliseconds: 110);

  Duration giftTtsLeadIn(int value) {
    if (value >= _highGiftValueThreshold) {
      return const Duration(milliseconds: 760);
    }
    if (value >= _mediumGiftValueThreshold) {
      return const Duration(milliseconds: 360);
    }
    return const Duration(milliseconds: 180);
  }

  Future<void> _playTone(
    String toneName, {
    double volumeScale = 1.0,
    String? assetKey,
    bool preferAsset = true,
  }) async {
    final isGiftTone = toneName != 'comment';
    if (isGiftTone) {
      AppLogger.info('_playTone called: $toneName');
    }

    if (preferAsset) {
      final soundKey = assetKey ?? _soundKeyForTone(toneName);
      final assetPlayed = soundKey != null &&
          await _tryPlayAssetTone(
            toneName,
            soundKey,
            volumeScale: volumeScale,
          );
      if (assetPlayed) {
        return;
      }
    }

    await _playGeneratedTone(toneName, volumeScale: volumeScale);
  }

  Future<void> _playGeneratedTone(
    String toneName, {
    double volumeScale = 1.0,
  }) async {
    final isGiftTone = toneName != 'comment';
    final resolvedVolume =
        (_resolvedVolumeForTone(toneName) * volumeScale).clamp(0.0, 1.0);
    if (resolvedVolume <= 0) {
      if (isGiftTone) {
        AppLogger.warning('_playTone skipped: volume is 0 for $toneName');
      }
      return;
    }

    final debugPlayback = _debugGeneratedPlayback;
    if (debugPlayback != null) {
      try {
        await debugPlayback(toneName, resolvedVolume);
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Effect sound playback failed: $toneName',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) {
      if (isGiftTone) {
        AppLogger.warning('_playTone skipped: not initialized');
      }
      return;
    }

    final pool = _pools[toneName];
    final tone = _tones[toneName];
    if (pool == null || tone == null) {
      if (isGiftTone) {
        AppLogger.warning('_playTone skipped: missing tone $toneName');
      }
      return;
    }

    try {
      if (isGiftTone) {
        AppLogger.info(
          '_playTone starting: $toneName volume=${resolvedVolume.toStringAsFixed(2)}',
        );
      }
      final stop = await pool.start(
        volume: resolvedVolume,
      );
      unawaited(
        Future<void>.delayed(tone.duration + _poolStopPadding, () async {
          try {
            await stop();
          } catch (error, stackTrace) {
            AppLogger.warning(
              'Effect sound stop failed: $toneName',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }),
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Effect sound playback failed: $toneName',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _tryPlayAssetTone(
    String toneName,
    String soundKey, {
    required double volumeScale,
  }) async {
    final assetPath = _assetPathForSoundKey(soundKey);
    if (assetPath == null) {
      return false;
    }
    if (_missingAssetPaths.contains(assetPath)) {
      return false;
    }

    final tone = _tones[toneName];
    final stopAfter = (tone?.duration ?? const Duration(milliseconds: 600)) +
        _poolStopPadding;
    final resolvedVolume =
        (_resolvedVolumeForTone(toneName) * volumeScale).clamp(0.0, 1.0);
    if (resolvedVolume <= 0) {
      AppLogger.warning('asset sound skipped: volume is 0 for $soundKey');
      return true;
    }

    try {
      final debugPlayback = _debugAssetPlayback;
      if (debugPlayback != null) {
        await debugPlayback(assetPath, resolvedVolume, stopAfter);
        return true;
      }

      final pool = await _assetPoolForPath(
        assetPath,
        maxPlayers: toneName.contains('small') ? 6 : 3,
      );
      final stop = await pool.start(volume: resolvedVolume);
      unawaited(
        Future<void>.delayed(stopAfter, () async {
          try {
            await stop();
          } catch (error, stackTrace) {
            AppLogger.warning(
              'Effect asset sound stop failed: $soundKey',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }),
      );
      return true;
    } catch (error, stackTrace) {
      if (_isAssetNotFoundError(error)) {
        _missingAssetPaths.add(assetPath);
        AppLogger.warning(
          'asset sound not found, fallback to generated tone: $soundKey',
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        AppLogger.warning(
          'asset sound playback error, fallback to generated tone: $soundKey ($error)',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return false;
    }
  }

  Future<AudioPool> _createPool(
    Uint8List wavBytes, {
    required AudioContext? audioContext,
    required int maxPlayers,
    required int minPlayers,
  }) {
    return AudioPool.create(
      source: BytesSource(wavBytes, mimeType: _wavMimeType),
      maxPlayers: maxPlayers,
      minPlayers: minPlayers,
      playerMode: PlayerMode.lowLatency,
      audioContext: audioContext,
    );
  }

  Future<AudioPool> _assetPoolForPath(
    String assetPath, {
    required int maxPlayers,
  }) {
    final existing = _assetPools[assetPath];
    if (existing != null) {
      return Future.value(existing);
    }

    // Cache the Future itself so concurrent callers receive the same Future
    // and AudioPool.create is never invoked more than once per path.
    return _assetPoolFutures.putIfAbsent(assetPath, () {
      return AudioPool.create(
        source: AssetSource(assetPath, mimeType: _mp3MimeType),
        maxPlayers: maxPlayers,
        minPlayers: 1,
        playerMode: PlayerMode.lowLatency,
        audioContext: _audioContext ??= _buildAudioContext(),
      ).then((pool) {
        _assetPools[assetPath] = pool;
        return pool;
      }).whenComplete(() {
        _assetPoolFutures.remove(assetPath);
      });
    });
  }

  static String? _soundKeyForTone(String toneName) {
    if (toneName == 'comment' ||
        toneName == 'connection_success' ||
        toneName == 'connection_failure') {
      return toneName;
    }
    if (toneName == 'rare_small' || toneName.startsWith('small')) {
      return 'gift_small';
    }
    if (toneName == 'rare_medium' || toneName.startsWith('medium')) {
      return 'gift_big';
    }
    if (toneName == 'rare_large' || toneName.startsWith('large')) {
      return 'gift_big';
    }
    return null;
  }

  static String? _assetPathForSoundKey(String soundKey) {
    return switch (soundKey) {
      'comment' => 'audio/comment_pop.mp3',
      'connection_success' => 'audio/connect_success.mp3',
      'connection_failure' => 'audio/connect_error.mp3',
      'gift_small' => 'audio/gift_small.mp3',
      'gift_big' => 'audio/gift_big.mp3',
      'gift_premium' => 'audio/gift_premium.mp3',
      'follow' => 'audio/follow.mp3',
      'like_rush' => 'audio/like_rush.mp3',
      _ => null,
    };
  }

  static bool _isAssetNotFoundError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unable to load asset') ||
        message.contains('asset not found') ||
        message.contains('not found') ||
        message.contains('404') ||
        message.contains('does not exist');
  }

  Future<void> _doPrimeForPlayback() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) {
      return;
    }

    if (!kIsWeb || _webAudioUnlocked) {
      return;
    }

    final pool = _pools.values.firstOrNull;
    if (pool == null) {
      return;
    }

    try {
      final stop = await pool.start(volume: 0.001);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await stop();
      _webAudioUnlocked = true;
      AppLogger.info('Effect sound unlocked for web playback');
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Effect sound web unlock failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  int _comboTier(int comboStreak) {
    if (comboStreak >= 10) return 3;
    if (comboStreak >= 5) return 2;
    if (comboStreak >= 3) return 1;
    return 0;
  }

  Future<void> _playSmallGiftCombo(double randomVal, int comboTier) async {
    if (comboTier == 1) {
      if (randomVal < 0.03) {
        await _playTone('rare_small');
      } else {
        await _playTone('small_combo_3_4');
      }
      return;
    }

    if (comboTier == 2) {
      if (randomVal < 0.04) {
        await _playTone('rare_small');
      } else {
        await _playTone('small_combo_5_9');
        _playToneAfter(
          const Duration(milliseconds: 58),
          'small_1',
          volumeScale: 0.72,
        );
      }
      return;
    }

    await _playTone('small_combo_10');
    if (randomVal < 0.06) {
      _playToneAfter(
        const Duration(milliseconds: 36),
        'rare_small',
        volumeScale: 0.62,
      );
    } else {
      _playToneAfter(
        const Duration(milliseconds: 44),
        'small_2',
        volumeScale: 0.80,
      );
    }
  }

  Future<void> _playMediumGiftCombo(double randomVal, int comboTier) async {
    if (comboTier == 0) {
      if (randomVal < 0.03) {
        await _playTone('rare_medium');
      } else {
        await _playTone('medium');
      }
      return;
    }

    if (comboTier == 1) {
      if (randomVal < 0.04) {
        await _playTone('rare_medium');
      } else {
        await _playTone('medium_combo_3_4');
      }
      return;
    }

    if (comboTier == 2) {
      if (randomVal < 0.05) {
        await _playTone('rare_medium');
      } else {
        await _playTone('medium_combo_5_9');
        _playToneAfter(
          const Duration(milliseconds: 90),
          'small_combo_3_4',
          volumeScale: 0.66,
        );
      }
      return;
    }

    if (randomVal < 0.06) {
      await _playTone('rare_medium');
    } else {
      await _playTone('medium_combo_10');
      _playToneAfter(
        const Duration(milliseconds: 76),
        'small_combo_5_9',
        volumeScale: 0.72,
      );
    }
  }

  Future<void> _playHighGiftCombo(double randomVal, int comboTier) async {
    if (comboTier == 0) {
      if (randomVal < 0.03) {
        await _playTone('rare_large');
      } else {
        await _playTone('large');
      }
      return;
    }

    if (comboTier == 1) {
      if (randomVal < 0.04) {
        await _playTone('rare_large');
      } else {
        await _playTone('large_combo_3_4');
      }
      return;
    }

    if (comboTier == 2) {
      if (randomVal < 0.05) {
        await _playTone('rare_large');
      } else {
        await _playTone('large_combo_5_9');
        _playToneAfter(
          const Duration(milliseconds: 124),
          'small_combo_5_9',
          volumeScale: 0.60,
        );
      }
      return;
    }

    if (randomVal < 0.06) {
      await _playTone('rare_large');
    } else {
      await _playTone('large_combo_10');
      _playToneAfter(
        const Duration(milliseconds: 112),
        'medium_combo_3_4',
        volumeScale: 0.68,
      );
    }
  }

  Future<void> _playPremiumGift() async {
    await _playTone('rare_large', assetKey: 'gift_premium');
  }

  void _playToneAfter(
    Duration delay,
    String toneName, {
    double volumeScale = 1.0,
    bool preferAsset = false,
  }) {
    final generation = _pendingTonesGeneration;
    unawaited(
      Future<void>.delayed(delay, () async {
        if (_pendingTonesGeneration != generation) return;
        await _playTone(
          toneName,
          volumeScale: volumeScale,
          preferAsset: preferAsset,
        );
      }),
    );
  }

  double _resolvedVolumeForTone(String toneName) {
    final categoryScale = toneName == 'comment'
        ? 0.68
        : toneName == 'connection_success'
            ? 0.74
            : toneName == 'connection_failure'
                ? 0.66
                : toneName == 'rare_small'
                    ? 0.82
                    : toneName == 'rare_medium' || toneName.startsWith('medium')
                        ? 0.90
                        : toneName == 'rare_large' ||
                                toneName.startsWith('large')
                            ? 0.94
                            : toneName.startsWith('small')
                                ? 0.84
                                : 1.0;

    final ttsDuckScale = !ttsService.isPlaying
        ? 1.0
        : toneName == 'comment'
            ? 0.50
            : toneName == 'connection_success' ||
                    toneName == 'connection_failure'
                ? 0.70
                : toneName == 'rare_small'
                    ? 0.66
                    : toneName == 'rare_medium' || toneName.startsWith('medium')
                        ? 0.78
                        : toneName == 'rare_large' ||
                                toneName.startsWith('large')
                            ? 0.84
                            : toneName.startsWith('small')
                                ? 0.68
                                : 0.85;

    return (_volume * categoryScale * ttsDuckScale).clamp(0.0, 1.0);
  }

  static _GeneratedEffectTone _generateTone(
    List<_ToneNote> notes,
    double leadIn,
    double tail,
    double harmonic, {
    double interNoteGap = 0.004,
  }) {
    return _GeneratedEffectTone(
      bytes: _buildSequenceWav(
        notes,
        leadInSilence: leadIn,
        tailSilence: tail,
        harmonicMix: harmonic,
        interNoteGap: interNoteGap,
      ),
      duration: _sequenceDuration(
        notes,
        leadInSilence: leadIn,
        tailSilence: tail,
        interNoteGap: interNoteGap,
      ),
    );
  }

  static _GeneratedEffectTone _buildCommentTone() {
    return _generateTone(
      const [
        _ToneNote(1720, 0.016, 0.34),
        _ToneNote(2280, 0.024, 0.24),
      ],
      0.001,
      0.008,
      0.06,
    );
  }

  static _GeneratedEffectTone _buildConnectionSuccessTone() {
    return _generateTone(
      const [
        _ToneNote(880, 0.026, 0.24),
        _ToneNote(1320, 0.052, 0.32),
      ],
      0.001,
      0.018,
      0.10,
      interNoteGap: 0.004,
    );
  }

  static _GeneratedEffectTone _buildConnectionFailureTone() {
    return _generateTone(
      const [
        _ToneNote(520, 0.034, 0.26),
        _ToneNote(360, 0.056, 0.30),
      ],
      0.001,
      0.020,
      0.06,
      interNoteGap: 0.004,
    );
  }

  static _GeneratedEffectTone _buildSmallCrystal() {
    return _generateTone(
      const [
        _ToneNote(880, 0.020, 0.30),
        _ToneNote(1180, 0.042, 0.38),
      ],
      0.002,
      0.014,
      0.10,
    );
  }

  static _GeneratedEffectTone _buildSmallBubble() {
    return _generateTone(
      const [
        _ToneNote(760, 0.024, 0.26),
        _ToneNote(980, 0.032, 0.30),
      ],
      0.002,
      0.01,
      0.06,
    );
  }

  static _GeneratedEffectTone _buildSmallCoin() {
    return _generateTone(
      const [
        _ToneNote(900, 0.018, 0.28),
        _ToneNote(1260, 0.044, 0.36),
      ],
      0.001,
      0.014,
      0.12,
    );
  }

  static _GeneratedEffectTone _buildHeartMeTone() {
    return _generateTone(
      const [
        _ToneNote(1046, 0.020, 0.24),
        _ToneNote(1568, 0.026, 0.32),
        _ToneNote(2093, 0.052, 0.38),
      ],
      0.001,
      0.018,
      0.12,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildSmallComboScale(double pitchMulti) {
    return _generateTone(
      [
        _ToneNote(660 * pitchMulti, 0.045, 0.38),
      ],
      0.002,
      0.01,
      0.05,
    );
  }

  static _GeneratedEffectTone _buildSmallComboTier1() {
    return _generateTone(
      const [
        _ToneNote(880, 0.020, 0.30),
        _ToneNote(1220, 0.038, 0.40),
      ],
      0.001,
      0.012,
      0.10,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildSmallComboTier2() {
    return _generateTone(
      const [
        _ToneNote(820, 0.018, 0.28),
        _ToneNote(1080, 0.022, 0.32),
        _ToneNote(1380, 0.034, 0.42),
      ],
      0.001,
      0.012,
      0.12,
      interNoteGap: 0.0025,
    );
  }

  static _GeneratedEffectTone _buildSmallComboTier3() {
    return _generateTone(
      const [
        _ToneNote(920, 0.016, 0.26),
        _ToneNote(1180, 0.020, 0.30),
        _ToneNote(1520, 0.028, 0.38),
        _ToneNote(1880, 0.034, 0.46),
      ],
      0.001,
      0.012,
      0.14,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildRareSmallHit() {
    return _generateTone(
      const [
        _ToneNote(980, 0.018, 0.34),
        _ToneNote(1320, 0.022, 0.38),
        _ToneNote(1760, 0.050, 0.42),
      ],
      0.001,
      0.018,
      0.18,
    );
  }

  static _GeneratedEffectTone _buildMediumLevelUp() {
    return _generateTone(
      const [
        _ToneNote(660, 0.036, 0.25),
        _ToneNote(880, 0.040, 0.30),
        _ToneNote(1174, 0.050, 0.36),
        _ToneNote(1568, 0.068, 0.42),
      ],
      0.003,
      0.024,
      0.16,
    );
  }

  static _GeneratedEffectTone _buildMediumComboTier1() {
    return _generateTone(
      const [
        _ToneNote(740, 0.034, 0.24),
        _ToneNote(988, 0.036, 0.30),
        _ToneNote(1318, 0.046, 0.36),
        _ToneNote(1760, 0.062, 0.44),
      ],
      0.003,
      0.022,
      0.18,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildMediumComboTier2() {
    return _generateTone(
      const [
        _ToneNote(784, 0.030, 0.24),
        _ToneNote(1046, 0.032, 0.30),
        _ToneNote(1318, 0.040, 0.36),
        _ToneNote(1568, 0.050, 0.42),
        _ToneNote(1976, 0.064, 0.48),
      ],
      0.002,
      0.020,
      0.18,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildMediumComboTier3() {
    return _generateTone(
      const [
        _ToneNote(880, 0.028, 0.24),
        _ToneNote(1174, 0.030, 0.30),
        _ToneNote(1480, 0.038, 0.36),
        _ToneNote(1760, 0.046, 0.42),
        _ToneNote(2217, 0.058, 0.50),
      ],
      0.002,
      0.020,
      0.20,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildRareFever() {
    return _generateTone(
      const [
        _ToneNote(1046, 0.028, 0.34),
        _ToneNote(1318, 0.028, 0.36),
        _ToneNote(1046, 0.028, 0.32),
        _ToneNote(1568, 0.036, 0.40),
        _ToneNote(2093, 0.070, 0.48),
      ],
      0.002,
      0.030,
      0.24,
    );
  }

  static _GeneratedEffectTone _buildLargeFanfare() {
    return _generateTone(
      const [
        _ToneNote(587, 0.045, 0.22),
        _ToneNote(784, 0.050, 0.28),
        _ToneNote(988, 0.056, 0.34),
        _ToneNote(1318, 0.064, 0.40),
        _ToneNote(1661, 0.095, 0.48),
      ],
      0.003,
      0.035,
      0.18,
    );
  }

  static _GeneratedEffectTone _buildLargeComboTier1() {
    return _generateTone(
      const [
        _ToneNote(622, 0.042, 0.22),
        _ToneNote(830, 0.046, 0.28),
        _ToneNote(1046, 0.052, 0.34),
        _ToneNote(1396, 0.060, 0.40),
        _ToneNote(1760, 0.105, 0.50),
      ],
      0.003,
      0.034,
      0.20,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildLargeComboTier2() {
    return _generateTone(
      const [
        _ToneNote(659, 0.038, 0.22),
        _ToneNote(880, 0.044, 0.28),
        _ToneNote(1174, 0.050, 0.34),
        _ToneNote(1568, 0.058, 0.40),
        _ToneNote(1976, 0.118, 0.52),
      ],
      0.003,
      0.032,
      0.20,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildLargeComboTier3() {
    return _generateTone(
      const [
        _ToneNote(740, 0.034, 0.22),
        _ToneNote(988, 0.038, 0.28),
        _ToneNote(1318, 0.046, 0.34),
        _ToneNote(1661, 0.052, 0.40),
        _ToneNote(2093, 0.064, 0.46),
        _ToneNote(2489, 0.120, 0.54),
      ],
      0.003,
      0.032,
      0.22,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildRareJackpot() {
    final List<_ToneNote> n = [];
    for (int i = 0; i < 6; i++) {
      n.add(_ToneNote(1400 + (i % 2) * 360, 0.024, 0.34));
    }
    n.add(const _ToneNote(2350, 0.090, 0.50));
    return _generateTone(n, 0.002, 0.035, 0.26);
  }

  static Duration _sequenceDuration(
    List<_ToneNote> notes, {
    required double leadInSilence,
    required double tailSilence,
    required double interNoteGap,
  }) {
    final seconds = notes.fold<double>(
          leadInSilence + tailSilence,
          (sum, note) => sum + note.durationSeconds,
        ) +
        (notes.length - 1) * interNoteGap;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  static Uint8List _buildSequenceWav(
    List<_ToneNote> notes, {
    required double leadInSilence,
    required double tailSilence,
    required double harmonicMix,
    required double interNoteGap,
  }) {
    const sampleRate = 22050;
    const channelCount = 1;
    const bitsPerSample = 16;

    final totalSeconds = notes.fold<double>(
          leadInSilence + tailSilence,
          (sum, note) => sum + note.durationSeconds,
        ) +
        (notes.length - 1) * interNoteGap;
    final totalSamples = math.max(1, (totalSeconds * sampleRate).round());

    final pcm = Int16List(totalSamples);
    var cursor = leadInSilence;

    for (final note in notes) {
      final noteStart = (cursor * sampleRate).round();
      final noteSamples =
          math.max(1, (note.durationSeconds * sampleRate).round());
      for (var i = 0; i < noteSamples && noteStart + i < pcm.length; i++) {
        final t = i / sampleRate;
        final progress = i / noteSamples;
        final envelope = _envelope(progress);
        final fundamental = math.sin(2 * math.pi * note.frequency * t);
        final harmonic = math.sin(2 * math.pi * note.frequency * 2.0 * t);
        final shimmer = math.sin(2 * math.pi * (note.frequency * 0.5) * t);
        final sample = note.amplitude *
            envelope *
            (fundamental +
                (harmonic * harmonicMix) +
                (shimmer * 0.08 * (1.0 - progress)));
        final mixed = pcm[noteStart + i] / 32767.0 + sample;
        pcm[noteStart + i] = _toPcm16(mixed.clamp(-1.0, 1.0).toDouble());
      }
      cursor += note.durationSeconds + interNoteGap;
    }

    return _encodeWav(
      pcm,
      sampleRate: sampleRate,
      channelCount: channelCount,
      bitsPerSample: bitsPerSample,
    );
  }

  static double _envelope(double progress) {
    const attack = 0.12;
    const release = 0.28;

    if (progress <= attack) {
      return progress / attack;
    }
    if (progress >= 1.0 - release) {
      return (1.0 - progress) / release;
    }
    return 1.0;
  }

  static int _toPcm16(double sample) {
    final scaled = (sample * 32767.0).round();
    return scaled.clamp(-32768, 32767);
  }

  static Uint8List _encodeWav(
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
}

class _GeneratedEffectTone {
  final Uint8List bytes;
  final Duration duration;

  const _GeneratedEffectTone({
    required this.bytes,
    required this.duration,
  });
}

class _ToneNote {
  final double frequency;
  final double durationSeconds;
  final double amplitude;

  const _ToneNote(
    this.frequency,
    this.durationSeconds,
    this.amplitude,
  );
}

final effectSoundService = EffectSoundService.instance;

enum _GiftSoundTier {
  fallback,
  bronze,
  silver,
  gold,
  premium,
}
