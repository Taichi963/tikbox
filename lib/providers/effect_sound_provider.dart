import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/effect_sound_service.dart';

/// effectSoundService へのアクセス用プロバイダー。
/// 音量管理は TtsSettingsNotifier が effectSoundService.setVolume() を
/// 直接呼ぶことで一元管理している。
final effectSoundServiceProvider = Provider<EffectSoundService>((ref) {
  return effectSoundService;
});
