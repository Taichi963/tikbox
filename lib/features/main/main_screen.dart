import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/comment_model.dart';
import '../../models/tts_settings.dart';
import '../../services/app_logger.dart';
import '../../services/tts_service.dart';
import '../../services/ugc_moderation_service.dart';
import '../../widgets/comment_animation.dart';
import '../../widgets/gift_animation.dart';
import '../../widgets/neon_effect.dart';
import '../live/live_provider.dart';
import 'main_provider.dart';
import 'tts_provider.dart';

const String _lastUsernameKey = 'tikbox_last_username_v1';
const String _savedUsernamesKey = 'tikbox_saved_usernames_v1';
const int _maxSavedUsernames = 5;
const String _voicePreviewText = 'こんにちは。LiveVoice Boxの読み上げテストです。';
const String _supportEmail = 'zeb0kui3ackwv4pft1us@gmail.com';

/// MVP: 接続・TTS・最小設定のコメント一覧のみ
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _blockedWordController = TextEditingController();
  List<String> _savedUsernames = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSavedUsernames());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _blockedWordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedUsernames() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsernames = _normalizedUsernameList([
      prefs.getString(_lastUsernameKey),
      ...?prefs.getStringList(_savedUsernamesKey),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedUsernames = savedUsernames;
    });
    if (savedUsernames.isEmpty) {
      return;
    }
    await prefs.setStringList(_savedUsernamesKey, savedUsernames);
    await prefs.setString(_lastUsernameKey, savedUsernames.first);
    if (!mounted) {
      return;
    }
    if (_usernameController.text.trim().isNotEmpty) {
      return;
    }
    _usernameController.text = savedUsernames.first;
  }

  Future<void> _saveUsernameIfNeeded(String rawUsername) async {
    final normalized = _normalizeUsername(rawUsername);
    if (normalized.isEmpty || !_isLikelyTikTokUsername(normalized)) {
      return;
    }

    final updated = _normalizedUsernameList([normalized, ..._savedUsernames]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsernameKey, normalized);
    await prefs.setStringList(_savedUsernamesKey, updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedUsernames = updated;
    });
  }

  Future<void> _confirmRemoveSavedUsername(String username) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ユーザー名を削除しますか？'),
          content: Text('@$username'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
    if (shouldRemove == true) {
      await _removeSavedUsername(username);
    }
  }

  Future<void> _removeSavedUsername(String username) async {
    final normalized = _normalizeUsername(username);
    final updated = _savedUsernames
        .where((saved) => saved.toLowerCase() != normalized.toLowerCase())
        .toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedUsernamesKey, updated);
    if (updated.isEmpty) {
      await prefs.remove(_lastUsernameKey);
    } else {
      await prefs.setString(_lastUsernameKey, updated.first);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _savedUsernames = updated;
    });
  }

  void _selectSavedUsername(String username) {
    _usernameController.text = username;
    _usernameController.selection = TextSelection.collapsed(
      offset: username.length,
    );
  }

  List<String> _normalizedUsernameList(Iterable<String?> rawUsernames) {
    final seen = <String>{};
    final result = <String>[];
    for (final rawUsername in rawUsernames) {
      final normalized = _normalizeUsername(rawUsername ?? '');
      if (normalized.isEmpty || !_isLikelyTikTokUsername(normalized)) {
        continue;
      }
      final key = normalized.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      result.add(normalized);
      if (result.length >= _maxSavedUsernames) {
        break;
      }
    }
    return result;
  }

  String _normalizeUsername(String input) {
    final trimmed = input.replaceAll('\u3000', ' ').replaceAll('＠', '@').trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      if (uri.host.isEmpty) {
        return '';
      }
      final host = uri.host.toLowerCase();
      final isTikTokHost = host == 'tiktok.com' || host.endsWith('.tiktok.com');
      if (!isTikTokHost) {
        return '';
      }
      for (final segment in uri.pathSegments) {
        if (segment.startsWith('@')) {
          return segment.replaceFirst(RegExp(r'^@+'), '').trim();
        }
      }
      return '';
    }

    final withoutQuery = trimmed.split(RegExp(r'[?#]')).first;
    final withoutHost = withoutQuery.replaceFirst(
      RegExp(r'^(https?://)?(www\.)?tiktok\.com/?', caseSensitive: false),
      '',
    );
    final withoutAt = withoutHost.replaceFirst(RegExp(r'^@+'), '');
    return withoutAt.split('/').first.replaceAll('@', '').trim();
  }

  bool _isLikelyTikTokUsername(String username) {
    return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(username);
  }

  String _voiceKey(Map<String, String>? voice) {
    if (voice == null || voice.isEmpty) {
      return '';
    }
    return '${voice['name'] ?? ''}|${voice['locale'] ?? ''}|'
        '${voice['identifier'] ?? ''}';
  }

  String _voiceLabel(Map<String, String> voice, int index) {
    final name = (voice['name'] ?? '').trim();
    final identifier = (voice['identifier'] ?? '').trim();
    final locale = (voice['locale'] ?? '').trim();
    final source = '$name $identifier $locale'.toLowerCase();
    final language = _voiceLanguageLabel(locale, source);
    final gender = _voiceGenderLabel(source);
    final tone = _voiceToneLabel(source);

    if (gender != null) {
      return '$language・$gender（$tone） $index';
    }
    return '$language・$toneボイス $index';
  }

  String _voiceLanguageLabel(String locale, String source) {
    final normalized = locale.toLowerCase();
    if (normalized.startsWith('ja') ||
        normalized.contains('jp') ||
        source.contains('japanese') ||
        source.contains('日本')) {
      return '日本語';
    }
    if (normalized.startsWith('en')) {
      return '英語';
    }
    if (normalized.startsWith('ko')) {
      return '韓国語';
    }
    if (normalized.startsWith('zh')) {
      return '中国語';
    }
    return '端末';
  }

  String? _voiceGenderLabel(String source) {
    if (source.contains('female') ||
        source.contains('woman') ||
        source.contains('kyoko') ||
        source.contains('haruka')) {
      return '女性';
    }
    if (source.contains('male') ||
        source.contains('man') ||
        source.contains('otoya')) {
      return '男性';
    }
    return null;
  }

  String _voiceToneLabel(String source) {
    if (source.contains('premium') ||
        source.contains('enhanced') ||
        source.contains('neural') ||
        source.contains('wavenet')) {
      return '自然';
    }
    if (source.contains('bright') || source.contains('high')) {
      return '明るめ';
    }
    if (source.contains('deep') || source.contains('low')) {
      return '落ち着き';
    }
    return '標準';
  }

  @override
  Widget build(BuildContext context) {
    final isLive = ref.watch(mainProvider.select((s) => s.isLive));
    final connectedUsername =
        ref.watch(mainProvider.select((s) => s.connectedUsername));
    final liveState = ref.watch(liveProvider);
    final ttsSettings = ref.watch(ttsSettingsProvider);

    ref.listen<LiveState>(liveProvider, (previous, next) {
      final becameConnected = previous?.wsStatus != WsStatus.connected &&
          next.wsStatus == WsStatus.connected;
      if (!becameConnected) {
        return;
      }
      final connectedUsername = ref.read(mainProvider).connectedUsername;
      unawaited(_saveUsernameIfNeeded(
        connectedUsername ?? _usernameController.text,
      ));
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050815),
      body: Stack(
        children: [
          const Positioned.fill(child: _BuzzBackground()),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => ref.read(liveProvider.notifier).skipCurrentTts(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isKeyboardVisible =
                      MediaQuery.viewInsetsOf(context).bottom > 0;
                  final controlPanelUpperBound = (constraints.maxHeight -
                          (isKeyboardVisible ? 150.0 : 240.0))
                      .clamp(140.0, isKeyboardVisible ? 340.0 : 520.0)
                      .toDouble();
                  final controlPanelMaxHeight = (constraints.maxHeight *
                          (isKeyboardVisible ? 0.58 : 0.62))
                      .clamp(140.0, controlPanelUpperBound)
                      .toDouble();
                  final sectionGap = isKeyboardVisible ? 8.0 : 16.0;
                  final connectingNotice =
                      liveState.isConnecting ? liveState.errorMessage : null;
                  final content = Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: controlPanelMaxHeight,
                          ),
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: NeonPanel(
                              glowColor: isLive
                                  ? const Color(0xFFFF4F7D)
                                  : const Color(0xFF00E5FF),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _usernameController,
                                    enabled: !liveState.isConnecting && !isLive,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: '配信者の@ID / URL',
                                      hintText: '@jppachi',
                                      helperText:
                                          '表示名では接続できません。@IDまたはTikTok URLを入力してください',
                                      helperMaxLines: 2,
                                      labelStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                      ),
                                      hintStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.34),
                                      ),
                                      helperStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.58),
                                      ),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withValues(alpha: 0.05),
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
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _PrimaryLiveButton(
                                          isLive: isLive,
                                          isConnecting: liveState.isConnecting,
                                          onPressed: () async {
                                            if (liveState.isConnecting ||
                                                isLive) {
                                              await ref
                                                  .read(liveProvider.notifier)
                                                  .stopLive();
                                              return;
                                            }
                                            final username =
                                                _usernameController.text;
                                            AppLogger.info(
                                                'Connect button pressed');
                                            await ref
                                                .read(liveProvider.notifier)
                                                .startLive(username);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StatusChip(
                                          label:
                                              _statusLabel(liveState.wsStatus),
                                          accent:
                                              _statusColor(liveState.wsStatus),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (liveState.isConnecting) ...[
                                    const SizedBox(height: 16),
                                    _ConnectingHintCard(
                                      message: connectingNotice,
                                    ),
                                  ],
                                  if (!liveState.isConnecting &&
                                      liveState.errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    _ErrorActionCard(
                                      message: liveState.errorMessage!,
                                      onRetry: liveState.isConnecting
                                          ? null
                                          : ref
                                              .read(liveProvider.notifier)
                                              .retryConnection,
                                    ),
                                  ],
                                  if (_savedUsernames.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _savedUsernames.map((username) {
                                        return GestureDetector(
                                          onLongPress: () =>
                                              _confirmRemoveSavedUsername(
                                                  username),
                                          child: ActionChip(
                                            label: Text('@$username'),
                                            labelStyle: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.86),
                                              fontWeight: FontWeight.w700,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.05),
                                            side: BorderSide(
                                              color: const Color(0xFF72F6FF)
                                                  .withValues(alpha: 0.22),
                                            ),
                                            onPressed: liveState.isConnecting ||
                                                    isLive
                                                ? null
                                                : () => _selectSavedUsername(
                                                      username,
                                                    ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  if (isLive || connectedUsername != null) ...[
                                    const SizedBox(height: 10),
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
                                              '速度: ${ttsSettings.rate.toStringAsFixed(2)}',
                                          accent: const Color(0xFF6BA8FF),
                                          icon: Icons.graphic_eq_rounded,
                                        ),
                                        _InfoPill(
                                          label:
                                              '声の高さ: ${ttsSettings.pitch.toStringAsFixed(2)}',
                                          accent: const Color(0xFFEF6CFF),
                                          icon: Icons.multitrack_audio_rounded,
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    '非公式ツールです。ログイン情報・Cookieは取得しません。',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.58),
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      const Expanded(child: _CommentSection()),
                    ],
                  );

                  return content;
                },
              ),
            ),
          ),
          const Positioned.fill(child: _GiftOverlaySection()),
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    Map<String, String>? pendingCommentVoice =
        ref.read(ttsSettingsProvider).commentVoice;
    var pendingCommentVoiceKey = _voiceKey(pendingCommentVoice);

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
            final moderationReady = ref.watch(
              mainProvider.select((state) => state.moderationReady),
            );
            final blockedUsers = ref.watch(
              mainProvider.select((state) => state.blockedUsers),
            );
            final customBlockedTerms = ref.watch(
              mainProvider.select((state) => state.customBlockedTerms),
            );
            final moderationNotifier = ref.read(mainProvider.notifier);
            final availableVoices = current.availableVoices;
            final availableVoiceKeys = availableVoices.map(_voiceKey).toSet();
            final pendingVoiceValue = pendingCommentVoiceKey.isNotEmpty &&
                    availableVoiceKeys.contains(pendingCommentVoiceKey)
                ? pendingCommentVoiceKey
                : '';

            return StatefulBuilder(
              builder: (context, setModalState) {
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('← 戻る'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const NeonText(
                              '読み上げ設定',
                              glowColor: Color(0xFFEF6CFF),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '声・音プリセット',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 18),
                            Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                initiallyExpanded: false,
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                iconColor: const Color(0xFF72F6FF),
                                collapsedIconColor: Colors.white.withValues(
                                  alpha: 0.72,
                                ),
                                title: const Text(
                                  '詳細設定',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '声・音量・ギフト通知を調整できます',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    height: 1.3,
                                  ),
                                ),
                                children: [
                                  const SizedBox(height: 10),
                                  if (availableVoices.isNotEmpty) ...[
                                    DropdownButtonFormField<String>(
                                      initialValue: pendingVoiceValue,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF151A2D),
                                      iconEnabledColor: const Color(0xFF72F6FF),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: '読み上げボイス',
                                        helperText: '選ぶと試聴します。「この声にする」で保存します',
                                        helperMaxLines: 2,
                                        labelStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                        ),
                                        helperStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.58),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white
                                            .withValues(alpha: 0.05),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: const Color(
                                              0xFF72F6FF,
                                            ).withValues(alpha: 0.22),
                                          ),
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: '',
                                          child: Text('端末の標準ボイス'),
                                        ),
                                        ...availableVoices
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final voice = entry.value;
                                          return DropdownMenuItem<String>(
                                            value: _voiceKey(voice),
                                            child: Text(
                                              _voiceLabel(voice, entry.key + 1),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }),
                                      ],
                                      onChanged: (value) async {
                                        if (value == null) {
                                          return;
                                        }
                                        if (value.isEmpty) {
                                          setModalState(() {
                                            pendingCommentVoice = null;
                                            pendingCommentVoiceKey = '';
                                          });
                                          await ttsService.previewVoice(
                                            _voicePreviewText,
                                          );
                                          return;
                                        }
                                        final selectedVoice =
                                            availableVoices.firstWhere(
                                          (voice) => _voiceKey(voice) == value,
                                          orElse: () =>
                                              const <String, String>{},
                                        );
                                        if (selectedVoice.isEmpty) {
                                          return;
                                        }
                                        setModalState(() {
                                          pendingCommentVoice = selectedVoice;
                                          pendingCommentVoiceKey = value;
                                        });
                                        await ttsService.previewVoice(
                                          _voicePreviewText,
                                          voice: selectedVoice,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    FilledButton.icon(
                                      onPressed: () async {
                                        await notifier.setCommentVoice(
                                          pendingCommentVoice,
                                        );
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      icon: const Icon(Icons.check_rounded),
                                      label: const Text('この声にする'),
                                    ),
                                  ] else
                                    Text(
                                      '端末の音声一覧を取得できないため、標準の声を使用します',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.62),
                                        height: 1.35,
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
                                    label: '読み上げ音量',
                                    valueText:
                                        current.ttsVolume.toStringAsFixed(2),
                                    value: current.ttsVolume,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 10,
                                    onChanged: notifier.setTtsVolume,
                                  ),
                                  SwitchListTile.adaptive(
                                    value: current.readUsernameEnabled,
                                    onChanged: notifier.setReadUsernameEnabled,
                                    contentPadding: EdgeInsets.zero,
                                    activeThumbColor: const Color(0xFF72F6FF),
                                    title: const Text(
                                      'ユーザー名を読み上げる',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _LabeledSlider(
                                    label: '効果音音量',
                                    valueText:
                                        current.effectVolume.toStringAsFixed(2),
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
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  SwitchListTile.adaptive(
                                    value: current.giftVibrationEnabled,
                                    onChanged: notifier.setGiftVibrationEnabled,
                                    contentPadding: EdgeInsets.zero,
                                    activeThumbColor: const Color(0xFF72F6FF),
                                    title: const Text(
                                      'ギフト時にバイブレーション',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ギフト受信時だけ端末を短く振動させます',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
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
                                      'ライブ接続中のみ画面を起こしたままにします',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _ModerationSettingsSection(
                                    ready: moderationReady,
                                    blockedUsers: blockedUsers,
                                    customBlockedTerms: customBlockedTerms,
                                    blockedWordController:
                                        _blockedWordController,
                                    notifier: moderationNotifier,
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showPrivacyPolicy(context),
                              icon: const Icon(Icons.privacy_tip_outlined),
                              label: const Text('プライバシーと非公式について'),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                await ttsService.speak(
                                  'LiveVoice Box の読み上げテストです',
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
      },
    );
  }

  Future<void> _showPrivacyPolicy(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プライバシーと非公式について'),
          content: const SingleChildScrollView(
            child: Text(
              'LiveVoice BoxはTikTok/ByteDanceの公式アプリではありません。\n\n'
              'TikTokのログイン情報、パスワード、Cookie、ブラウザCookieは取得しません。\n\n'
              '入力された配信IDは、公開LIVEへの接続にのみ使います。コメントとギフト情報は、読み上げ、効果音、バイブレーションのためにアプリ内で処理します。\n\n'
              '設定とID履歴は端末内に保存されます。配信サービス側の仕様変更、通信状態、OSのバックグラウンド制限により接続できない場合があります。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
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
        return '接続失敗';
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
          if (widget.isLive)
            const LiveGlowDot()
          else
            const Icon(Icons.videocam),
          const SizedBox(width: 10),
          NeonText(
            widget.isLive ? '配信中  $mm:$ss' : '待機中',
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
        ? '接続を中止'
        : isLive
            ? '接続を停止'
            : '接続開始';
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

class _ConnectingHintCard extends StatelessWidget {
  final String? message;

  const _ConnectingHintCard({this.message});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFC64C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.14),
                    border: Border.all(color: accent.withValues(alpha: 0.34)),
                  ),
                ),
                const Icon(
                  Icons.sensors_rounded,
                  color: accent,
                  size: 18,
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFE0A3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '接続中',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message ?? '配信ルームを探しています。時間がかかる場合はID・配信中か・通信環境を確認してください。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
                  '接続できませんでした',
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
            child: const Text('もう一度試す'),
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

class _ModerationSettingsSection extends StatelessWidget {
  final bool ready;
  final List<BlockedUserEntry> blockedUsers;
  final List<String> customBlockedTerms;
  final TextEditingController blockedWordController;
  final MainNotifier notifier;

  const _ModerationSettingsSection({
    required this.ready,
    required this.blockedUsers,
    required this.customBlockedTerms,
    required this.blockedWordController,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.14)),
        const SizedBox(height: 8),
        const Text(
          'コメント保護',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '固定NGワードに加えて、自分用のNGワードを追加できます。',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.66),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: blockedWordController,
                enabled: ready,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '追加するNGワード',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: ready
                  ? () async {
                      final error = await notifier.addCustomBlockedTerm(
                        blockedWordController.text,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        return;
                      }
                      blockedWordController.clear();
                    }
                  : null,
              child: const Text('追加'),
            ),
          ],
        ),
        if (!ready) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (customBlockedTerms.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: customBlockedTerms.map((term) {
              return InputChip(
                label: Text(term),
                onDeleted: () {
                  unawaited(notifier.removeCustomBlockedTerm(term));
                },
              );
            }).toList(growable: false),
          ),
        ],
        const SizedBox(height: 14),
        const Text(
          'ブロック中のユーザー',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (blockedUsers.isEmpty)
          Text(
            'ブロック中のユーザーはいません。',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.58)),
          )
        else
          ...blockedUsers.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                entry.persistent ? 'IDでブロック（再起動後も有効）' : '表示名でブロック（この接続中のみ）',
              ),
              trailing: TextButton(
                onPressed: () => notifier.unblockUser(entry.key),
                child: const Text('解除'),
              ),
            ),
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
    return AnimatedCommentList(
      comments: comments,
      onBlockUser: (comment) {
        unawaited(_confirmBlock(context, ref, comment));
      },
      onReportComment: (comment) {
        unawaited(_showReportFlow(context, ref, comment));
      },
    );
  }

  Future<void> _confirmBlock(
    BuildContext context,
    WidgetRef ref,
    CommentModel comment,
  ) async {
    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('このユーザーをブロックしますか？'),
          content: Text(
            '${comment.userName}さんの今後のコメントを表示・読み上げしません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ブロック'),
            ),
          ],
        );
      },
    );
    if (shouldBlock != true) {
      return;
    }
    await ref.read(mainProvider.notifier).blockUser(comment);
  }

  Future<void> _showReportFlow(
    BuildContext context,
    WidgetRef ref,
    CommentModel comment,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('通報理由を選択'),
          children: [
            for (final reason in const [
              '嫌がらせ・誹謗中傷',
              '差別的または暴力的な内容',
              '性的または不適切な内容',
              'その他',
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(reason),
                child: Text(reason),
              ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) {
      return;
    }

    final reference = comment.userReference ?? comment.userName;
    final reportText = UgcModerationService.buildReportText(
      supportEmail: _supportEmail,
      reason: reason,
      displayName: comment.userName,
      userKeySource: comment.userKeySource ?? 'nickname',
      userReference: reference,
      commentText: comment.text,
      receivedAt: comment.createdAt,
    );
    final supportEmailConfigured =
        !_supportEmail.startsWith('[') && _supportEmail.contains('@');

    final copied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('通報内容を確認'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    supportEmailConfigured
                        ? '宛先・件名・本文をコピーし、メールアプリへ貼り付けて送信してください。'
                        : '宛先はプレースホルダーです。実在するサポートメールを公開前に設定してください。',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(reportText),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reportText));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('内容をコピー'),
            ),
          ],
        );
      },
    );
    if (copied != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          supportEmailConfigured
              ? '宛先・件名・本文をコピーしました。メールアプリから送信してください。'
              : '通報内容をコピーしました。サポートメールは未設定です。',
        ),
      ),
    );

    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('このユーザーもブロックしますか？'),
          content: const Text('ブロックすると、今後のコメントを表示・読み上げしません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('しない'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ブロック'),
            ),
          ],
        );
      },
    );
    if (shouldBlock == true) {
      await ref.read(mainProvider.notifier).blockUser(comment);
    }
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
