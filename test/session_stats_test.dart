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
    });

    test('calculates and clamps the score', () {
      const stats = SessionStats(
        lastDuration: Duration(minutes: 2),
        commentCount: 10,
        giftCount: 2,
        bigGiftCount: 1,
      );
      expect(stats.score, 39);

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
      expect(completed.hasCompletedSession, isTrue);
      expect(completed.score, 2);
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

    test('preparing a new attempt clears the previous result', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      notifier.startLive('streamer');
      notifier.addComment(_comment());
      notifier.stopLive();
      expect(
          container.read(mainProvider).sessionStats.hasCompletedSession, true);

      notifier.prepareSession();
      final prepared = container.read(mainProvider).sessionStats;
      expect(prepared.hasCompletedSession, false);
      expect(prepared.highlights, isEmpty);
      expect(prepared.commentCount, 0);
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

CommentModel _gift({required int value, DateTime? createdAt}) {
  return CommentModel(
    id: 'gift-$value',
    userName: 'viewer',
    text: '',
    type: CommentType.gift,
    giftName: 'Gift',
    giftCount: 1,
    giftValue: value,
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
