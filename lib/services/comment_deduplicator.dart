class CommentDeduplicator {
  static const Duration window = Duration(seconds: 5);
  static const int _maxEntries = 200;

  final Map<String, DateTime> _seen = {};

  int get length => _seen.length;

  /// Returns true when [userKey]+[normalizedText] was seen within [window].
  /// Registers the pair and returns false on first / expired occurrence.
  bool isDuplicate(String userKey, String normalizedText, DateTime now) {
    _pruneExpired(now);
    final key = '$userKey\x00$normalizedText';
    final lastSeen = _seen[key];
    if (lastSeen != null && now.difference(lastSeen) < window) {
      return true;
    }
    if (_seen.length >= _maxEntries) {
      _seen.clear();
    }
    _seen[key] = now;
    return false;
  }

  void reset() => _seen.clear();

  static String normalizeText(String text) => text
      .replaceAll('　', ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();

  void _pruneExpired(DateTime now) {
    _seen.removeWhere((_, at) => now.difference(at) >= window);
  }
}
