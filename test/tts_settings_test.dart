import 'package:flutter_test/flutter_test.dart';
import 'package:tikbox/models/tts_settings.dart';

void main() {
  group('TtsSettings', () {
    test('restores persisted values within safe ranges', () {
      final settings = TtsSettings.fromJson({
        'rate': 5.0,
        'pitch': -1.0,
        'ttsVolume': 2.0,
        'effectVolume': -0.5,
        'soundPreset': 'flashy',
        'keepScreenOn': false,
        'giftVibrationEnabled': false,
        'readUsernameEnabled': false,
        'broadcastModeEnabled': true,
      });

      expect(settings.rate, 1.0);
      expect(settings.pitch, 0.5);
      expect(settings.ttsVolume, 1.0);
      expect(settings.effectVolume, 0.0);
      expect(settings.language, TtsSettings.japaneseLanguage);
      expect(settings.soundPreset, SoundPreset.flashy);
      expect(settings.keepScreenOn, isFalse);
      expect(settings.giftVibrationEnabled, isFalse);
      expect(settings.readUsernameEnabled, isFalse);
      expect(settings.broadcastModeEnabled, isTrue);
    });
  });
}
