import 'package:flutter_test/flutter_test.dart';
import 'package:tikbox/services/comment_deduplicator.dart';

void main() {
  group('CommentDeduplicator', () {
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    test('same user, same text, within window → duplicate', () {
      final dedup = CommentDeduplicator();
      expect(dedup.isDuplicate('uniqueId:alice', 'hello', t0), isFalse);
      expect(
        dedup.isDuplicate(
          'uniqueId:alice',
          'hello',
          t0.add(const Duration(seconds: 4)),
        ),
        isTrue,
      );
    });

    test('same user, same text, at window boundary → not duplicate', () {
      final dedup = CommentDeduplicator();
      expect(dedup.isDuplicate('uniqueId:alice', 'hello', t0), isFalse);
      expect(
        dedup.isDuplicate(
          'uniqueId:alice',
          'hello',
          t0.add(CommentDeduplicator.window),
        ),
        isFalse,
      );
    });

    test('same text, different users → not duplicate', () {
      final dedup = CommentDeduplicator();
      expect(dedup.isDuplicate('uniqueId:alice', 'hello', t0), isFalse);
      expect(
        dedup.isDuplicate(
          'uniqueId:bob',
          'hello',
          t0.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('same user, different text → not duplicate', () {
      final dedup = CommentDeduplicator();
      expect(dedup.isDuplicate('uniqueId:alice', 'hello', t0), isFalse);
      expect(
        dedup.isDuplicate(
          'uniqueId:alice',
          'world',
          t0.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('reset clears history so same comment fires again', () {
      final dedup = CommentDeduplicator();
      expect(dedup.isDuplicate('uniqueId:alice', 'hello', t0), isFalse);
      dedup.reset();
      expect(
        dedup.isDuplicate(
          'uniqueId:alice',
          'hello',
          t0.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('whitespace-normalized texts are treated as the same comment', () {
      final dedup = CommentDeduplicator();
      final text1 = CommentDeduplicator.normalizeText('  hello  world  ');
      final text2 = CommentDeduplicator.normalizeText('hello world');
      expect(dedup.isDuplicate('uniqueId:alice', text1, t0), isFalse);
      expect(
        dedup.isDuplicate(
          'uniqueId:alice',
          text2,
          t0.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('history does not grow without bound', () {
      final dedup = CommentDeduplicator();
      // All entries at this time are fresh (not expired).
      final now = t0;
      for (var i = 0; i < 300; i++) {
        dedup.isDuplicate('user:$i', 'text', now);
      }
      expect(dedup.length, lessThan(300));
    });
  });

  group('CommentDeduplicator.normalizeText', () {
    test('trims and collapses whitespace', () {
      expect(
        CommentDeduplicator.normalizeText('  hello   world  '),
        'hello world',
      );
    });

    test('converts ideographic space to regular space', () {
      expect(
        CommentDeduplicator.normalizeText('hello　world'),
        'hello world',
      );
    });

    test('lowercases ASCII characters', () {
      expect(CommentDeduplicator.normalizeText('Hello World'), 'hello world');
    });
  });
}
