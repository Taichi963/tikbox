import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
  });

  group('EffectSoundService gift tiers', () {
    test('classifies boundary values safely', () {
      expect(EffectSoundService.debugGiftSoundTierName(-1), 'fallback');
      expect(EffectSoundService.debugGiftSoundTierName(0), 'fallback');
      expect(EffectSoundService.debugGiftSoundTierName(1), 'small');
      expect(EffectSoundService.debugGiftSoundTierName(9), 'small');
      expect(EffectSoundService.debugGiftSoundTierName(10), 'medium');
      expect(EffectSoundService.debugGiftSoundTierName(99), 'medium');
      expect(EffectSoundService.debugGiftSoundTierName(100), 'large');
      expect(EffectSoundService.debugGiftSoundTierName(999), 'large');
      expect(EffectSoundService.debugGiftSoundTierName(1000), 'ultraRare');
    });

    test('detects Heart Me gift names safely', () {
      expect(EffectSoundService.debugIsHeartMeGift('Heart Me'), isTrue);
      expect(EffectSoundService.debugIsHeartMeGift('heart-me'), isTrue);
      expect(EffectSoundService.debugIsHeartMeGift('ハートミー'), isTrue);
      expect(EffectSoundService.debugIsHeartMeGift('Rose'), isFalse);
      expect(EffectSoundService.debugIsHeartMeGift(null), isFalse);
    });
  });
}

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

int _dataLength(Uint8List bytes) {
  return ByteData.sublistView(bytes).getUint32(40, Endian.little);
}
