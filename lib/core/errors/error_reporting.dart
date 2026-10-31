import 'package:flutter/foundation.dart';

/// Central place for uncaught errors. Replace [report] with a crash reporting
/// service (Sentry, Firebase Crashlytics...) in production; by default errors
/// are only logged so nothing leaves the user's browser.
typedef ErrorReporter = void Function(Object error, StackTrace? stack);

void installGlobalErrorHandlers({ErrorReporter? report}) {
  final reporter = report ?? _log;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter(details.exception, details.stack);
  };
  // Errors outside the Flutter framework (async gaps, platform callbacks).
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter(error, stack);
    return true; // handled: do not crash the app
  };
}

void _log(Object error, StackTrace? stack) =>
    debugPrint('Uncaught error: $error\n$stack');
