import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Native Apple sheet (Face ID / Touch ID). The ID token is exchanged with Supabase, bound to a one-time nonce.
  /// No timeout here: the person may take a while in Apple's sheet. Cancelling is not an error.
  @override
  Future<void> signInWithApple() async {
    final raw = List.generate(32, (_) => Random.secure().nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final AuthorizationCredentialAppleID cred;
    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      throw AppException('UNAVAILABLE', 'Sign in with Apple did not finish. Please try again.');
    }
    final token = cred.identityToken;
    if (token == null) throw AppException('UNAVAILABLE', 'Apple did not return a sign-in token. Please try again.');
    try {
      final res = await _c.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: token, nonce: raw).timeout(const Duration(seconds: 30));
      // Apple shares the name only on the very first sign-in: keep it if the profile has none yet
      final name = [cred.givenName, cred.familyName].whereType<String>().map((x) => x.trim()).where((x) => x.isNotEmpty).join(' ');
      final uid = res.user?.id;
      if (name.isNotEmpty && uid != null) {
        await _c.from('customer_profiles').update({'full_name': name}).eq('id', uid).eq('full_name', '');
      }
    } catch (e) {
      throw toAppException(e);
    }
  }

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
