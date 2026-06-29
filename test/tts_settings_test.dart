import 'package:flutter_test/flutter_test.dart';
import 'package:tikbox/models/tts_settings.dart';

void main() {
  group('TtsSettings.voiceKey', () {
    test('produces pipe-separated name|locale|identifier', () {
      const voice = {
        'name': 'Kyoko',
        'locale': 'ja-JP',
        'identifier': 'com.apple.ttsbundle.Kyoko-compact',
      };
      expect(
        TtsSettings.voiceKey(voice),
        'Kyoko|ja-JP|com.apple.ttsbundle.Kyoko-compact',
      );
    });

    test('uses empty string for missing fields', () {
      expect(TtsSettings.voiceKey(const {'name': 'Test'}), 'Test||');
      expect(TtsSettings.voiceKey(const {'locale': 'ja-JP'}), '|ja-JP|');
    });

    test('two voices with same name/locale/identifier produce equal keys', () {
      const a = {'name': 'X', 'locale': 'ja-JP', 'identifier': 'id1'};
      const b = {'name': 'X', 'locale': 'ja-JP', 'identifier': 'id1'};
      expect(TtsSettings.voiceKey(a), TtsSettings.voiceKey(b));
    });

    test('voices differing in any field produce different keys', () {
      const base = {'name': 'X', 'locale': 'ja-JP', 'identifier': 'id1'};
      const diffName = {'name': 'Y', 'locale': 'ja-JP', 'identifier': 'id1'};
      const diffLocale = {'name': 'X', 'locale': 'en-US', 'identifier': 'id1'};
      const diffId = {'name': 'X', 'locale': 'ja-JP', 'identifier': 'id2'};
      expect(TtsSettings.voiceKey(diffName), isNot(TtsSettings.voiceKey(base)));
      expect(TtsSettings.voiceKey(diffLocale), isNot(TtsSettings.voiceKey(base)));
      expect(TtsSettings.voiceKey(diffId), isNot(TtsSettings.voiceKey(base)));
    });
  });

  group('TtsSettings', () {
    test('defaults gift vibration to enabled', () {
      const settings = TtsSettings();

      expect(settings.giftVibrationEnabled, isTrue);
      expect(TtsSettings.fromJson({}).giftVibrationEnabled, isTrue);
    });

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
