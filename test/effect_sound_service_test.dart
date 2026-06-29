import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tikbox/features/live/live_provider.dart';
import 'package:tikbox/services/effect_sound_service.dart';

void main() {
  group('EffectSoundService WAV synthesis', () {
    test('comment tone produces a RIFF/WAVE payload', () {
      final wav = EffectSoundService.debugBuildCommentWav();

      expect(wav, isNotEmpty);
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 36, 4), 'data');
      expect(_dataLength(wav), greaterThan(0));
    });

    test('gift tone is longer than comment tone', () {
      final comment = EffectSoundService.debugBuildCommentWav();
      final gift = EffectSoundService.debugBuildGiftWav();

      expect(gift.length, greaterThan(comment.length));
    });

    test('connection cues produce distinct WAV payloads', () {
      final success = EffectSoundService.debugBuildConnectionSuccessWav();
      final failure = EffectSoundService.debugBuildConnectionFailureWav();

      expect(_ascii(success, 0, 4), 'RIFF');
      expect(_ascii(failure, 0, 4), 'RIFF');
      expect(_dataLength(success), greaterThan(0));
      expect(_dataLength(failure), greaterThan(0));
      expect(success.length, isNot(failure.length));
    });
  });

  group('EffectSoundService gift tiers', () {
    test('classifies boundary values safely', () {
      expect(EffectSoundService.debugGiftSoundTierName(-1), 'fallback');
      expect(EffectSoundService.debugGiftSoundTierName(0), 'fallback');
      expect(EffectSoundService.debugGiftSoundTierName(1), 'bronze');
      expect(EffectSoundService.debugGiftSoundTierName(9), 'bronze');
      expect(EffectSoundService.debugGiftSoundTierName(10), 'silver');
      expect(EffectSoundService.debugGiftSoundTierName(99), 'silver');
      expect(EffectSoundService.debugGiftSoundTierName(100), 'gold');
      expect(EffectSoundService.debugGiftSoundTierName(999), 'gold');
      expect(EffectSoundService.debugGiftSoundTierName(1000), 'premium');
      expect(EffectSoundService.debugGiftSoundTierName(10000), 'premium');
    });

    test('detects Heart Me gift names safely', () {
      expect(EffectSoundService.debugIsHeartMeGift('Heart Me'), isTrue);
      expect(EffectSoundService.debugIsHeartMeGift('heart-me'), isTrue);
      expect(EffectSoundService.debugIsHeartMeGift('ハートミー'), isTrue);
      expect(EffectSoundService.debugIsHeartMeGift('Rose'), isFalse);
      expect(EffectSoundService.debugIsHeartMeGift(null), isFalse);
    });
  });

  group('EffectSoundService pending tone cancellation', () {
    final service = EffectSoundService.instance;

    setUp(() {
      service.resetEngagementSoundCooldowns();
      service.debugResetPlaybackOverrides();
      service.setGiftSoundEnabled(true);
      service.setVolume(0.85);
    });

    tearDown(() {
      service.resetEngagementSoundCooldowns();
      service.debugResetPlaybackOverrides();
    });

    test('resetEngagementSoundCooldowns increments pending tone generation',
        () {
      final before = service.debugPendingTonesGeneration;
      service.resetEngagementSoundCooldowns();
      expect(service.debugPendingTonesGeneration, before + 1);
    });

    test('playGiftEvent increments pending tone generation', () async {
      service.debugSetPlaybackOverrides(
        assetPlayback: (path, vol, dur) async {},
        generatedPlayback: (name, vol) async {},
      );
      final before = service.debugPendingTonesGeneration;
      await service.playGiftEvent(value: 1, comboStreak: 1, giftName: 'Rose');
      expect(service.debugPendingTonesGeneration, greaterThan(before));
    });

    test('cancels secondary combo tones when reset occurs before delay fires',
        () async {
      // Bronze tier comboStreak=10 → comboTier=3 → _playSmallGiftCombo always
      // schedules a secondary tone (rare_small or small_2) via _playToneAfter.
      // Primary 'small_combo_10' starts with 'small' → uses asset path (gift_small).
      // Secondary tones use preferAsset=false → go through generated path.
      final assetPaths = <String>[];
      final generatedTones = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (path, vol, dur) async {
          assetPaths.add(path);
        },
        generatedPlayback: (name, vol) async {
          generatedTones.add(name);
        },
      );

      unawaited(
        service.playGiftEvent(value: 1, comboStreak: 10, giftName: 'Rose'),
      );
      // Duration.zero yields to the event loop after all pending microtasks
      // run, which is enough for the primary tone chain to complete.
      await Future<void>.delayed(Duration.zero);

      // Cancel before the secondary tone fires (delay is 36–44 ms).
      service.resetEngagementSoundCooldowns();

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Primary tone plays via asset path.
      expect(assetPaths, contains('audio/gift_small.mp3'));
      // Secondary tone (preferAsset=false → generated) must have been cancelled.
      expect(generatedTones, isEmpty);
    });

    test('secondary combo tone plays normally when reset does not occur',
        () async {
      final assetPaths = <String>[];
      final generatedTones = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (path, vol, dur) async {
          assetPaths.add(path);
        },
        generatedPlayback: (name, vol) async {
          generatedTones.add(name);
        },
      );

      await service.playGiftEvent(value: 1, comboStreak: 10, giftName: 'Rose');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Primary plays via asset path.
      expect(assetPaths, contains('audio/gift_small.mp3'));
      // Secondary tone (preferAsset=false → generated) plays after the delay.
      expect(
        generatedTones.any((t) => t == 'rare_small' || t == 'small_2'),
        isTrue,
      );
    });
  });

  group('EffectSoundService engagement cooldowns', () {
    final service = EffectSoundService.instance;
    final startedAt = DateTime(2026);

    setUp(service.resetEngagementSoundCooldowns);
    tearDown(service.resetEngagementSoundCooldowns);

    test('suppresses follow sounds for three seconds', () {
      expect(service.debugClaimFollowSoundAt(startedAt), isTrue);
      expect(
        service.debugClaimFollowSoundAt(
          startedAt.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
      expect(
        service.debugClaimFollowSoundAt(
          startedAt.add(EffectSoundService.followSoundCooldown),
        ),
        isTrue,
      );
    });

    test('suppresses like rush sounds for fifteen seconds', () {
      expect(service.debugClaimLikeRushSoundAt(startedAt), isTrue);
      expect(
        service.debugClaimLikeRushSoundAt(
          startedAt.add(const Duration(seconds: 14)),
        ),
        isFalse,
      );
      expect(
        service.debugClaimLikeRushSoundAt(
          startedAt.add(EffectSoundService.likeRushSoundCooldown),
        ),
        isTrue,
      );
    });

    test('reset clears both cooldowns', () {
      expect(service.debugClaimFollowSoundAt(startedAt), isTrue);
      expect(service.debugClaimLikeRushSoundAt(startedAt), isTrue);

      service.resetEngagementSoundCooldowns();

      expect(service.debugClaimFollowSoundAt(startedAt), isTrue);
      expect(service.debugClaimLikeRushSoundAt(startedAt), isTrue);
    });
  });

  group('EffectSoundService asset playback fallback', () {
    final service = EffectSoundService.instance;

    setUp(() {
      service.resetEngagementSoundCooldowns();
      service.debugResetPlaybackOverrides();
      service.setGiftSoundEnabled(true);
      service.setVolume(0.85);
    });

    tearDown(() {
      service.resetEngagementSoundCooldowns();
      service.debugResetPlaybackOverrides();
      service.setGiftSoundEnabled(true);
      service.setVolume(0.85);
    });

    test('maps sound keys to bundled asset paths', () {
      expect(
        EffectSoundService.debugAssetPathForSoundKey('comment'),
        'audio/comment_pop.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('gift_small'),
        'audio/gift_small.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('gift_big'),
        'audio/gift_big.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('gift_premium'),
        'audio/gift_premium.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('follow'),
        'audio/follow.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('like_rush'),
        'audio/like_rush.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('connection_success'),
        'audio/connect_success.mp3',
      );
      expect(
        EffectSoundService.debugAssetPathForSoundKey('connection_failure'),
        'audio/connect_error.mp3',
      );
    });

    test('asset success does not call generated fallback', () async {
      final assetPaths = <String>[];
      final generatedTones = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetPaths.add(assetPath);
        },
        generatedPlayback: (toneName, volume) async {
          generatedTones.add(toneName);
        },
      );

      await service.playFollowSound();

      expect(assetPaths, ['audio/follow.mp3']);
      expect(generatedTones, isEmpty);
    });

    test('asset failure falls back to generated tone once', () async {
      final assetPaths = <String>[];
      final generatedTones = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetPaths.add(assetPath);
          throw StateError('Unable to load asset: $assetPath');
        },
        generatedPlayback: (toneName, volume) async {
          generatedTones.add(toneName);
        },
      );

      await service.playFollowSound();

      expect(assetPaths, ['audio/follow.mp3']);
      expect(generatedTones, ['small_1']);
    });

    test('missing asset is attempted only once per process', () async {
      final assetPaths = <String>[];
      final generatedTones = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetPaths.add(assetPath);
          throw StateError('Unable to load asset: $assetPath');
        },
        generatedPlayback: (toneName, volume) async {
          generatedTones.add(toneName);
        },
      );

      await service.playFollowSound();
      service.resetEngagementSoundCooldowns();
      await service.playFollowSound();

      expect(assetPaths, ['audio/follow.mp3']);
      expect(generatedTones, ['small_1', 'small_1']);
    });

    test('asset path is selected for gift tiers without changing rank logic',
        () async {
      final assetPaths = <String>[];
      final generatedTones = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetPaths.add(assetPath);
        },
        generatedPlayback: (toneName, volume) async {
          generatedTones.add(toneName);
        },
      );

      await service.playGiftEvent(value: 1, comboStreak: 1, giftName: 'Rose');
      await service.playGiftEvent(
        value: 1000,
        comboStreak: 1,
        giftName: 'Rose',
      );

      expect(assetPaths, contains('audio/gift_small.mp3'));
      expect(assetPaths, contains('audio/gift_premium.mp3'));
      expect(generatedTones, isEmpty);
    });

    test('volume is applied to both asset and generated playback paths',
        () async {
      final assetVolumes = <double>[];
      final generatedVolumes = <double>[];

      service.setVolume(0.5);
      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetVolumes.add(volume);
        },
        generatedPlayback: (toneName, volume) async {
          generatedVolumes.add(volume);
        },
      );

      await service.playComment();

      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetVolumes.add(volume);
          throw StateError('Unable to load asset: $assetPath');
        },
        generatedPlayback: (toneName, volume) async {
          generatedVolumes.add(volume);
        },
      );

      await service.playComment();

      expect(assetVolumes, [
        closeTo(0.34, 0.001),
        closeTo(0.34, 0.001),
      ]);
      expect(generatedVolumes, [closeTo(0.34, 0.001)]);
    });

    test('follow cooldown still suppresses repeated asset playback', () async {
      final assetPaths = <String>[];

      service.debugSetPlaybackOverrides(
        assetPlayback: (assetPath, volume, stopAfter) async {
          assetPaths.add(assetPath);
        },
      );

      await service.playFollowSound();
      await service.playFollowSound();

      expect(assetPaths, ['audio/follow.mp3']);
    });
  });

  group('LikeRushTracker', () {
    final startedAt = DateTime(2026);

    test('detects one hundred likes inside thirty seconds', () {
      final tracker = LikeRushTracker();

      expect(tracker.addIncrement(60, startedAt), isFalse);
      expect(
        tracker.addIncrement(40, startedAt.add(const Duration(seconds: 20))),
        isTrue,
      );
      expect(tracker.likeCount, 100);
    });

    test('starts a new bucket after thirty seconds', () {
      final tracker = LikeRushTracker();

      expect(tracker.addIncrement(90, startedAt), isFalse);
      expect(
        tracker.addIncrement(10, startedAt.add(LikeRushTracker.window)),
        isFalse,
      );
      expect(tracker.likeCount, 10);
    });

    test('ignores non-positive increments and resets safely', () {
      final tracker = LikeRushTracker();

      expect(tracker.addIncrement(-1, startedAt), isFalse);
      expect(tracker.likeCount, 0);
      expect(tracker.addIncrement(100, startedAt), isTrue);

      tracker.reset();

      expect(tracker.likeCount, 0);
      expect(tracker.addIncrement(1, startedAt), isFalse);
    });
  });
}

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

int _dataLength(Uint8List bytes) {
  return ByteData.sublistView(bytes).getUint32(40, Endian.little);
}
