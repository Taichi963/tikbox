import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tts_settings.dart';
import '../../widgets/comment_animation.dart';
import '../../widgets/gift_animation.dart';
import '../../widgets/neon_effect.dart';
import '../../services/tts_service.dart';
import '../live/live_provider.dart';
import 'main_provider.dart';
import 'tts_provider.dart';

const String _lastUsernameKey = 'tikbox_last_username_v1';

/// MVP: 接続・TTS・最小設定のコメント一覧のみ
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _cookieController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSavedUsername());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(_lastUsernameKey)?.trim();
    if (!mounted || savedUsername == null || savedUsername.isEmpty) {
      return;
    }
    if (_usernameController.text.trim().isNotEmpty) {
      return;
    }
    _usernameController.text = savedUsername;
  }

  Future<void> _saveUsernameIfNeeded(String rawUsername) async {
    final normalized = rawUsername
        .trim()
        .replaceAll('@', '')
        .replaceAll(
          RegExp(r'https?://(www\.)?tiktok\.com/@?', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\?.*$'), '')
        .replaceAll('/', '');
    if (normalized.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsernameKey, normalized);
  }

  @override
  Widget build(BuildContext context) {
    final isLive = ref.watch(mainProvider.select((s) => s.isLive));
    final connectedUsername =
        ref.watch(mainProvider.select((s) => s.connectedUsername));
    final liveState = ref.watch(liveProvider);
    final ttsSettings = ref.watch(ttsSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF050815),
      body: Stack(
        children: [
          const Positioned.fill(child: _BuzzBackground()),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => ref.read(liveProvider.notifier).skipCurrentTts(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _RecordingHud(isLive: isLive),
                        ),
                        const SizedBox(width: 10),
                        _HudIconButton(
                          icon: Icons.tune_rounded,
                          glowColor: const Color(0xFFEF6CFF),
                          onTap: () => _openSettings(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NeonPanel(
                      glowColor: isLive
                          ? const Color(0xFFFF4F7D)
                          : const Color(0xFF00E5FF),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: NeonText(
                                  isLive ? 'LIVE 接続中' : 'LIVE 接続待機中',
                                  glowColor: isLive
                                      ? const Color(0xFFFF6D91)
                                      : const Color(0xFF72F6FF),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              if (isLive) const LiveGlowDot(),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _usernameController,
                            enabled: !liveState.isConnecting && !isLive,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              labelText: 'TikTok username',
                              hintText: 'example_user',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.34),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color(0xFF72F6FF)
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _cookieController,
                            enabled: !liveState.isConnecting && !isLive,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Cookie (18+配信のみ必須)',
                              hintText: 'sessionid=xxx; sid_tt=xxx',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.34),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color(0xFF72F6FF)
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _PrimaryLiveButton(
                                  isLive: isLive,
                                  isConnecting: liveState.isConnecting,
                                  onPressed: () async {
                                    if (liveState.isConnecting || isLive) {
                                      await ref
                                          .read(liveProvider.notifier)
                                          .stopLive();
                                      return;
                                    }
                                    await _saveUsernameIfNeeded(
                                      _usernameController.text,
                                    );
                                    await ref
                                        .read(liveProvider.notifier)
                                        .startLive(
                                          _usernameController.text,
                                          cookie: _cookieController.text.trim().isEmpty ? null : _cookieController.text,
                                        );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatusChip(
                                  label: _statusLabel(liveState.wsStatus),
                                  accent: _statusColor(liveState.wsStatus),
                                ),
                              ),
                            ],
                          ),
                          if (liveState.isConnecting) ...[
                            const SizedBox(height: 14),
                            const LinearProgressIndicator(
                              minHeight: 4,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(999)),
                              backgroundColor: Color(0x22FFFFFF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFC64C),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoPill(
                                label: connectedUsername == null
                                    ? '未接続'
                                    : '@$connectedUsername',
                                accent: const Color(0xFF72F6D0),
                                icon: Icons.person_rounded,
                              ),
                              _InfoPill(
                                label:
                                    '話速: ${ttsSettings.rate.toStringAsFixed(2)}',
                                accent: const Color(0xFF6BA8FF),
                                icon: Icons.graphic_eq_rounded,
                              ),
                              _InfoPill(
                                label:
                                    'ピッチ: ${ttsSettings.pitch.toStringAsFixed(2)}',
                                accent: const Color(0xFFEF6CFF),
                                icon: Icons.multitrack_audio_rounded,
                              ),
                            ],
                          ),
                          if (liveState.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _ErrorActionCard(
                              message: liveState.errorMessage!,
                              onRetry: liveState.isConnecting
                                  ? null
                                  : ref
                                      .read(liveProvider.notifier)
                                      .retryConnection,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Expanded(child: _CommentSection()),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: _GiftOverlaySection()),
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1020),
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(ttsSettingsProvider);
            final notifier = ref.read(ttsSettingsProvider.notifier);
            final giftSoundEnabled = notifier.giftSoundEnabled;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SingleChildScrollView(
                  child: NeonPanel(
                    glowColor: const Color(0xFFEF6CFF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const NeonText(
                          '読み上げ（最小設定）',
                          glowColor: Color(0xFFEF6CFF),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '音プリセット',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: SoundPreset.values.map((preset) {
                            final selected = current.soundPreset == preset;
                            return ChoiceChip(
                              label: Text(
                                preset.label,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: selected ? 0.96 : 0.78,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: const Color(
                                0xFF72F6FF,
                              ).withValues(alpha: 0.18),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFF72F6FF)
                                    : Colors.white.withValues(alpha: 0.16),
                              ),
                              onSelected: (_) {
                                notifier.applySoundPreset(preset);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _LabeledSlider(
                          label: '話速',
                          valueText: current.rate.toStringAsFixed(2),
                          value: current.rate,
                          min: 0.3,
                          max: 1.0,
                          divisions: 14,
                          onChanged: notifier.setRate,
                        ),
                        _LabeledSlider(
                          label: 'ピッチ',
                          valueText: current.pitch.toStringAsFixed(2),
                          value: current.pitch,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          onChanged: notifier.setPitch,
                        ),
                        _LabeledSlider(
                          label: 'TTS音量',
                          valueText: current.ttsVolume.toStringAsFixed(2),
                          value: current.ttsVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: notifier.setTtsVolume,
                        ),
                        _LabeledSlider(
                          label: '効果音音量',
                          valueText: current.effectVolume.toStringAsFixed(2),
                          value: current.effectVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: notifier.setEffectVolume,
                        ),
                        SwitchListTile.adaptive(
                          value: giftSoundEnabled,
                          onChanged: notifier.setGiftSoundEnabled,
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: const Color(0xFF72F6FF),
                          title: const Text(
                            'ギフト音',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'ギフト受信時の効果音だけを切り替えます',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.35,
                            ),
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: current.keepScreenOn,
                          onChanged: notifier.setKeepScreenOn,
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: const Color(0xFF72F6FF),
                          title: const Text(
                            '配信中はスリープしない',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'LIVE接続中のみ画面を起こしたままにします',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await ttsService.speak(
                              'TikBox の読み上げテストです',
                            );
                          },
                          icon: const Icon(Icons.record_voice_over_rounded),
                          label: const Text('読み上げテスト'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(WsStatus status) {
    switch (status) {
      case WsStatus.disconnected:
        return '未接続';
      case WsStatus.connecting:
        return '接続中';
      case WsStatus.connected:
        return '接続済み';
      case WsStatus.error:
        return 'エラー';
    }
  }

  Color _statusColor(WsStatus status) {
    switch (status) {
      case WsStatus.disconnected:
        return const Color(0xFF8A9DBB);
      case WsStatus.connecting:
        return const Color(0xFFFFC64C);
      case WsStatus.connected:
        return const Color(0xFF63FFD7);
      case WsStatus.error:
        return const Color(0xFFFF5E7A);
    }
  }
}

class _BuzzBackground extends StatelessWidget {
  const _BuzzBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF040611),
            Color(0xFF0A1022),
            Color(0xFF11081E),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -40,
            child: _GlowOrb(size: 220, color: Color(0xFF00E5FF)),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _GlowOrb(size: 240, color: Color(0xFFFF3F7A)),
          ),
          Positioned(
            bottom: -60,
            left: 50,
            child: _GlowOrb(size: 260, color: Color(0xFF8D4CFF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.38),
              color.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingHud extends StatefulWidget {
  final bool isLive;

  const _RecordingHud({required this.isLive});

  @override
  State<_RecordingHud> createState() => _RecordingHudState();
}

class _RecordingHudState extends State<_RecordingHud> {
  Timer? _timer;
  DateTime? _startedAt;

  @override
  void didUpdateWidget(covariant _RecordingHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !oldWidget.isLive) {
      _startedAt = DateTime.now();
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.isLive && oldWidget.isLive) {
      _startedAt = null;
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return NeonPanel(
      glowColor:
          widget.isLive ? const Color(0xFFFF4F7D) : const Color(0xFF6BA8FF),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (widget.isLive) const LiveGlowDot() else const Icon(Icons.videocam),
          const SizedBox(width: 10),
          NeonText(
            widget.isLive ? 'REC  $mm:$ss' : 'STANDBY',
            glowColor: widget.isLive
                ? const Color(0xFFFF4F7D)
                : const Color(0xFF6BA8FF),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final Color glowColor;
  final VoidCallback? onTap;

  const _HudIconButton({
    required this.icon,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: NeonPanel(
        glowColor: glowColor,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PrimaryLiveButton extends StatelessWidget {
  final bool isLive;
  final bool isConnecting;
  final Future<void> Function() onPressed;

  const _PrimaryLiveButton({
    required this.isLive,
    required this.isConnecting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isConnecting
        ? const Color(0xFFFFC64C)
        : isLive
        ? const Color(0xFFFF4F7D)
        : const Color(0xFF58F5D1);
    final label = isConnecting
        ? 'Cancel Connect'
        : isLive
        ? 'Stop Live'
        : 'Connect Live';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.72)],
        ),
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color accent;
  final IconData icon;

  const _InfoPill({
    required this.label,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorActionCard extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const _ErrorActionCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x22FF5474),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66FF7E96)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF8D9C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '接続トラブル',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('再接続'),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label $valueText',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CommentSection extends ConsumerWidget {
  const _CommentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(mainProvider.select((s) => s.comments));
    return AnimatedCommentList(comments: comments);
  }
}

class _GiftOverlaySection extends ConsumerWidget {
  const _GiftOverlaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(mainProvider.select((s) => s.comments));
    return GiftAnimationOverlay(comments: comments);
  }
}
