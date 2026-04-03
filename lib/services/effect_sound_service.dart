import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class EffectSoundService {
  EffectSoundService._();

  static final EffectSoundService instance = EffectSoundService._();

  static const String _commentAsset = 'audio/comment_pop.mp3';
  static const String _giftAsset = 'audio/gift_flash.mp3';

  AudioPool? _commentPool;
  AudioPool? _giftPool;
  // true = 初期化成功, false = 未初期化 or 失敗済み
  bool _initialized = false;
  double _volume = 0.85;

  // [修正済み]
  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      AppLogger.info('EffectSoundService: Web では効果音を無効化します');
      return;
    }

    try {
      final context = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
        stayAwake: true,
      ).build();

      _commentPool = await AudioPool.create(
        source: AssetSource(_commentAsset),
        maxPlayers: 8,
        minPlayers: 3,
        playerMode: PlayerMode.lowLatency,
        audioContext: context,
      );

      _giftPool = await AudioPool.create(
        source: AssetSource(_giftAsset),
        maxPlayers: 6,
        minPlayers: 2,
        playerMode: PlayerMode.lowLatency,
        audioContext: context,
      );

      _initialized = true;
    } catch (e) {
      // ファイルが存在しない場合は無音で続行
      _initialized = false;
    }
  }

  Future<void> playComment() async {
    if (!_initialized) await initialize();
    if (!_initialized) return; // [修正済み]
    unawaited(_commentPool?.start(volume: _volume));
  }

  Future<void> playGift() async {
    if (!_initialized) await initialize();
    if (!_initialized) return; // [修正済み]
    unawaited(_giftPool?.start(volume: _volume));
  }

  Future<void> playPremiumGift() async {
    if (!_initialized) await initialize();
    if (!_initialized) return; // [修正済み]
    unawaited(_giftPool?.start(volume: _volume));
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        () => _giftPool?.start(volume: _volume),
      ),
    );
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  double get volume => _volume;
}

final effectSoundService = EffectSoundService.instance;
