import 'dart:async';
import 'dart:math';

/// True for failures that are worth repeating: the request probably never reached the server or the server was briefly unavailable.
/// Never true for a normal business error (sold out, bad coupon, forbidden...), which a repeat cannot fix.
bool isTransientFailure(Object e) {
  if (e is TimeoutException) return true;
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup') ||
      s.contains('HandshakeException') || s.contains('Connection reset') || s.contains('Connection closed')) {
    return true;
  }
  // gateway errors from the API layer
  final m = RegExp(r'\b(502|503|504)\b').firstMatch(s);
  return m != null && (s.contains('PostgrestException') || s.contains('FunctionException'));
}

/// Runs [action] and repeats it on transient failures with exponential backoff and random jitter (no retry storms:
/// at most [attempts] tries, delays 0.4 s, 0.8 s... with +-50% jitter). ONLY use for requests that are safe to repeat (reads).
Future<T> retryTransient<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration base = const Duration(milliseconds: 400),
  Random? random,
  Future<void> Function(Duration)? sleep,
  bool Function(Object)? retryIf,
}) async {
  final rng = random ?? Random();
  final wait = sleep ?? (d) => Future<void>.delayed(d);
  final shouldRetry = retryIf ?? isTransientFailure;
  for (var i = 1;; i++) {
    try {
      return await action();
    } catch (e) {
      if (i >= attempts || !shouldRetry(e)) rethrow;
      final exp = base.inMilliseconds * pow(2, i - 1);
      final jitter = 0.5 + rng.nextDouble(); // 0.5x to 1.5x
      await wait(Duration(milliseconds: (exp * jitter).round()));
    }
  }
}
