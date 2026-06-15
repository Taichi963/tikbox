enum CommentType {
  normal,
  gift,
}

class CommentModel {
  final String id;
  final String userName;
  final String text;
  final CommentType type;
  final String? giftName;
  final int? giftCount;
  final int giftValue;
  final String? userKey;
  final String? userKeySource;
  final String? userReference;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.userName,
    required this.text,
    required this.type,
    required this.createdAt,
    this.giftName,
    this.giftCount,
    this.giftValue = 0,
    this.userKey,
    this.userKeySource,
    this.userReference,
  });

  bool get isGift => type == CommentType.gift;

  int get priority => isGift ? 100 : 10;

  String get ttsText {
    if (isGift) {
      final gift = giftName ?? 'ギフト';
      final count = giftCount ?? 1;
      return '$userName さんから $gift を $count 個もらいました';
    }
    return '$userName さん $text';
  }
}
