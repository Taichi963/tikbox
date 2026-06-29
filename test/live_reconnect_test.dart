import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikbox/features/live/live_provider.dart';

void main() {
  group('LiveNotifier reconnect backoff', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('exponential backoff: attempts 1–4 double each time', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(liveProvider.notifier);

      expect(notifier.debugReconnectDelayForAttempt(1), const Duration(seconds: 1));
      expect(notifier.debugReconnectDelayForAttempt(2), const Duration(seconds: 2));
      expect(notifier.debugReconnectDelayForAttempt(3), const Duration(seconds: 4));
      expect(notifier.debugReconnectDelayForAttempt(4), const Duration(seconds: 8));
    });

    test('attempt 5 reaches the 16-second cap', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(liveProvider.notifier);

      expect(notifier.debugReconnectDelayForAttempt(5), const Duration(seconds: 16));
    });

    test('attempt 6 and beyond stays capped at 16 seconds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(liveProvider.notifier);

      // Attempt 6 = 1 << 5 = 32 → capped to 16
      expect(notifier.debugReconnectDelayForAttempt(6), const Duration(seconds: 16));
      // Well beyond the cap: still 16 seconds
      expect(notifier.debugReconnectDelayForAttempt(10), const Duration(seconds: 16));
    });
  });
}
