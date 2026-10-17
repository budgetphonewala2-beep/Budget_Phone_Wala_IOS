import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-safe error. [code] is a stable machine value (NETWORK, UNAUTHENTICATED, UNAVAILABLE, BAD_REQUEST, ...).
class AppException implements Exception {
  AppException(this.code, this.message);
  final String code;
  final String message;
  bool get isNetwork => code == 'NETWORK';
  bool get isAuth => code == 'UNAUTHENTICATED';
  @override
  String toString() => message;
}

final _pgCode = RegExp(r'^([A-Z_]+):(.*)$', dotAll: true);

/// Converts any thrown error into an [AppException] without leaking internals.
AppException toAppException(Object e) {
  if (e is AppException) return e;
  if (e is PostgrestException) {
    final m = _pgCode.firstMatch(e.message);
    if (m != null) return AppException(m.group(1)!, m.group(2)!.trim());
    if (e.code == '42501' || e.code == 'PGRST301') return AppException('UNAUTHENTICATED', 'Please sign in to continue.');
    return AppException('ERROR', 'Something went wrong. Please try again.');
  }
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) {
      return AppException((d['code'] ?? 'ERROR').toString(), d['error'].toString());
    }
    if (e.status == 401) return AppException('UNAUTHENTICATED', 'Please sign in to continue.');
    return AppException('ERROR', 'Something went wrong. Please try again.');
  }
  if (e is AuthException) {
    return AppException(e.code ?? 'AUTH', _friendlyAuth(e.message));
  }
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup') || s.contains('TimeoutException')) {
    return AppException('NETWORK', 'No internet connection. Check your network and try again.');
  }
  return AppException('ERROR', 'Something went wrong. Please try again.');
}

String _friendlyAuth(String m) {
  final l = m.toLowerCase();
  if (l.contains('invalid login')) return 'Wrong email or password.';
  if (l.contains('email not confirmed')) return 'Please verify your email first. Check your inbox.';
  if (l.contains('already registered') || l.contains('already been registered')) return 'This email is already registered. Try signing in.';
  if (l.contains('rate limit') || l.contains('too many')) return 'Too many attempts. Please wait a minute and try again.';
  if (l.contains('password')) return 'Password is too weak. Use at least 8 characters.';
  return m;
}
