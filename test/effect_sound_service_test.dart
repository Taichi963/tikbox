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
}

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

int _dataLength(Uint8List bytes) {
  return ByteData.sublistView(bytes).getUint32(40, Endian.little);
}
