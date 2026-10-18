import 'dart:async';

/// What the app tells the server when something unexpected happens. Deliberately small: no user profile, no addresses,
/// no phone numbers, no IMEI, no tokens, no payment data. The server scrubs again before storing anything.
class ErrorReport {
  const ErrorReport({
    required this.message,
    this.stack,
    this.operation = 'unknown',
    this.category = 'unhandled',
    this.fatal = false,
    this.requestId,
  });
  final String message;
  final String? stack;
  final String operation, category;
  final bool fatal;
  final String? requestId;
}

/// Removes anything that must never leave the device inside an error message or stack trace.
String scrubForReport(String input, {int max = 1000}) {
  var s = input
      .replaceAll(RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}'), '[token]')
      .replaceAll(RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), '[email]')
      .replaceAllMapped(RegExp(r'\b(apikey|authorization|password|secret|token|bearer)\s*[=:]\s*\S+', caseSensitive: false), (m) => '${m[1]}=[redacted]')
      .replaceAll(RegExp(r'\b\d{9,}\b'), '[number]');
  if (s.length > max) s = s.substring(0, max);
  return s;
}

abstract class ErrorReporter {
  void report(Object error, StackTrace? stack, {String operation, String category, bool fatal});
}

class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();
  @override
  void report(Object error, StackTrace? stack, {String operation = 'unknown', String category = 'unhandled', bool fatal = false}) {}
}

typedef ReportSender = Future<void> Function(Map<String, dynamic> body);

/// Sends reports to the shop's own backend. Never throws and never blocks the UI: reporting is best-effort and the app
/// keeps working when it fails. A crash loop is bounded to [maxPerMinute] reports and identical errors are sent once a minute.
class RemoteErrorReporter implements ErrorReporter {
  RemoteErrorReporter({
    required this.send,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    this.maxPerMinute = 5,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReportSender send;
  final String appVersion, buildNumber, platform;
  final int maxPerMinute;
  final DateTime Function() _now;
  final List<DateTime> _sent = [];
  final Map<String, DateTime> _recent = {};

  @override
  void report(Object error, StackTrace? stack, {String operation = 'unknown', String category = 'unhandled', bool fatal = false}) {
    try {
      final now = _now();
      _sent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
      _recent.removeWhere((_, t) => now.difference(t) > const Duration(minutes: 1));
      final message = scrubForReport(error.toString());
      final key = '$category|$operation|${message.length > 120 ? message.substring(0, 120) : message}';
      if (_sent.length >= maxPerMinute || _recent.containsKey(key)) return;
      _sent.add(now);
      _recent[key] = now;
      final body = <String, dynamic>{
        'app_version': appVersion, 'build_number': buildNumber, 'platform': platform,
        'operation': operation, 'category': category, 'fatal': fatal,
        'message': message, 'stack': scrubForReport(stack?.toString() ?? '', max: 4000),
      };
      unawaited(send(body).catchError((Object _) {}));
    } catch (_) {
      // reporting must never create a new problem
    }
  }
}
