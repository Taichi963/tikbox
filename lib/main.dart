import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'features/main/main_provider.dart';
import 'features/main/main_screen.dart';
import 'features/settings/settings_provider.dart';
import 'services/app_logger.dart';
import 'services/effect_sound_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  await runZonedGuarded(
    () async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      runApp(
        const ProviderScope(
          child: TikBoxApp(),
        ),
      );

      unawaited(effectSoundService.initialize());
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

class TikBoxApp extends StatelessWidget {
  const TikBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'TikBox',
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

/// settingsProvider の keepScreenOn と mainProvider の isLive を監視し、
/// 「配信中 かつ keepScreenOn が true」のときだけスリープを防ぐ。
/// 配信停止またはアプリ終了時は自動で解除する。
class _WakelockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const _WakelockWrapper({required this.child});

  @override
  ConsumerState<_WakelockWrapper> createState() => _WakelockWrapperState();
}

class _WakelockWrapperState extends ConsumerState<_WakelockWrapper> {
  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keepScreenOn = ref.watch(settingsProvider).keepScreenOn;
    final isLive = ref.watch(mainProvider).isLive;

    final shouldLock = keepScreenOn && isLive;
    WakelockPlus.toggle(enable: shouldLock);

    return widget.child;
  }
}
