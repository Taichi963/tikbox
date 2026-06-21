import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/comment_model.dart';
import '../../services/app_logger.dart';
import '../../services/ugc_moderation_service.dart';

const String _blockedUsersPreferenceKey = 'tikbox_blocked_users_v1';
const String _customBlockedTermsPreferenceKey = 'tikbox_custom_ng_words_v1';

enum HighlightType {
  commentRush,
  gift,
  bigGift,
  premiumGift,
}

class HighlightEvent {
  final DateTime timestamp;
  final HighlightType type;
  final String title;

  const HighlightEvent({
    required this.timestamp,
    required this.type,
    required this.title,
  });

  int get priority => switch (type) {
        HighlightType.premiumGift => 4,
        HighlightType.bigGift => 3,
        HighlightType.gift => 2,
        HighlightType.commentRush => 1,
      };
}

class SessionStats {
  final DateTime? startedAt;
  final Duration lastDuration;
  final int commentCount;
  final int giftCount;
  final int bigGiftCount;
  final int premiumGiftCount;
  final List<HighlightEvent> highlights;

  const SessionStats({
    this.startedAt,
    this.lastDuration = Duration.zero,
    this.commentCount = 0,
    this.giftCount = 0,
    this.bigGiftCount = 0,
    this.premiumGiftCount = 0,
    this.highlights = const [],
  });

  bool get hasCompletedSession =>
      startedAt == null &&
      (lastDuration > Duration.zero || commentCount > 0 || giftCount > 0);

  int get score {
    final liveMinutes = lastDuration.inMinutes;
    return (commentCount +
            giftCount * 5 +
            bigGiftCount * 15 +
            premiumGiftCount * 30 +
            liveMinutes * 2)
        .clamp(0, 100)
        .toInt();
  }

  List<HighlightEvent> get topHighlights {
    final selected = [...highlights]..sort((a, b) {
        final priorityOrder = b.priority.compareTo(a.priority);
        return priorityOrder != 0
            ? priorityOrder
            : b.timestamp.compareTo(a.timestamp);
      });
    final topFive = selected.take(5).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List.unmodifiable(topFive);
  }

  SessionStats record(CommentModel comment) {
    if (startedAt == null) {
      return this;
    }
    if (!comment.isGift) {
      return SessionStats(
        startedAt: startedAt,
        lastDuration: lastDuration,
        commentCount: commentCount + 1,
        giftCount: giftCount,
        bigGiftCount: bigGiftCount,
        premiumGiftCount: premiumGiftCount,
        highlights: highlights,
      );
    }
    return SessionStats(
      startedAt: startedAt,
      lastDuration: lastDuration,
      commentCount: commentCount,
      giftCount: giftCount + 1,
      bigGiftCount: bigGiftCount + (comment.giftRank == GiftRank.big ? 1 : 0),
      premiumGiftCount:
          premiumGiftCount + (comment.giftRank == GiftRank.premium ? 1 : 0),
      highlights: highlights,
    );
  }

  SessionStats addHighlight(HighlightEvent event) {
    final bounded = [...highlights, event]..sort((a, b) {
        final priorityOrder = b.priority.compareTo(a.priority);
        return priorityOrder != 0
            ? priorityOrder
            : b.timestamp.compareTo(a.timestamp);
      });
    return SessionStats(
      startedAt: startedAt,
      lastDuration: lastDuration,
      commentCount: commentCount,
      giftCount: giftCount,
      bigGiftCount: bigGiftCount,
      premiumGiftCount: premiumGiftCount,
      highlights: List.unmodifiable(bounded.take(20)),
    );
  }

  SessionStats finish(DateTime endedAt) {
    final started = startedAt;
    if (started == null) {
      return this;
    }
    final elapsed = endedAt.difference(started);
    return SessionStats(
      lastDuration: elapsed.isNegative ? Duration.zero : elapsed,
      commentCount: commentCount,
      giftCount: giftCount,
      bigGiftCount: bigGiftCount,
      premiumGiftCount: premiumGiftCount,
      highlights: highlights,
    );
  }
}

class BlockedUserEntry {
  final String key;
  final String label;
  final String source;
  final bool persistent;

  const BlockedUserEntry({
    required this.key,
    required this.label,
    required this.source,
    required this.persistent,
  });

  String toStorageValue() {
    return jsonEncode({
      'key': key,
      'label': label,
      'source': source,
    });
  }

  static BlockedUserEntry? fromStorageValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final key = decoded['key']?.toString() ?? '';
      final label = decoded['label']?.toString() ?? '';
      final source = decoded['source']?.toString() ?? '';
      if (!key.startsWith('uniqueId:') ||
          label.isEmpty ||
          source != 'uniqueId') {
        return null;
      }
      return BlockedUserEntry(
        key: key,
        label: label,
        source: source,
        persistent: true,
      );
    } catch (_) {
      return null;
    }
  }
}

