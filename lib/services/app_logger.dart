import 'dart:developer' as developer;

class AppLogger {
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'TikBox',
      error: error,
      stackTrace: stackTrace,
      level: 800,
    );
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'TikBox',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'TikBox',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
