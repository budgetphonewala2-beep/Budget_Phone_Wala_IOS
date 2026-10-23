import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../errors/app_exception.dart';

/// Email/password, Google and (iOS) Apple sign-in. Admin rights never come from the client: staff status lives in the database.
abstract class AuthService {
  /// Returns true when a session exists immediately, false when email verification is required first.
  Future<bool> signUp({required String email, required String password, required String fullName});
  Future<void> signIn({required String email, required String password});
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._c);
  final SupabaseClient _c;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 30));
    } catch (e) {
      throw toAppException(e);
    }
  }

  @override
  Future<bool> signUp({required String email, required String password, required String fullName}) => _guard(() async {
        final r = await _c.auth.signUp(
          email: email.trim(), password: password, data: {'full_name': fullName.trim()}, emailRedirectTo: AppEnv.emailRedirect,
        );
        return r.session != null;
      });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() async => _c.auth.signInWithPassword(email: email.trim(), password: password));

  // iOS opens the provider page in an in-app Safari sheet (SFSafariViewController), Android in the browser. The sheet is closed
  // by the sign-in screen once the session arrives through the deep link (see closeAuthBrowser).
  Future<void> _oauth(OAuthProvider p) => _guard(() async {
        final ok = await _c.auth.signInWithOAuth(p, redirectTo: AppEnv.oauthRedirect,
            authScreenLaunchMode: defaultTargetPlatform == TargetPlatform.iOS ? LaunchMode.inAppBrowserView : LaunchMode.platformDefault);
        if (!ok) throw AppException('UNAVAILABLE', 'Could not open the sign-in page. Please try again.');
      });

  @override
  Future<void> signInWithGoogle() => _oauth(OAuthProvider.google);

  @override
  Future<void> signInWithApple() => _oauth(OAuthProvider.apple);

  @override
  Future<void> resetPassword(String email) =>
      _guard(() async => _c.auth.resetPasswordForEmail(email.trim(), redirectTo: AppEnv.emailRedirect));

  @override
  Future<void> signOut() => _guard(() async => _c.auth.signOut());
}

sealed class PaymentOutcome {
  const PaymentOutcome();
}

class PaymentSuccess extends PaymentOutcome {
  const PaymentSuccess({required this.paymentId, required this.orderId, required this.signature});
  final String paymentId, orderId, signature;
}

class PaymentFailure extends PaymentOutcome {
  const PaymentFailure({required this.message, this.cancelled = false});
  final String message;
  final bool cancelled;
}

/// Opens the payment sheet for a server-created order. The result is only a UI signal; the server verifies it.
abstract class PaymentLauncher {
  Future<PaymentOutcome> pay({
    required String keyId, required String razorpayOrderId, required int amountPaise, required String name,
    required String description, String? contact, String? email,
  });
}

class RazorpayLauncher implements PaymentLauncher {
  @override
  Future<PaymentOutcome> pay({
    required String keyId, required String razorpayOrderId, required int amountPaise, required String name,
    required String description, String? contact, String? email,
  }) {
    final completer = Completer<PaymentOutcome>();
    final rz = Razorpay();
    void done(PaymentOutcome o) {
      if (!completer.isCompleted) completer.complete(o);
      rz.clear();
    }

    rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (r.paymentId == null || r.orderId == null || r.signature == null) {
        done(const PaymentFailure(message: 'Payment details were incomplete. We will check with the bank.'));
      } else {
        done(PaymentSuccess(paymentId: r.paymentId!, orderId: r.orderId!, signature: r.signature!));
      }
    });
    rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      // code 2 = cancelled by the user on Android/iOS
      final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
      done(PaymentFailure(
        cancelled: cancelled,
        message: cancelled ? 'Payment was cancelled.' : (r.message?.isNotEmpty == true ? r.message! : 'Payment did not go through.'),
      ));
    });
    rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});

    try {
      rz.open({
        'key': keyId,
        'order_id': razorpayOrderId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'BudgetPhonewala',
        'description': description,
        'prefill': {
          'contact': contact == null ? '' : (contact.length == 10 ? '+91$contact' : contact),
          if (email != null && email.isNotEmpty) 'email': email,
          'name': name,
        },
        'theme': {'color': '#D7263D'},
        'retry': {'enabled': true, 'max_count': 3},
      });
    } catch (_) {
      done(const PaymentFailure(message: 'Could not open the payment window. Please try again.'));
    }
    return completer.future;
  }
}
