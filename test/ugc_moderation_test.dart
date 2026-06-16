import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikbox/features/main/main_provider.dart';
import 'package:tikbox/models/comment_model.dart';
import 'package:tikbox/services/ugc_moderation_service.dart';

void main() {
  group('UgcModerationService', () {
    test('normalizes full-width and separated blocked terms', () {
      expect(
        UgcModerationService.containsBlockedTerm(
          userName: 'viewer',
          text: 'ＫＩＬＬ　ＹＯＵＲＳＥＬＦ',
          customTerms: const [],
        ),
        isTrue,
      );
      expect(
        UgcModerationService.containsBlockedTerm(
          userName: 'viewer',
          text: '安全なコメントです',
          customTerms: const ['追加ワード'],
        ),
        isFalse,
      );
    });

    test('prefers persistent uniqueId and falls back to session nickname', () {
      final uniqueIdentity = UgcModerationService.resolveIdentity(
        uniqueId: 'Viewer_01',
        nickname: '表示名',
      );
      expect(uniqueIdentity.key, 'uniqueId:viewer_01');
      expect(uniqueIdentity.persistent, isTrue);

      final nicknameIdentity = UgcModerationService.resolveIdentity(
        uniqueId: null,
        nickname: ' 表示 名 ',
      );
      expect(nicknameIdentity.key, 'nickname:表示名');
      expect(nicknameIdentity.persistent, isFalse);
    });

    test('builds a minimal email report without internal identifiers', () {
      final report = UgcModerationService.buildReportText(
        supportEmail: 'zeb0kui3ackwv4pft1us@gmail.com',
        reason: '嫌がらせ・誹謗中傷',
        displayName: 'Viewer',
        userKeySource: 'uniqueId',
        userReference: 'viewer_01',
        commentText: 'report target',
        receivedAt: DateTime.utc(2026, 6, 13, 12, 30),
      );

      expect(report, contains('宛先: zeb0kui3ackwv4pft1us@gmail.com'));
      expect(report, contains('件名: LiveVoice Box コメント通報'));
      expect(report, contains('通報理由: 嫌がらせ・誹謗中傷'));
      expect(report, contains('userKey種別: uniqueId'));
      expect(report, contains('ユーザー参照: viewer_01'));
      expect(report, contains('コメント本文: report target'));
      expect(report, isNot(contains('Cookie')));
      expect(report, isNot(contains('ttwid')));
      expect(report, isNot(contains('端末ID')));
      expect(report, isNot(contains('内部ログ')));
      expect(report, isNot(contains('認証情報')));
    });
  });

  group('MainNotifier moderation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('blocks comments until moderation settings finish loading', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);

      expect(container.read(mainProvider).moderationReady, isFalse);
      expect(
        notifier.moderationDecision(
          userKey: 'uniqueId:viewer',
          userName: 'viewer',
          text: 'hello',
        ),
        UgcModerationDecision.settingsLoading,
      );

      await notifier.ensureModerationReady();
      expect(container.read(mainProvider).moderationReady, isTrue);
    });

    test('persists uniqueId blocks and custom blocked terms', () async {
      final firstContainer = ProviderContainer();
      final firstNotifier = firstContainer.read(mainProvider.notifier);
      await firstNotifier.ensureModerationReady();

      expect(await firstNotifier.addCustomBlockedTerm('追加ワード'), isNull);
      await firstNotifier.blockUser(
        CommentModel(
          id: '1',
          userName: 'Viewer',
          text: 'hello',
          type: CommentType.normal,
          createdAt: DateTime(2026),
          userKey: 'uniqueId:viewer',
          userKeySource: 'uniqueId',
          userReference: 'viewer',
        ),
      );
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      final secondNotifier = secondContainer.read(mainProvider.notifier);
      await secondNotifier.ensureModerationReady();

      expect(
        secondNotifier.moderationDecision(
          userKey: 'uniqueId:viewer',
          userName: 'Viewer',
          text: 'hello',
        ),
        UgcModerationDecision.blockedUser,
      );
      expect(
        secondNotifier.moderationDecision(
          userKey: 'uniqueId:other',
          userName: 'Other',
          text: 'これは追加ワードです',
        ),
        UgcModerationDecision.blockedTerm,
      );
    });

    test('does not persist nickname fallback blocks', () async {
      final firstContainer = ProviderContainer();
      final firstNotifier = firstContainer.read(mainProvider.notifier);
      await firstNotifier.ensureModerationReady();
      await firstNotifier.blockUser(
        CommentModel(
          id: '1',
          userName: '同じ表示名',
          text: 'hello',
          type: CommentType.normal,
          createdAt: DateTime(2026),
          userKey: 'nickname:同じ表示名',
          userKeySource: 'nickname',
          userReference: '同じ表示名',
        ),
      );
      expect(firstContainer.read(mainProvider).blockedUsers, hasLength(1));
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      await secondContainer.read(mainProvider.notifier).ensureModerationReady();
      expect(secondContainer.read(mainProvider).blockedUsers, isEmpty);
    });

    test('clears only session blocks when a live session stops', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mainProvider.notifier);
      await notifier.ensureModerationReady();

      await notifier.blockUser(
        CommentModel(
          id: 'persistent',
          userName: 'Persistent',
          text: 'hello',
          type: CommentType.normal,
          createdAt: DateTime(2026),
          userKey: 'uniqueId:persistent',
          userKeySource: 'uniqueId',
          userReference: 'persistent',
        ),
      );
      await notifier.blockUser(
        CommentModel(
          id: 'session',
          userName: 'Session',
          text: 'hello',
          type: CommentType.normal,
          createdAt: DateTime(2026),
          userKey: 'nickname:session',
          userKeySource: 'nickname',
          userReference: 'Session',
        ),
      );

      notifier.stopLive();

      expect(
        container.read(mainProvider).blockedUsers.map((entry) => entry.key),
        ['uniqueId:persistent'],
      );
    });
  });
}