class MainState {
  final bool isLive;
  final String? connectedUsername;
  final List<CommentModel> comments;
  final List<BlockedUserEntry> blockedUsers;
  final List<String> customBlockedTerms;
  final bool moderationReady;
  final SessionStats sessionStats;

  const MainState({
    this.isLive = false,
    this.connectedUsername,
    this.comments = const [],
    this.blockedUsers = const [],
    this.customBlockedTerms = const [],
    this.moderationReady = false,
    this.sessionStats = const SessionStats(),
  });

  MainState copyWith({
    bool? isLive,
    String? connectedUsername,
    List<CommentModel>? comments,
    List<BlockedUserEntry>? blockedUsers,
    List<String>? customBlockedTerms,
    bool? moderationReady,
    SessionStats? sessionStats,
    bool clearConnectedUsername = false,
  }) {
    return MainState(
      isLive: isLive ?? this.isLive,
      connectedUsername: clearConnectedUsername
          ? null
          : (connectedUsername ?? this.connectedUsername),
      comments: comments ?? this.comments,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      customBlockedTerms: customBlockedTerms ?? this.customBlockedTerms,
      moderationReady: moderationReady ?? this.moderationReady,
      sessionStats: sessionStats ?? this.sessionStats,
    );
  }
}

class MainNotifier extends Notifier<MainState> {
  static const int _commentRushThreshold = 20;
  static const Duration _commentRushWindow = Duration(seconds: 30);
  static const Duration _commentRushCooldown = Duration(seconds: 30);

  Future<void>? _moderationRestoreFuture;
  final List<DateTime> _recentCommentTimestamps = [];
  DateTime? _lastCommentRushAt;

  @override
  MainState build() {
    _moderationRestoreFuture = _restoreModerationSettings();
    unawaited(_moderationRestoreFuture);
    return const MainState();
  }

  Future<void> ensureModerationReady() async {
    await _moderationRestoreFuture;
  }

  void startLive(String username) {
    _resetHighlightTracking();
    state = state.copyWith(
      isLive: true,
      connectedUsername: username,
      sessionStats: SessionStats(startedAt: DateTime.now()),
    );
  }

  void stopLive() {
    _resetHighlightTracking();
    state = state.copyWith(
      isLive: false,
      clearConnectedUsername: true,
      sessionStats: state.sessionStats.finish(DateTime.now()),
      blockedUsers:
          state.blockedUsers.where((entry) => entry.persistent).toList(),
    );
  }

  void addComment(CommentModel comment) {
    final updated = <CommentModel>[comment, ...state.comments];
    var sessionStats = state.sessionStats.record(comment);
    if (sessionStats.startedAt != null) {
      final highlight = _highlightFor(comment);
      if (highlight != null) {
        sessionStats = sessionStats.addHighlight(highlight);
      }
    }
    state = state.copyWith(
      comments: updated.length > 200 ? updated.take(200).toList() : updated,
      sessionStats: sessionStats,
    );
  }

  HighlightEvent? _highlightFor(CommentModel comment) {
    if (comment.isGift) {
      return switch (comment.giftRank) {
        GiftRank.premium => HighlightEvent(
            timestamp: comment.createdAt,
            type: HighlightType.premiumGift,
            title: 'PREMIUM GIFT',
          ),
        GiftRank.big => HighlightEvent(
            timestamp: comment.createdAt,
            type: HighlightType.bigGift,
            title: 'BIG GIFT',
          ),
        GiftRank.normal => HighlightEvent(
            timestamp: comment.createdAt,
            type: HighlightType.gift,
            title: 'ギフト',
          ),
      };
    }

    final timestamp = comment.createdAt;
    _recentCommentTimestamps.add(timestamp);
    _recentCommentTimestamps.removeWhere(
      (item) => timestamp.difference(item) > _commentRushWindow,
    );
    if (_recentCommentTimestamps.length > _commentRushThreshold) {
      _recentCommentTimestamps.removeRange(
        0,
        _recentCommentTimestamps.length - _commentRushThreshold,
      );
    }
    if (_recentCommentTimestamps.length < _commentRushThreshold) {
      return null;
    }

    final previousRush = _lastCommentRushAt;
    if (previousRush != null &&
        timestamp.difference(previousRush) < _commentRushCooldown) {
      return null;
    }
    _lastCommentRushAt = timestamp;
    return HighlightEvent(
      timestamp: timestamp,
      type: HighlightType.commentRush,
      title: 'コメント急増',
    );
  }

