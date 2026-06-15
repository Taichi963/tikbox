enum UgcModerationDecision {
  allow,
  settingsLoading,
  blockedUser,
  blockedTerm,
}

class UgcUserIdentity {
  final String key;
  final String source;
  final String reference;
  final bool persistent;

  const UgcUserIdentity({
    required this.key,
    required this.source,
    required this.reference,
    required this.persistent,
  });
}

class UgcModerationService {
  static const String reportSubject = 'LiveVoice Box コメント通報';

  static const List<String> fixedBlockedTerms = [
    '死ね',
    '殺してやる',
    '自殺しろ',
    'レイプ',
    '強姦',
    'kill yourself',
  ];

  static UgcUserIdentity resolveIdentity({
    required String? uniqueId,
    required String nickname,
  }) {
    final trimmedUniqueId = uniqueId?.trim() ?? '';
    if (trimmedUniqueId.isNotEmpty) {
      return UgcUserIdentity(
        key: 'uniqueId:${trimmedUniqueId.toLowerCase()}',
        source: 'uniqueId',
        reference: trimmedUniqueId,
        persistent: true,
      );
    }

    final trimmedNickname = nickname.trim();
    return UgcUserIdentity(
      key: 'nickname:${normalizeText(trimmedNickname)}',
      source: 'nickname',
      reference: trimmedNickname,
      persistent: false,
    );
  }

  static bool containsBlockedTerm({
    required String userName,
    required String text,
    required Iterable<String> customTerms,
  }) {
    final normalizedContent =
        '${normalizeText(userName)} ${normalizeText(text)}';
    if (normalizedContent.trim().isEmpty) {
      return false;
    }

    for (final term in [...fixedBlockedTerms, ...customTerms]) {
      final normalizedTerm = normalizeText(term);
      if (normalizedTerm.length >= 2 &&
          normalizedContent.contains(normalizedTerm)) {
        return true;
      }
    }
    return false;
  }

  static String buildReportText({
    required String supportEmail,
    required String reason,
    required String displayName,
    required String userKeySource,
    required String userReference,
    required String commentText,
    required DateTime receivedAt,
  }) {
    final sourceLabel = userKeySource == 'uniqueId' ? 'uniqueId' : 'nickname';
    return [
      '宛先: $supportEmail',
      '件名: $reportSubject',
      '',
      '通報理由: $reason',
      '公開表示名: $displayName',
      'userKey種別: $sourceLabel',
      'ユーザー参照: $userReference',
      'コメント本文: $commentText',
      '受信時刻: ${receivedAt.toIso8601String()}',
    ].join('\n');
  }

  static String normalizeText(String input) {
    final converted = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        converted.writeCharCode(rune - 0xFEE0);
      } else {
        converted.writeCharCode(rune);
      }
    }

    return converted.toString().toLowerCase().replaceAll(
          RegExp(
            r'[\s\u3000\u200B_\-.,!?！？。、・…:;：；~〜～^()\[\]{}<>＜＞【】「」『』]+',
          ),
          '',
        );
  }
}
