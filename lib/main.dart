import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'features/main/main_provider.dart';
import 'features/main/main_screen.dart';
import 'features/main/tts_provider.dart';
import 'features/live/live_provider.dart';
import 'services/app_logger.dart';
import 'services/tts_service.dart';

final wakelockShouldEnableProvider = Provider<bool>((ref) {
  final keep = ref.watch(
    ttsSettingsProvider.select((settings) => settings.keepScreenOn),
  );
  final live = ref.watch(
    mainProvider.select((state) => state.isLive),
  );
  return keep && live;
});

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };
      final previousPlatformErrorHandler =
          ui.PlatformDispatcher.instance.onError;
      ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error(
          'PlatformDispatcher uncaught error',
          error: error,
          stackTrace: stackTrace,
        );
        return previousPlatformErrorHandler?.call(error, stackTrace) ?? true;
      };

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      runApp(
        const ProviderScope(
          child: LiveVoiceBoxApp(),
        ),
      );

      unawaited(ttsService.init());
    },
    (error, stackTrace) {
      AppLogger.error(
        'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class LiveVoiceBoxApp extends StatelessWidget {
  const LiveVoiceBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'LiveVoice Box',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF050815),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFF72F6FF),
          secondary: const Color(0xFFFF4F7D),
          surface: const Color(0xFF0B1020),
        ),
      ),
      home: const _WakelockWrapper(child: MainScreen()),
    );
  }
}

class _WakelockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const _WakelockWrapper({required this.child});

  @override
  ConsumerState<_WakelockWrapper> createState() => _WakelockWrapperState();
}

class _WakelockWrapperState extends ConsumerState<_WakelockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldLock = ref.read(wakelockShouldEnableProvider);
      WakelockPlus.toggle(enable: shouldLock);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.info('app lifecycle changed: ${state.name}');
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(liveProvider.notifier).onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(wakelockShouldEnableProvider, (previous, next) {
      if (previous == next) return;
      WakelockPlus.toggle(enable: next);
    });

    return widget.child;
  }
}