  void _resetHighlightTracking() {
    _recentCommentTimestamps.clear();
    _lastCommentRushAt = null;
  }

  void clearComments() {
    state = state.copyWith(comments: const []);
  }

  UgcModerationDecision moderationDecision({
    required String userKey,
    required String userName,
    required String text,
  }) {
    if (!state.moderationReady) {
      return UgcModerationDecision.settingsLoading;
    }
    if (state.blockedUsers.any((entry) => entry.key == userKey)) {
      return UgcModerationDecision.blockedUser;
    }
    if (UgcModerationService.containsBlockedTerm(
      userName: userName,
      text: text,
      customTerms: state.customBlockedTerms,
    )) {
      return UgcModerationDecision.blockedTerm;
    }
    return UgcModerationDecision.allow;
  }

  Future<void> blockUser(CommentModel comment) async {
    final key = comment.userKey;
    final source = comment.userKeySource;
    if (key == null || source == null || key.isEmpty) {
      return;
    }

    await ensureModerationReady();
    final persistent = source == 'uniqueId';
    final updated = [
      ...state.blockedUsers.where((entry) => entry.key != key),
      BlockedUserEntry(
        key: key,
        label: comment.userName,
        source: source,
        persistent: persistent,
      ),
    ];
    state = state.copyWith(
      blockedUsers: updated,
      comments: state.comments
          .where((existing) => existing.userKey != key)
          .toList(growable: false),
    );
    await _savePersistentBlockedUsers();
  }

  Future<void> unblockUser(String key) async {
    await ensureModerationReady();
    state = state.copyWith(
      blockedUsers:
          state.blockedUsers.where((entry) => entry.key != key).toList(),
    );
    await _savePersistentBlockedUsers();
  }

  Future<String?> addCustomBlockedTerm(String rawTerm) async {
    await ensureModerationReady();
    final term = rawTerm.trim();
    final normalized = UgcModerationService.normalizeText(term);
    if (normalized.length < 2) {
      return '2文字以上で入力してください。';
    }
    final alreadyExists = state.customBlockedTerms.any(
      (existing) => UgcModerationService.normalizeText(existing) == normalized,
    );
    if (alreadyExists) {
      return '同じNGワードが登録されています。';
    }

    final updated = [...state.customBlockedTerms, term];
    state = state.copyWith(
      customBlockedTerms: updated,
      comments: state.comments
          .where(
            (comment) =>
                comment.isGift ||
                !UgcModerationService.containsBlockedTerm(
                  userName: comment.userName,
                  text: comment.text,
                  customTerms: updated,
                ),
          )
          .toList(growable: false),
    );
    await _saveCustomBlockedTerms();
    return null;
  }

  Future<void> removeCustomBlockedTerm(String term) async {
    await ensureModerationReady();
    final normalized = UgcModerationService.normalizeText(term);
    state = state.copyWith(
      customBlockedTerms: state.customBlockedTerms
          .where(
            (existing) =>
                UgcModerationService.normalizeText(existing) != normalized,
          )
          .toList(),
    );
    await _saveCustomBlockedTerms();
  }

  Future<void> _restoreModerationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restoredUsers =
          (prefs.getStringList(_blockedUsersPreferenceKey) ?? const <String>[])
              .map(BlockedUserEntry.fromStorageValue)
              .whereType<BlockedUserEntry>()
              .toList(growable: false);
      final restoredTerms =
          prefs.getStringList(_customBlockedTermsPreferenceKey) ??
              const <String>[];

      final mergedUsers = <String, BlockedUserEntry>{
        for (final entry in restoredUsers) entry.key: entry,
        for (final entry in state.blockedUsers) entry.key: entry,
      }.values.toList(growable: false);
      final mergedTerms = <String, String>{
        for (final term in restoredTerms)
          UgcModerationService.normalizeText(term): term,
        for (final term in state.customBlockedTerms)
          UgcModerationService.normalizeText(term): term,
      }.values.where((term) => term.trim().isNotEmpty).toList(growable: false);

      state = state.copyWith(
        blockedUsers: mergedUsers,
        customBlockedTerms: mergedTerms,
        moderationReady: true,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UGC moderation settings restore failed; comments remain blocked',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _savePersistentBlockedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = state.blockedUsers
          .where((entry) => entry.persistent)
          .map((entry) => entry.toStorageValue())
          .toList(growable: false);
      await prefs.setStringList(_blockedUsersPreferenceKey, values);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UGC blocked users save failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveCustomBlockedTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _customBlockedTermsPreferenceKey,
        state.customBlockedTerms,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UGC custom words save failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final mainProvider =
    NotifierProvider<MainNotifier, MainState>(MainNotifier.new);
