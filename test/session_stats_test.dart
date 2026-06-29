import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikbox/features/main/main_provider.dart';
import 'package:tikbox/models/comment_model.dart';

void main() {
  group('GiftRank', () {
    test('classifies gift value boundaries', () {
      expect(_giftWithoutValue().giftRank, GiftRank.normal);
      expect(_gift(value: 99).giftRank, GiftRank.normal);
      expect(_gift(value: 100).giftRank, GiftRank.big);
      expect(_gift(value: 999).giftRank, GiftRank.big);
      expect(_gift(value: 1000).giftRank, GiftRank.premium);
    });
  });

  group('SessionStats', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('collects comments and gift ranks for one live session', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.addComment(_comment());
      notifier.addComment(_gift(value: 50));
      notifier.addComment(_gift(value: 100));
      notifier.addComment(_gift(value: 1000));
      notifier.stopLive();

      final stats = container.read(mainProvider).sessionStats;
      expect(stats.startedAt, isNull);
      expect(stats.hasCompletedSession, isTrue);
      expect(stats.commentCount, 1);
      expect(stats.giftCount, 3);
      expect(stats.bigGiftCount, 1);
      expect(stats.premiumGiftCount, 1);
      expect(stats.followCount, 0);
      expect(stats.likeCount, 0);
      expect(stats.likeRushCount, 0);
      expect(stats.topGiftRanking.single.points, 1150);
      expect(stats.score, 61);
    });

    test('stop is idempotent and the next connection resets totals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.addComment(_comment());
      notifier.stopLive();
      final firstResult = container.read(mainProvider).sessionStats;

      notifier.stopLive();
      expect(container.read(mainProvider).sessionStats.commentCount, 1);
      expect(
        container.read(mainProvider).sessionStats.lastDuration,
        firstResult.lastDuration,
      );

      notifier.startLive('streamer');
      final nextSession = container.read(mainProvider).sessionStats;
      expect(nextSession.startedAt, isNotNull);
      expect(nextSession.commentCount, 0);
      expect(nextSession.giftCount, 0);
      expect(nextSession.followCount, 0);
      expect(nextSession.likeCount, 0);
      expect(nextSession.likeRushCount, 0);
      expect(nextSession.giftRanking, isEmpty);
    });

    test('ignores comments and social events after stop', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();
      final timestamp = DateTime(2026, 1, 1, 12);

      notifier.startLive('streamer');
      notifier.addComment(_comment(createdAt: timestamp));
      notifier.recordFollow(timestamp);
      notifier.recordLikes(20);
      notifier.recordLikeRush(timestamp);
      notifier.addComment(_gift(value: 100, createdAt: timestamp));
      notifier.stopLive();
      final stoppedStats = container.read(mainProvider).sessionStats;

      notifier.addComment(_comment(id: 'after-stop', createdAt: timestamp));
      notifier.recordFollow(timestamp.add(const Duration(minutes: 1)));
      notifier.recordLikes(30);
      notifier.recordLikeRush(timestamp.add(const Duration(minutes: 1)));
      notifier.addComment(
        _gift(value: 1000, userName: 'after-stop', createdAt: timestamp),
      );

      final afterStopStats = container.read(mainProvider).sessionStats;
      expect(afterStopStats.commentCount, stoppedStats.commentCount);
      expect(afterStopStats.giftCount, stoppedStats.giftCount);
      expect(afterStopStats.bigGiftCount, stoppedStats.bigGiftCount);
      expect(afterStopStats.premiumGiftCount, stoppedStats.premiumGiftCount);
      expect(afterStopStats.followCount, stoppedStats.followCount);
      expect(afterStopStats.likeCount, stoppedStats.likeCount);
      expect(afterStopStats.likeRushCount, stoppedStats.likeRushCount);
      expect(afterStopStats.topGiftRanking, stoppedStats.topGiftRanking);
      expect(afterStopStats.highlights, stoppedStats.highlights);
    });

    test('calculates and clamps the score', () {
      const stats = SessionStats(
        lastDuration: Duration(minutes: 2),
        commentCount: 10,
        giftCount: 2,
        bigGiftCount: 1,
        followCount: 2,
        likeRushCount: 1,
      );
      expect(stats.score, 65);

      const largeStats = SessionStats(
        commentCount: 100,
        premiumGiftCount: 10,
      );
      expect(largeStats.score, 100);
    });

    test('calculates duration and supports an empty completed session', () {
      final startedAt = DateTime(2026, 1, 1, 12);
      final completed = SessionStats(startedAt: startedAt).finish(
        startedAt.add(const Duration(minutes: 1, seconds: 30)),
      );

      expect(completed.lastDuration, const Duration(minutes: 1, seconds: 30));
      expect(completed.commentCount, 0);
      expect(completed.giftCount, 0);
      expect(completed.followCount, 0);
      expect(completed.likeCount, 0);
      expect(completed.likeRushCount, 0);
      expect(completed.hasCompletedSession, isTrue);
      expect(completed.score, 2);
    });

    test('finish clamps a negative elapsed duration to zero', () {
      final startedAt = DateTime(2026, 1, 1, 12);
      final completed = SessionStats(startedAt: startedAt).finish(
        startedAt.subtract(const Duration(seconds: 30)),
      );
      expect(completed.lastDuration, Duration.zero);
      expect(completed.hasCompletedSession, isFalse);
    });

    test('records one comment rush and all gift highlight types', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();
      final startedAt = DateTime(2026, 1, 1, 12);

      notifier.startLive('streamer');
      for (var index = 0; index < 21; index++) {
        notifier.addComment(
          _comment(
            id: 'comment-$index',
            createdAt: startedAt.add(Duration(seconds: index)),
          ),
        );
      }
      notifier.addComment(
        _gift(value: 50, createdAt: startedAt.add(const Duration(seconds: 21))),
      );
      notifier.addComment(
        _gift(
          value: 100,
          createdAt: startedAt.add(const Duration(seconds: 22)),
        ),
      );
      notifier.addComment(
        _gift(
          value: 1000,
          createdAt: startedAt.add(const Duration(seconds: 23)),
        ),
      );
      notifier.stopLive();

      final highlights = container.read(mainProvider).sessionStats.highlights;
      expect(
        highlights.where((event) => event.type == HighlightType.commentRush),
        hasLength(1),
      );
      expect(
        highlights.map((event) => event.type),
        containsAll([
          HighlightType.gift,
          HighlightType.bigGift,
          HighlightType.premiumGift,
        ]),
      );
    });

    test('caps highlights and keeps premium events in the top five', () {
      final startedAt = DateTime(2026, 1, 1, 12);
      var stats = SessionStats(startedAt: startedAt);
      for (var index = 0; index < 25; index++) {
        stats = stats.addHighlight(
          HighlightEvent(
            timestamp: startedAt.add(Duration(seconds: index)),
            type: HighlightType.commentRush,
            title: 'コメント急増',
          ),
        );
      }
      stats = stats.addHighlight(
        HighlightEvent(
          timestamp: startedAt,
          type: HighlightType.premiumGift,
          title: 'PREMIUM GIFT',
        ),
      );

      expect(stats.highlights, hasLength(20));
      expect(stats.topHighlights, hasLength(5));
      expect(
        stats.topHighlights.map((event) => event.type),
        contains(HighlightType.premiumGift),
      );
    });

    test('prefers newer events within the same highlight rank', () {
      final startedAt = DateTime(2026, 1, 1, 12);
      var stats = SessionStats(startedAt: startedAt);
      for (var index = 0; index < 6; index++) {
        stats = stats.addHighlight(
          HighlightEvent(
            timestamp: startedAt.add(Duration(minutes: index)),
            type: HighlightType.gift,
            title: 'gift-$index',
          ),
        );
      }

      expect(stats.topHighlights.map((event) => event.title), [
        'gift-1',
        'gift-2',
        'gift-3',
        'gift-4',
        'gift-5',
      ]);
    });

    test('records follow and like rush counts with minute deduped highlights',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();
      final startedAt = DateTime(2026, 1, 1, 12);

      notifier.startLive('streamer');
      notifier.recordFollow(startedAt);
      notifier.recordFollow(startedAt.add(const Duration(seconds: 10)));
      notifier.recordLikeRush(startedAt.add(const Duration(seconds: 20)));
      notifier.recordLikeRush(startedAt.add(const Duration(seconds: 30)));
      notifier.recordLikeRush(startedAt.add(const Duration(minutes: 1)));

      final stats = container.read(mainProvider).sessionStats;
      expect(stats.followCount, 2);
      expect(stats.likeRushCount, 3);
      expect(
        stats.highlights.where((event) => event.type == HighlightType.follow),
        hasLength(1),
      );
      expect(
        stats.highlights.where((event) => event.type == HighlightType.likeRush),
        hasLength(2),
      );
    });

    test('records positive like increments separately from like rushes',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.recordLikes(4);
      notifier.recordLikes(6);
      notifier.recordLikes(0);
      notifier.recordLikes(-3);

      final stats = container.read(mainProvider).sessionStats;
      expect(stats.likeCount, 10);
      expect(stats.likeRushCount, 0);
      expect(stats.score, 0);
    });

    test('ranks gifts by value, count fallback, and one-point fallback',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();
      final startedAt = DateTime(2026, 1, 1, 12);

      notifier.startLive('streamer');
      notifier.addComment(
        _gift(
          value: 100,
          giftCount: 9,
          userKey: 'userId:a',
          userName: 'A',
          createdAt: startedAt,
        ),
      );
      notifier.addComment(
        _gift(
          value: 0,
          giftCount: 3,
          userKey: 'uniqueId:b',
          userName: 'B',
          createdAt: startedAt.add(const Duration(seconds: 1)),
        ),
      );
      notifier.addComment(
        _gift(
          value: 0,
          giftCount: null,
          userKey: 'nickname:c',
          userName: 'C',
          createdAt: startedAt.add(const Duration(seconds: 2)),
        ),
      );

      final ranking = container.read(mainProvider).sessionStats.topGiftRanking;
      expect(ranking.map((entry) => entry.points), [100, 3, 1]);
      expect(ranking.map((entry) => entry.displayName), ['A', 'B', 'C']);
    });

    test('keeps same nicknames with different stable user keys separate',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.addComment(
        _gift(
          value: 10,
          userKey: 'userId:1',
          userName: 'same-name',
        ),
      );
      notifier.addComment(
        _gift(
          value: 20,
          userKey: 'userId:2',
          userName: 'same-name',
        ),
      );

      final ranking = container.read(mainProvider).sessionStats.giftRanking;
      expect(ranking, hasLength(2));
      expect(ranking['userId:1']?.points, 10);
      expect(ranking['userId:2']?.points, 20);
    });

    test('limits gift ranking to top three and prefers earlier tied total',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();
      final startedAt = DateTime(2026, 1, 1, 12);

      notifier.startLive('streamer');
      notifier.addComment(
        _gift(
          value: 20,
          userKey: 'userId:early',
          userName: 'Early',
          createdAt: startedAt,
        ),
      );
      notifier.addComment(
        _gift(
          value: 30,
          userKey: 'userId:top',
          userName: 'Top',
          createdAt: startedAt.add(const Duration(seconds: 1)),
        ),
      );
      notifier.addComment(
        _gift(
          value: 20,
          userKey: 'userId:late',
          userName: 'Late',
          createdAt: startedAt.add(const Duration(seconds: 2)),
        ),
      );
      notifier.addComment(
        _gift(
          value: 5,
          userKey: 'userId:fourth',
          userName: 'Fourth',
          createdAt: startedAt.add(const Duration(seconds: 3)),
        ),
      );

      final ranking = container.read(mainProvider).sessionStats.topGiftRanking;
      expect(ranking, hasLength(3));
      expect(
          ranking.map((entry) => entry.displayName), ['Top', 'Early', 'Late']);
    });

    test('stop retains social totals and ranking until the next session',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.recordFollow(DateTime(2026));
      notifier.recordLikes(12);
      notifier.addComment(
        _gift(value: 10, userKey: 'userId:viewer', userName: 'Viewer'),
      );
      notifier.stopLive();

      final completed = container.read(mainProvider).sessionStats;
      expect(completed.followCount, 1);
      expect(completed.likeCount, 12);
      expect(completed.topGiftRanking.single.displayName, 'Viewer');

      notifier.startLive('streamer');
      final next = container.read(mainProvider).sessionStats;
      expect(next.followCount, 0);
      expect(next.likeCount, 0);
      expect(next.giftRanking, isEmpty);
    });

    test('orders social highlights between big and regular gifts', () {
      final timestamp = DateTime(2026, 1, 1, 12, 30);
      var stats = SessionStats(startedAt: timestamp);
      for (final type in HighlightType.values) {
        stats = stats.addHighlight(
          HighlightEvent(
            timestamp: timestamp,
            type: type,
            title: type.name,
          ),
        );
      }

      expect(stats.topHighlights.map((event) => event.type), [
        HighlightType.premiumGift,
        HighlightType.bigGift,
        HighlightType.likeRush,
        HighlightType.follow,
        HighlightType.gift,
      ]);
    });

    test('preparing a new attempt clears the previous result', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.addComment(_comment());
      notifier.recordFollow(DateTime(2026));
      notifier.recordLikeRush(DateTime(2026));
      notifier.stopLive();
      expect(
          container.read(mainProvider).sessionStats.hasCompletedSession, true);

      notifier.prepareSession();
      final prepared = container.read(mainProvider).sessionStats;
      expect(prepared.hasCompletedSession, false);
      expect(prepared.highlights, isEmpty);
      expect(prepared.commentCount, 0);
      expect(prepared.followCount, 0);
      expect(prepared.likeCount, 0);
      expect(prepared.likeRushCount, 0);
      expect(prepared.giftRanking, isEmpty);
    });
  });
}

CommentModel _comment({String id = 'comment', DateTime? createdAt}) {
  return CommentModel(
    id: id,
    userName: 'viewer',
    text: 'hello',
    type: CommentType.normal,
    createdAt: createdAt ?? DateTime(2026),
  );
}

CommentModel _gift({
  required int value,
  int? giftCount = 1,
  String? userKey,
  String userName = 'viewer',
  DateTime? createdAt,
}) {
  return CommentModel(
    id: 'gift-$value-${userKey ?? userName}',
    userName: userName,
    text: '',
    type: CommentType.gift,
    giftName: 'Gift',
    giftCount: giftCount,
    giftValue: value,
    userKey: userKey,
    createdAt: createdAt ?? DateTime(2026),
  );
}

CommentModel _giftWithoutValue() {
  return CommentModel(
    id: 'gift-unknown',
    userName: 'viewer',
    text: '',
    type: CommentType.gift,
    giftName: 'Gift',
    createdAt: DateTime(2026),
  );
}
