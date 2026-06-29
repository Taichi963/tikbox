import 'package:flutter_test/flutter_test.dart';
import 'package:tikbox/features/main/main_provider.dart';
import 'package:tikbox/models/comment_model.dart';

void main() {
  group('CommentModel.ttsText', () {
    test('normal comment includes userName and text', () {
      final comment = CommentModel(
        id: '1',
        userName: 'viewer',
        text: 'こんにちは',
        type: CommentType.normal,
        createdAt: DateTime(2026),
      );
      expect(comment.ttsText, 'viewer さん こんにちは');
    });

    test('gift comment uses giftName, giftCount, and userName', () {
      final comment = CommentModel(
        id: '2',
        userName: 'viewer',
        text: '',
        type: CommentType.gift,
        giftName: 'Rose',
        giftCount: 3,
        giftValue: 30,
        createdAt: DateTime(2026),
      );
      expect(comment.ttsText, 'viewer さんから Rose を 3 個もらいました');
    });

    test('gift comment falls back to giftCount=1 when null', () {
      final comment = CommentModel(
        id: '3',
        userName: 'viewer',
        text: '',
        type: CommentType.gift,
        giftName: 'Rose',
        giftValue: 10,
        createdAt: DateTime(2026),
        // giftCount omitted → null
      );
      expect(comment.ttsText, 'viewer さんから Rose を 1 個もらいました');
    });

    test('gift comment falls back to ギフト when giftName is null', () {
      final comment = CommentModel(
        id: '4',
        userName: 'viewer',
        text: '',
        type: CommentType.gift,
        giftCount: 2,
        giftValue: 20,
        createdAt: DateTime(2026),
        // giftName omitted → null
      );
      expect(comment.ttsText, 'viewer さんから ギフト を 2 個もらいました');
    });

    test('isGift is true only for gift type', () {
      final normalComment = CommentModel(
        id: '5',
        userName: 'v',
        text: 'hi',
        type: CommentType.normal,
        createdAt: DateTime(2026),
      );
      final giftComment = CommentModel(
        id: '6',
        userName: 'v',
        text: '',
        type: CommentType.gift,
        giftValue: 10,
        createdAt: DateTime(2026),
      );
      expect(normalComment.isGift, isFalse);
      expect(giftComment.isGift, isTrue);
    });

    test('priority is higher for gifts', () {
      final normalComment = CommentModel(
        id: '7',
        userName: 'v',
        text: 'hi',
        type: CommentType.normal,
        createdAt: DateTime(2026),
      );
      final giftComment = CommentModel(
        id: '8',
        userName: 'v',
        text: '',
        type: CommentType.gift,
        giftValue: 1,
        createdAt: DateTime(2026),
      );
      expect(giftComment.priority, greaterThan(normalComment.priority));
    });

    test('giftRank returns normal for non-gift comments', () {
      final comment = CommentModel(
        id: '9',
        userName: 'v',
        text: 'hi',
        type: CommentType.normal,
        createdAt: DateTime(2026),
      );
      expect(comment.giftRank, GiftRank.normal);
    });
  });

  group('BlockedUserEntry serialization', () {
    test('uniqueId entry survives a toStorageValue / fromStorageValue roundtrip',
        () {
      const entry = BlockedUserEntry(
        key: 'uniqueId:viewer_01',
        label: 'Viewer',
        source: 'uniqueId',
        persistent: true,
      );

      final restored = BlockedUserEntry.fromStorageValue(entry.toStorageValue());

      expect(restored, isNotNull);
      expect(restored!.key, entry.key);
      expect(restored.label, entry.label);
      expect(restored.source, entry.source);
      expect(restored.persistent, isTrue);
    });

    test('fromStorageValue returns null for malformed JSON', () {
      expect(BlockedUserEntry.fromStorageValue('not-json'), isNull);
      expect(BlockedUserEntry.fromStorageValue('{invalid'), isNull);
    });

    test('fromStorageValue returns null when key does not start with uniqueId:',
        () {
      // nickname-keyed entries must not be restored (they are session-only).
      const entry = BlockedUserEntry(
        key: 'nickname:someuser',
        label: 'SomeUser',
        source: 'nickname',
        persistent: false,
      );
      expect(
        BlockedUserEntry.fromStorageValue(entry.toStorageValue()),
        isNull,
      );
    });

    test('fromStorageValue returns null for empty JSON object', () {
      expect(BlockedUserEntry.fromStorageValue('{}'), isNull);
    });

    test('fromStorageValue returns null for JSON array instead of object', () {
      expect(BlockedUserEntry.fromStorageValue('[]'), isNull);
    });
  });
}
