import 'package:flutter_test/flutter_test.dart';
import 'package:tikbox/services/tts_service.dart';

void main() {
  final service = ttsService;

  group('TtsService.debugSanitizeText output', () {
    test('empty string returns empty', () {
      expect(service.debugSanitizeText(''), isEmpty);
    });

    test('URL is replaced with URL省略', () {
      expect(service.debugSanitizeText('https://example.com'), 'URL省略');
    });

    test('URL embedded in text is replaced inline', () {
      expect(
        service.debugSanitizeText('見てね https://example.com ありがとう'),
        '見てね URL省略 ありがとう',
      );
    });

    test('www × 3+ becomes 笑', () {
      expect(service.debugSanitizeText('wwwww'), '笑');
    });

    test('(笑) becomes 笑', () {
      expect(service.debugSanitizeText('おもしろい(笑)'), 'おもしろい笑');
    });

    test('text longer than 30 characters is truncated with 以下省略', () {
      // 32 unique chars — no 4+ consecutive repeats, so only the truncation
      // rule fires (not the repeat-collapse rule).
      const longText = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみ';
      final result = service.debugSanitizeText(longText);
      expect(result, endsWith('以下省略'));
      expect(result.length, lessThanOrEqualTo(36));
    });

    test('4+ repeated characters are collapsed to 3', () {
      expect(service.debugSanitizeText('aaaaaaaa'), 'aaa');
    });

    test('decorative emoji is removed', () {
      expect(service.debugSanitizeText('🎉'), isEmpty);
    });

    test('emoji between text is replaced with a space then trimmed', () {
      final result = service.debugSanitizeText('配信🎉ありがとう');
      // Emoji becomes a space between the two text segments.
      expect(result, '配信 ありがとう');
    });

    test('two or more consecutive punctuation collapses to a space then trims', () {
      expect(service.debugSanitizeText('!!!'), isEmpty);
      expect(service.debugSanitizeText('…………'), isEmpty);
    });

    test('normal Japanese text passes through unchanged', () {
      expect(service.debugSanitizeText('こんにちは'), 'こんにちは');
    });
  });

  group('TtsService.hasSpeakableText', () {
    test('empty string is not speakable', () {
      expect(service.hasSpeakableText(''), isFalse);
    });

    test('normal Japanese comment is speakable', () {
      expect(service.hasSpeakableText('こんにちは'), isTrue);
    });

    test('URL-only comment is speakable as URL省略', () {
      // URL is replaced with 'URL省略', which is non-empty → speakable.
      expect(service.hasSpeakableText('https://example.com'), isTrue);
    });

    test('decorative emoji alone is not speakable', () {
      // U+1F389 🎉 is in the decorative rune range (0x1F000–0x1FAFF).
      // Removed → trimmed → empty.
      expect(service.hasSpeakableText('🎉'), isFalse);
    });

    test('two or more consecutive punctuation symbols collapse to not speakable', () {
      // "!!!" matches [!]{2,} → space → trim → empty.
      expect(service.hasSpeakableText('!!!'), isFalse);
      // "…" alone matches [.]{2,} pattern via U+2026 → space → trim → empty.
      // Actually "…" is a single character, so let's use "…………" (5× ellipsis).
      expect(service.hasSpeakableText('…………'), isFalse);
    });

    test('long text is speakable after truncation', () {
      // 50 Japanese characters — exceeds the 30-char limit.
      // The truncated result still contains text, so it is speakable.
      final longText = 'あ' * 50;
      expect(service.hasSpeakableText(longText), isTrue);
    });

    test('mixed emoji and text is speakable when text survives cleaning', () {
      // Emoji is removed but the surrounding Japanese text survives.
      expect(service.hasSpeakableText('配信🎉ありがとう'), isTrue);
    });

    test('four or more repeated characters are collapsed to three', () {
      // "aaaaaaa" → "aaa" (non-empty) → speakable.
      expect(service.hasSpeakableText('aaaaaaa'), isTrue);
    });

    test('www × 3+ is replaced with 笑 and is speakable', () {
      // "wwwww" matches [wW]{3,} → "笑" → speakable.
      expect(service.hasSpeakableText('wwwww'), isTrue);
    });

    test('text with embedded URL leaves surrounding text speakable', () {
      expect(
        service.hasSpeakableText('見てね https://example.com ありがとう'),
        isTrue,
      );
    });
  });
}
