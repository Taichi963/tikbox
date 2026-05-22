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
  static const Duration _poolStopPadding = Duration(milliseconds: 24);
  static const int _mediumGiftValueThreshold = 10;
  static const int _highGiftValueThreshold = 100;

  final Map<String, _GeneratedEffectTone> _tones = {};
  final Map<String, AudioPool> _pools = {};

  Future<void>? _initializeFuture;
  Future<void>? _primeFuture;
  bool _initialized = false;
  bool _webAudioUnlocked = false;
  bool _giftSoundEnabled = true;
  double _volume = 0.85;

  final math.Random _random = math.Random();

  @visibleForTesting
  static Uint8List debugBuildCommentWav() => _buildCommentTone().bytes;

  @visibleForTesting
  static Uint8List debugBuildGiftWav() => _buildSmallCrystal().bytes;

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
      final context = kIsWeb
          ? null
          : AudioContextConfig(
              focus: AudioContextConfigFocus.mixWithOthers,
              stayAwake: true,
            ).build();

      _tones['comment'] = _buildCommentTone();
      _tones['small_0'] = _buildSmallCrystal();
      _tones['small_1'] = _buildSmallBubble();
      _tones['small_2'] = _buildSmallCoin();
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
    } catch (error, stackTrace) {
      _initialized = false;
      final poolsToDispose = _pools.values.toList(growable: false);
      _pools.clear();
      _tones.clear();
      for (final pool in poolsToDispose) {
        try {
          await pool.dispose();
        } catch (_) {}
      }
      AppLogger.error(
        'Effect sound initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> playComment() async {
    await _playTone('comment');
  }

  Future<void> playGiftEvent({
    required int value,
    required int comboStreak,
  }) async {
    if (!_giftSoundEnabled) {
      return;
    }

    final randomVal = _random.nextDouble();
    final comboTier = _comboTier(comboStreak);

    if (value >= _highGiftValueThreshold) {
      await _playHighGiftCombo(randomVal, comboTier);
      return;
    }

    if (value >= _mediumGiftValueThreshold) {
      await _playMediumGiftCombo(randomVal, comboTier);
      return;
    }

    if (comboTier > 0) {
      await _playSmallGiftCombo(randomVal, comboTier);
      return;
    }

    if (randomVal < 0.03) {
      await _playTone('rare_small');
    } else {
      final variation = _random.nextInt(3);
      await _playTone('small_$variation');
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
  }

  double get volume => _volume;

  void setGiftSoundEnabled(bool enabled) {
    _giftSoundEnabled = enabled;
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
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) {
      return;
    }

    final pool = _pools[toneName];
    final tone = _tones[toneName];
    if (pool == null || tone == null) {
      return;
    }

    try {
      final stop = await pool.start(
        volume: (_resolvedVolumeForTone(toneName) * volumeScale).clamp(0.0, 1.0),
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
      if (randomVal < 0.05) {
        await _playTone('rare_small');
      } else {
        await _playTone('small_combo_3_4');
      }
      return;
    }

    if (comboTier == 2) {
      if (randomVal < 0.08) {
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
    if (randomVal < 0.14) {
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
      if (randomVal < 0.05) {
        await _playTone('rare_medium');
      } else {
        await _playTone('medium');
      }
      return;
    }

    if (comboTier == 1) {
      if (randomVal < 0.06) {
        await _playTone('rare_medium');
      } else {
        await _playTone('medium_combo_3_4');
      }
      return;
    }

    if (comboTier == 2) {
      if (randomVal < 0.09) {
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

    if (randomVal < 0.11) {
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
      if (randomVal < 0.05) {
        await _playTone('rare_large');
      } else {
        await _playTone('large');
      }
      return;
    }

    if (comboTier == 1) {
      if (randomVal < 0.06) {
        await _playTone('rare_large');
      } else {
        await _playTone('large_combo_3_4');
      }
      return;
    }

    if (comboTier == 2) {
      if (randomVal < 0.08) {
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

    if (randomVal < 0.10) {
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

  void _playToneAfter(
    Duration delay,
    String toneName, {
    double volumeScale = 1.0,
  }) {
    unawaited(
      Future<void>.delayed(delay, () async {
        await _playTone(
          toneName,
          volumeScale: volumeScale,
        );
      }),
    );
  }

  double _resolvedVolumeForTone(String toneName) {
    final categoryScale = toneName == 'comment'
        ? 0.72
        : toneName == 'rare_small'
        ? 0.92
        : toneName == 'rare_medium' || toneName.startsWith('medium')
        ? 0.96
        : toneName == 'rare_large' || toneName.startsWith('large')
        ? 1.0
        : toneName.startsWith('small')
        ? 0.88
        : 1.0;

    final ttsDuckScale = !ttsService.isPlaying
        ? 1.0
        : toneName == 'comment'
        ? 0.55
        : toneName == 'rare_small'
        ? 0.76
        : toneName == 'rare_medium' || toneName.startsWith('medium')
        ? 0.86
        : toneName == 'rare_large' || toneName.startsWith('large')
        ? 0.92
        : toneName.startsWith('small')
        ? 0.74
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

  static _GeneratedEffectTone _buildSmallCrystal() {
    return _generateTone(
      const [
        _ToneNote(720, 0.024, 0.34),
        _ToneNote(960, 0.046, 0.40),
      ],
      0.002,
      0.018,
      0.08,
    );
  }

  static _GeneratedEffectTone _buildSmallBubble() {
    return _generateTone(
      const [
        _ToneNote(540, 0.03, 0.30),
        _ToneNote(720, 0.035, 0.24),
      ],
      0.002,
      0.01,
      0.05,
    );
  }

  static _GeneratedEffectTone _buildSmallCoin() {
    return _generateTone(
      const [
        _ToneNote(660, 0.02, 0.30),
        _ToneNote(880, 0.055, 0.38),
      ],
      0.001,
      0.016,
      0.12,
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
        _ToneNote(760, 0.022, 0.34),
        _ToneNote(1020, 0.042, 0.40),
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
        _ToneNote(760, 0.020, 0.30),
        _ToneNote(960, 0.024, 0.34),
        _ToneNote(1180, 0.036, 0.42),
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
        _ToneNote(820, 0.018, 0.28),
        _ToneNote(1040, 0.022, 0.32),
        _ToneNote(1310, 0.030, 0.40),
        _ToneNote(1560, 0.040, 0.46),
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
        _ToneNote(150, 0.02, 0.6),
        _ToneNote(300, 0.02, 0.5),
        _ToneNote(450, 0.04, 0.4),
      ],
      0.001,
      0.01,
      0.8,
    );
  }

  static _GeneratedEffectTone _buildMediumLevelUp() {
    return _generateTone(
      const [
        _ToneNote(523, 0.05, 0.28),
        _ToneNote(659, 0.05, 0.34),
        _ToneNote(784, 0.07, 0.38),
        _ToneNote(1046, 0.11, 0.46),
      ],
      0.003,
      0.03,
      0.18,
    );
  }

  static _GeneratedEffectTone _buildMediumComboTier1() {
    return _generateTone(
      const [
        _ToneNote(550, 0.046, 0.28),
        _ToneNote(698, 0.046, 0.34),
        _ToneNote(880, 0.060, 0.38),
        _ToneNote(1174, 0.090, 0.46),
      ],
      0.003,
      0.026,
      0.20,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildMediumComboTier2() {
    return _generateTone(
      const [
        _ToneNote(587, 0.040, 0.28),
        _ToneNote(740, 0.040, 0.34),
        _ToneNote(932, 0.052, 0.38),
        _ToneNote(1174, 0.070, 0.44),
        _ToneNote(1396, 0.085, 0.48),
      ],
      0.002,
      0.024,
      0.20,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildMediumComboTier3() {
    return _generateTone(
      const [
        _ToneNote(622, 0.038, 0.28),
        _ToneNote(784, 0.038, 0.34),
        _ToneNote(988, 0.048, 0.38),
        _ToneNote(1244, 0.062, 0.44),
        _ToneNote(1568, 0.080, 0.50),
      ],
      0.002,
      0.022,
      0.22,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildRareFever() {
    return _generateTone(
      const [
        _ToneNote(880, 0.04, 0.4),
        _ToneNote(1046, 0.04, 0.4),
        _ToneNote(880, 0.04, 0.4),
        _ToneNote(1046, 0.04, 0.4),
        _ToneNote(1318, 0.1, 0.5),
      ],
      0.002,
      0.05,
      0.4,
    );
  }

  static _GeneratedEffectTone _buildLargeFanfare() {
    return _generateTone(
      const [
        _ToneNote(392, 0.07, 0.24),
        _ToneNote(523, 0.07, 0.30),
        _ToneNote(659, 0.08, 0.36),
        _ToneNote(784, 0.08, 0.40),
        _ToneNote(1046, 0.10, 0.46),
        _ToneNote(1396, 0.24, 0.52),
      ],
      0.004,
      0.05,
      0.2,
    );
  }

  static _GeneratedEffectTone _buildLargeComboTier1() {
    return _generateTone(
      const [
        _ToneNote(415, 0.065, 0.24),
        _ToneNote(554, 0.065, 0.30),
        _ToneNote(698, 0.074, 0.36),
        _ToneNote(830, 0.074, 0.40),
        _ToneNote(1108, 0.090, 0.46),
        _ToneNote(1478, 0.200, 0.52),
      ],
      0.004,
      0.050,
      0.22,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildLargeComboTier2() {
    return _generateTone(
      const [
        _ToneNote(440, 0.060, 0.24),
        _ToneNote(587, 0.060, 0.30),
        _ToneNote(740, 0.070, 0.36),
        _ToneNote(880, 0.070, 0.40),
        _ToneNote(1174, 0.080, 0.46),
        _ToneNote(1568, 0.180, 0.52),
      ],
      0.004,
      0.040,
      0.22,
      interNoteGap: 0.003,
    );
  }

  static _GeneratedEffectTone _buildLargeComboTier3() {
    return _generateTone(
      const [
        _ToneNote(466, 0.050, 0.24),
        _ToneNote(622, 0.050, 0.28),
        _ToneNote(784, 0.060, 0.34),
        _ToneNote(932, 0.060, 0.38),
        _ToneNote(1174, 0.070, 0.42),
        _ToneNote(1396, 0.080, 0.48),
        _ToneNote(1760, 0.140, 0.54),
      ],
      0.004,
      0.038,
      0.24,
      interNoteGap: 0.002,
    );
  }

  static _GeneratedEffectTone _buildRareJackpot() {
    final List<_ToneNote> n = [];
    for (int i = 0; i < 8; i++) {
      n.add(_ToneNote(1200 + (i % 2) * 300, 0.03, 0.4));
    }
    n.add(const _ToneNote(1800, 0.15, 0.5));
    return _generateTone(n, 0.002, 0.05, 0.3);
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
