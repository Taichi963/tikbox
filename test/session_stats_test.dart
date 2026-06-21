import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikbox/features/main/main_provider.dart';
import 'package:tikbox/models/comment_model.dart';

void main() {
  group('GiftRank', () {
    test('classifies gift value boundaries', () {
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
  });
}

CommentModel _comment() {
  return CommentModel(
    id: 'comment',
    userName: 'viewer',
    text: 'hello',
    type: CommentType.normal,
    createdAt: DateTime(2026),
  );
}

CommentModel _gift({required int value}) {
  return CommentModel(
    id: 'gift-$value',
    userName: 'viewer',
    text: '',
    type: CommentType.gift,
    giftName: 'Gift',
    giftCount: 1,
    giftValue: value,
    createdAt: DateTime(2026),
  );
}
