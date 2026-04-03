// Main live screen for connecting, reading comments, and sharing standout moments.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_logger.dart';
import '../../widgets/comment_animation.dart';
import '../../widgets/gift_animation.dart';
import '../../widgets/neon_effect.dart';
import '../live/live_provider.dart';
import '../premium/premium_provider.dart';
import 'main_provider.dart';
import 'tts_provider.dart';

const String _tutorialSeenKey = 'tikbox_tutorial_seen_v1';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final GlobalKey _shareBoundaryKey = GlobalKey();
  DateTime? _liveStartedAt;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _showTutorialIfNeeded();
  }

  Future<void> _showTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tutorialSeenKey) ?? false;
    if (seen || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: const Color(0xFF0C1020),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: NeonPanel(
                glowColor: const Color(0xFF72F6FF),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NeonText(
                      '3ステップで開始',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _TutorialStep(
                      index: '1',
                      title: 'TikTokユーザー名を入力',
                      body: '@なしでOK。配信URLを貼っても自動で整形します。',
                    ),
                    const _TutorialStep(
                      index: '2',
                      title: 'LIVEへ接続',
                      body: 'コメント取得とTTS読み上げが始まり、ギフト演出も反応します。',
                    ),
                    const _TutorialStep(
                      index: '3',
                      title: '映えたら共有',
                      body: '共有ボタンでそのままSNSに投稿できます。',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('はじめる'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      await prefs.setBool(_tutorialSeenKey, true);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [修正済み] mainProvider の select を用いて必要な変数のみ監視するよう修正
    final isLive = ref.watch(mainProvider.select((s) => s.isLive));
    final connectedUsername = ref.watch(mainProvider.select((s) => s.connectedUsername));
    final liveState = ref.watch(liveProvider);
    final ttsSettings = ref.watch(ttsSettingsProvider);
    final premiumState = ref.watch(premiumProvider);

    // [修正済み] mainState.isLive を isLive に置き換え
    if (isLive && _liveStartedAt == null) {
      _liveStartedAt = DateTime.now();
    } else if (!isLive) {
      _liveStartedAt = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050815),
      body: RepaintBoundary(
        key: _shareBoundaryKey,
        child: Stack(
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
                            child: _RecordingHud(
                              isLive: isLive, // [修正済み]
                              startedAt: _liveStartedAt,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _HudIconButton(
                            icon: premiumState.isPremium
                                ? Icons.workspace_premium
                                : Icons.lock_open_rounded,
                            glowColor: premiumState.isPremium
                                ? const Color(0xFFFFC64C)
                                : const Color(0xFF72F6FF),
                            onTap: () => _openPremium(context),
                          ),
                          const SizedBox(width: 10),
                          _HudIconButton(
                            icon: Icons.ios_share_rounded,
                            glowColor: const Color(0xFF72F6D0),
                            onTap: _isSharing ? null : _shareCurrentScreen,
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
                        glowColor: isLive // [修正済み]
                            ? const Color(0xFFFF4F7D)
                            : const Color(0xFF00E5FF),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: NeonText(
                                    isLive // [修正済み]
                                        ? 'LIVE 接続中'
                                        : 'LIVE 接続待機中',
                                    glowColor: isLive // [修正済み]
                                        ? const Color(0xFFFF6D91)
                                        : const Color(0xFF72F6FF),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                if (isLive) const LiveGlowDot(), // [修正済み]
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _usernameController,
                              enabled: !liveState.isConnecting && !isLive, // [修正済み]
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
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _PrimaryLiveButton(
                                    isLive: isLive, // [修正済み]
                                    isBusy: liveState.isConnecting,
                                    onPressed: () async {
                                      if (isLive) { // [修正済み]
                                        await ref
                                            .read(liveProvider.notifier)
                                            .stopLive();
                                        return;
                                      }
                                      await ref
                                          .read(liveProvider.notifier)
                                          .startLive(_usernameController.text);
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
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _InfoPill(
                                  label: connectedUsername == null // [修正済み]
                                      ? '接続先なし'
                                      : '@$connectedUsername', // [修正済み]
                                  accent: const Color(0xFF72F6D0),
                                  icon: Icons.person_rounded,
                                ),
                                _InfoPill(
                                  label: '話速 ${ttsSettings.rate.toStringAsFixed(2)}',
                                  accent: const Color(0xFF6BA8FF),
                                  icon: Icons.graphic_eq_rounded,
                                ),
                                _InfoPill(
                                  label: 'ピッチ ${ttsSettings.pitch.toStringAsFixed(2)}',
                                  accent: const Color(0xFFEF6CFF),
                                  icon: Icons.multitrack_audio_rounded,
                                ),
                                if (ttsSettings.broadcastModeEnabled)
                                  const _InfoPill(
                                    label: '配信向け出力モード',
                                    accent: Color(0xFFFFC64C),
                                    icon: Icons.campaign_rounded,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _PremiumSummaryCard(state: premiumState),
                            if (ttsSettings.broadcastModeEnabled) ...[
                              const SizedBox(height: 12),
                              const _BroadcastOutputHintCard(),
                            ],
                            if (liveState.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              _ErrorActionCard(
                                message: liveState.errorMessage!,
                                onRetry: liveState.isConnecting
                                    ? null
                                    : ref.read(liveProvider.notifier).retryConnection,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Expanded(
                      // [修正済み]
                      child: _CommentSection(),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              // [修正済み]
              child: _GiftOverlaySection(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCurrentScreen() async {
    if (_isSharing) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      final context = _shareBoundaryKey.currentContext;
      if (context == null) {
        return;
      }

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/tikbox_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'このアプリやばい。TikTok LIVEのコメント演出が気持ちよすぎる #TikBox',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Share image generation failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('共有用画像の作成に失敗しました'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
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
                          '読み上げ設定',
                          glowColor: Color(0xFFEF6CFF),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
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
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          value: current.broadcastModeEnabled,
                          onChanged: notifier.setBroadcastModeEnabled,
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: const Color(0xFFFFC64C),
                          activeTrackColor: const Color(0x66FFC64C),
                          title: const Text(
                            '配信向け出力モード',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'TTSと効果音をスピーカーへ強めに出し、配信アプリのマイクに乗りやすくします。TikTokアプリへ直接注入するものではありません。',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (current.broadcastModeEnabled) ...[
                          const SizedBox(height: 8),
                          _BroadcastPresetButtons(
                            onBalanced: notifier.applyBroadcastBalancedPreset,
                            onClarity: notifier.applyBroadcastClarityPreset,
                          ),
                          const SizedBox(height: 10),
                          const _PlatformBroadcastGuideCard(),
                        ],
                        const SizedBox(height: 8),
                        _VoiceDropdown(
                          label: '通常コメントの声',
                          voices: current.availableVoices,
                          selected: current.commentVoice,
                          onChanged: notifier.setCommentVoice,
                        ),
                        const SizedBox(height: 12),
                        _VoiceDropdown(
                          label: 'ギフトの声',
                          voices: current.availableVoices,
                          selected: current.giftVoice,
                          onChanged: notifier.setGiftVoice,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.tonal(
                              onPressed: notifier.testCurrentVoice,
                              child: const Text('通常音声テスト'),
                            ),
                            FilledButton(
                              onPressed: notifier.testGiftVoice,
                              child: const Text('ギフト音声テスト'),
                            ),
                            OutlinedButton(
                              onPressed: notifier.testBroadcastMode,
                              child: const Text('配信向け出力テスト'),
                            ),
                          ],
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

  Future<void> _openPremium(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1020),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final premiumState = ref.watch(premiumProvider);
            final notifier = ref.read(premiumProvider.notifier);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: SingleChildScrollView(
                  child: NeonPanel(
                    glowColor: const Color(0xFFFFC64C),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NeonText(
                          premiumState.isPremium
                              ? 'プレミアム利用中'
                              : 'プレミアムを解放',
                          glowColor: const Color(0xFFFFC64C),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'もっと快適に使うにはプレミアムへ。読み上げ回数の上限解放、高品質ボイス、強化ギフト演出が使えます。',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _BenefitLine('読み上げ回数が無制限'),
                        const _BenefitLine('高品質ボイスが利用可能'),
                        const _BenefitLine('ギフト演出がさらに派手になる'),
                        const _BenefitLine('優先読み上げがさらに強くなる'),
                        const SizedBox(height: 18),
                        if (!premiumState.isPremium)
                          FilledButton(
                            onPressed:
                                premiumState.isLoading ? null : notifier.buyPremium,
                            child: Text(
                              premiumState.products.isEmpty
                                  ? 'プレミアムを解放'
                                  : 'プレミアムを解放 ${premiumState.products.first.price}',
                            ),
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: notifier.restorePurchases,
                          child: const Text('購入を復元'),
                        ),
                        if (premiumState.promptMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              premiumState.promptMessage!,
                              style: const TextStyle(color: Colors.amber),
                            ),
                          ),
                        if (premiumState.purchaseMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              premiumState.purchaseMessage!,
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                              ),
                            ),
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
            child: _GlowOrb(
              size: 220,
              color: Color(0xFF00E5FF),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _GlowOrb(
              size: 240,
              color: Color(0xFFFF3F7A),
            ),
          ),
          Positioned(
            bottom: -60,
            left: 50,
            child: _GlowOrb(
              size: 260,
              color: Color(0xFF8D4CFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

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
  final DateTime? startedAt;

  const _RecordingHud({
    required this.isLive,
    required this.startedAt,
  });

  @override
  State<_RecordingHud> createState() => _RecordingHudState();
}

class _RecordingHudState extends State<_RecordingHud> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(_RecordingHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLive != widget.isLive) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    if (widget.isLive) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
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
    final elapsed = widget.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(widget.startedAt!);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return NeonPanel(
      glowColor: widget.isLive ? const Color(0xFFFF4F7D) : const Color(0xFF6BA8FF),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (widget.isLive) const LiveGlowDot() else const Icon(Icons.videocam),
          const SizedBox(width: 10),
          NeonText(
            widget.isLive ? 'REC  $mm:$ss' : 'STANDBY',
            glowColor:
                widget.isLive ? const Color(0xFFFF4F7D) : const Color(0xFF6BA8FF),
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
  final bool isBusy;
  final Future<void> Function() onPressed;

  const _PrimaryLiveButton({
    required this.isLive,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isLive ? const Color(0xFFFF4F7D) : const Color(0xFF58F5D1);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accent,
            accent.withValues(alpha: 0.72),
          ],
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
        onPressed: isBusy ? null : onPressed,
        child: Text(
          isLive ? '配信を停止' : 'LIVEへ接続',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusChip({
    required this.label,
    required this.accent,
  });

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
        border: Border.all(
          color: accent.withValues(alpha: 0.32),
        ),
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

class _PremiumSummaryCard extends StatelessWidget {
  final PremiumState state;

  const _PremiumSummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isPremium = state.isPremium;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isPremium
              ? const [Color(0x33FFC64C), Color(0x22FF7E5F)]
              : const [Color(0x221DF7FF), Color(0x221A4BFF)],
        ),
        border: Border.all(
          color: isPremium
              ? const Color(0x88FFC64C)
              : const Color(0x663ACFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.auto_awesome : Icons.bolt_rounded,
                color: isPremium
                    ? const Color(0xFFFFD56B)
                    : const Color(0xFF73F6FF),
              ),
              const SizedBox(width: 8),
              Text(
                isPremium ? 'プレミアム' : '無料プラン',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPremium
                ? '無制限読み上げ / 高品質ボイス / 強化ギフト'
                : '無料枠: 残り ${state.freeRemainingReads} 回 / 日',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastOutputHintCard extends StatelessWidget {
  const _BroadcastOutputHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x22FFC64C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66FFD56B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.record_voice_over_rounded, color: Color(0xFFFFD56B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '配信向け出力モードが有効です',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'スマホのスピーカーからTTSと効果音を強めに出力します。最も安定するのは、本アプリ端末とTikTok配信端末を分ける構成です。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastPresetButtons extends StatelessWidget {
  final Future<void> Function() onBalanced;
  final Future<void> Function() onClarity;

  const _BroadcastPresetButtons({
    required this.onBalanced,
    required this.onClarity,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.tonal(
          onPressed: onBalanced,
          child: const Text('バランス重視'),
        ),
        FilledButton(
          onPressed: onClarity,
          child: const Text('声を前に出す'),
        ),
      ],
    );
  }
}

class _PlatformBroadcastGuideCard extends StatelessWidget {
  const _PlatformBroadcastGuideCard();

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isIos = platform == TargetPlatform.iOS;

    final title = isIos ? 'iPhoneで聞こえやすくするコツ' : 'Androidで聞こえやすくするコツ';
    final tips = isIos
        ? const [
            'TikTok配信用端末と本アプリ端末を分けると安定します。',
            '本アプリ端末のスピーカーを配信端末の下側マイク付近へ向けてください。',
            'iPhoneの消音スイッチと音量を確認し、ノイズ抑制が強すぎる場合は距離を少し離します。',
          ]
        : const [
            '配信端末と本アプリ端末を分けると最も聞こえやすくなります。',
            '配信端末側のノイズ抑制が強い場合は、本アプリ端末を10〜20cm程度まで近づけてください。',
            '本アプリ端末のメディア音量を高めにして、通知音はオフにしておくと安定します。',
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xFFFFC64C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
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

  const _ErrorActionCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x22FF5474),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x66FF7E96),
        ),
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

class _BenefitLine extends StatelessWidget {
  final String text;

  const _BenefitLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFFFFC64C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
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

class _VoiceDropdown extends StatelessWidget {
  final String label;
  final List<Map<String, String>> voices;
  final Map<String, String>? selected;
  final ValueChanged<Map<String, String>?> onChanged;

  const _VoiceDropdown({
    required this.label,
    required this.voices,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue = _voiceKey(selected);
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('デフォルト'),
      ),
      ...voices.map((voice) {
        final name = voice['name'] ?? 'unknown';
        final locale = voice['locale'] ?? '';
        final key = _voiceKey(voice);
        return DropdownMenuItem<String?>(
          value: key,
          child: Text('$name ($locale)'),
        );
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: items.any((item) => item.value == selectedValue)
              ? selectedValue
              : null,
          dropdownColor: const Color(0xFF12162A),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          items: items,
          onChanged: (value) {
            if (value == null) {
              onChanged(null);
              return;
            }
            final voice = voices.firstWhere(
              (item) => _voiceKey(item) == value,
            );
            onChanged(voice);
          },
        ),
      ],
    );
  }

  String? _voiceKey(Map<String, String>? voice) {
    if (voice == null) {
      return null;
    }
    return '${voice['name']}_${voice['locale']}_${voice['identifier']}';
  }
}

class _TutorialStep extends StatelessWidget {
  final String index;
  final String title;
  final String body;

  const _TutorialStep({
    required this.index,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF72F6FF),
            ),
            child: Text(
              index,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
