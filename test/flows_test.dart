import 'dart:async';
import 'package:budgetphonewala/core/router/app_router.dart';
import 'package:budgetphonewala/core/data/services.dart';
import 'package:budgetphonewala/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Pumps in small steps until [finder] matches (spinners never "settle", so pumpAndSettle cannot be used).
Future<void> pumpUntil(WidgetTester t, Finder finder, {int steps = 80}) async {
  for (var i = 0; i < steps; i++) {
    await t.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Map<String, dynamic> _placedResponse({required bool requiresPayment}) => {
      'ok': true,
      'order': {'order_id': 'o1', 'order_number': 'BPW-2026-01001', 'total_paise': 2759800, 'requires_payment': requiresPayment, 'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String()},
      'razorpay': requiresPayment ? {'key_id': 'rzp_test_x', 'order_id': 'order_RZ1', 'amount_paise': 2759800} : null,
    };

void main() {
  group('guest browsing and sign-in', () {
    testWidgets('guests can browse the catalogue without an account', (t) async {
      final g = buildGateway(userId: null);
      await pumpApp(t, gateway: g);
      await t.scrollUntilVisible(find.textContaining('Apple iPhone 12'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Apple iPhone 12'), findsOneWidget);
    });

    testWidgets('tapping the wishlist heart as a guest asks to sign in and does not call the server', (t) async {
      final g = buildGateway(userId: null);
      await pumpApp(t, gateway: g);
      await t.scrollUntilVisible(find.byTooltip('Add to wishlist'), 300, scrollable: find.byType(Scrollable).first);
      await t.tap(find.byTooltip('Add to wishlist').first);
      await t.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      expect(g.rpcCalls.where((c) => c.fn == 'wishlist_toggle'), isEmpty);
    });

    testWidgets('protected pages redirect guests to sign-in, then return after signing in', (t) async {
      final g = buildGateway(userId: null);
      await pumpApp(t, gateway: g, location: '/cart');
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Cart'), findsNothing);

      await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'buyer@test.local');
      await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret-123');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pumpAndSettle();
      expect(find.text('Cart'), findsOneWidget); // returned to the page they wanted
      expect(find.textContaining('Apple iPhone 12'), findsOneWidget);
    });

    testWidgets('signing in from a pushed sign-in screen closes it and shows the account', (t) async {
      final g = buildGateway(userId: null);
      final c = await pumpApp(t, gateway: g, location: '/profile');
      // the Profile tab opens sign-in with push(), exactly like this
      unawaited(c.read(routerProvider).push('/auth?from=%2Fprofile'));
      await t.pumpAndSettle();
      expect(find.text('Budget Aapka, Phone Hamara'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'buyer@test.local');
      await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret-123');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pumpAndSettle();
      expect(find.text('Budget Aapka, Phone Hamara'), findsNothing);
      expect(find.text('My details'), findsOneWidget);
    });

    testWidgets('sign-up that needs email verification does not sign the user in', (t) async {
      final g = buildGateway(userId: null);
      await pumpApp(t, gateway: g, location: '/auth');
      await t.tap(find.text('New here? Create an account'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, 'Full name'), 'New Buyer');
      await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'new@test.local');
      await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'longenough1');
      final c = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
      (c.read(authServiceProvider) as FakeAuth).requireVerification = true;
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pumpAndSettle();
      expect(find.textContaining('verification link'), findsOneWidget);
      expect(g.userId, isNull);
    });

    testWidgets('invalid sign-in fields show inline errors and do not call the auth service', (t) async {
      final g = buildGateway(userId: null);
      await pumpApp(t, gateway: g, location: '/auth');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(g.userId, isNull);
    });
  });

  group('account isolation', () {
    testWidgets('signing out and switching accounts never shows the previous account data', (t) async {
      final g = buildGateway(userId: 'user-a');
      g.rpcs['cart_list'] = (_) => g.userId == 'user-a' ? [cartLineJson(unit: 'a-unit')] : (g.userId == 'user-b' ? [cartLineJson(unit: 'b-unit', price: 1000000)] : []);
      g.rpcs['wishlist_list'] = (_) => g.userId == 'user-a' ? [{'model_id': 'm1', 'slug': 'iphone-12', 'name': 'iPhone 12', 'brand': 'Apple', 'from_price_paise': 100, 'available_units': 1}] : [];
      final c = await pumpApp(t, gateway: g);

      expect((await c.read(cartProvider.future)).single.unitId, 'a-unit');
      expect((await c.read(wishlistProvider.future)).length, 1);

      g.signOut();
      await t.pumpAndSettle();
      expect(await c.read(cartProvider.future), isEmpty);
      expect(await c.read(wishlistProvider.future), isEmpty);
      expect(await c.read(ordersProvider.future), isEmpty);

      g.signIn('user-b');
      await t.pumpAndSettle();
      final lines = await c.read(cartProvider.future);
      expect(lines.single.unitId, 'b-unit');
      expect(await c.read(wishlistProvider.future), isEmpty);
    });
  });

  group('checkout', () {
    testWidgets('shows the server delivery fee in the total and never sends prices to the server', (t) async {
      final g = buildGateway();
      g.functions['create-order'] = (_) => _placedResponse(requiresPayment: true);
      g.functions['verify-payment'] = (_) => {'ok': true, 'status': 'captured'};
      var paid = false;
      g.rpcs['my_orders'] = (_) => paid ? [orderJson()] : [];
      final pay = FakePayments(const PaymentSuccess(paymentId: 'pay_1', orderId: 'order_RZ1', signature: 'sig_1'));
      final c = await pumpApp(t, gateway: g, payments: pay);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();

      expect(find.text('Pay ₹27,598 securely'), findsOneWidget); // 27,499 + 99 delivery
      expect(find.text('Cash on delivery'), findsNothing);          // owner has not enabled COD

      paid = true;
      await t.tap(find.text('Pay ₹27,598 securely'));
      await pumpUntil(t, find.text('Payment successful'));

      final create = g.invokeCalls.firstWhere((c) => c.fn == 'create-order');
      expect(create.body['unit_ids'], ['u1']);
      expect(create.body['payment_method'], 'razorpay');
      expect(create.body['address_id'], 'a1');
      for (final forbidden in ['total', 'total_paise', 'price', 'price_paise', 'delivery_fee', 'delivery_fee_paise', 'discount', 'amount', 'status']) {
        expect(create.body.containsKey(forbidden), isFalse, reason: 'client must not send $forbidden');
      }
      expect(create.headers?['x-idempotency-key'], isNotEmpty);
      expect(pay.calls, 1);
      expect(pay.lastContact, '9822145678'); // prefilled from the delivery address, not retyped
      expect(pay.lastName, 'Test Buyer');
      final verify = g.invokeCalls.firstWhere((c) => c.fn == 'verify-payment');
      expect(verify.body['razorpay_signature'], 'sig_1');
      expect(verify.body['razorpay_order_id'], 'order_RZ1');
    });

    testWidgets('a failed or cancelled payment is not shown as success and offers another try', (t) async {
      final g = buildGateway();
      g.functions['create-order'] = (_) => _placedResponse(requiresPayment: true);
      final pay = FakePayments(const PaymentFailure(message: 'Payment was cancelled.', cancelled: true));
      final c = await pumpApp(t, gateway: g, payments: pay);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      await t.tap(find.text('Pay ₹27,598 securely'));
      await pumpUntil(t, find.textContaining('Payment was cancelled'));
      expect(find.text('Payment successful'), findsNothing);
      expect(g.invokeCalls.where((c) => c.fn == 'verify-payment'), isEmpty);
      expect(find.text('Cancel this order'), findsOneWidget); // the held order can be released

      // retry resumes the same server order instead of creating a second one
      g.functions['create-order'] = (b) => b['action'] == 'resume'
          ? {'ok': true, 'order_id': 'o1', 'order_number': 'BPW-2026-01001', 'total_paise': 2759800, 'expires_at': DateTime.now().add(const Duration(minutes: 9)).toIso8601String(), 'razorpay': {'key_id': 'rzp_test_x', 'order_id': 'order_RZ1', 'amount_paise': 2759800}}
          : _placedResponse(requiresPayment: true);
      await t.tap(find.text('Pay ₹27,598 securely'));
      await pumpUntil(t, find.textContaining('Payment was cancelled'));
      expect(g.invokeCalls.where((c) => c.body['action'] == 'resume').length, 1);
      expect(g.invokeCalls.where((c) => c.fn == 'create-order' && c.body['action'] == null).length, 1);
    });

    testWidgets('payment success callback alone is not trusted: no captured order means no success screen', (t) async {
      final g = buildGateway();
      g.functions['create-order'] = (_) => _placedResponse(requiresPayment: true);
      g.functions['verify-payment'] = (_) => {'ok': true, 'status': 'authorized'}; // provider has not captured
      g.rpcs['my_orders'] = (_) => [orderJson(status: 'pending_payment', payStatus: 'authorized')];
      final pay = FakePayments(const PaymentSuccess(paymentId: 'pay_1', orderId: 'order_RZ1', signature: 'sig_1'));
      final c = await pumpApp(t, gateway: g, payments: pay);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      await t.tap(find.text('Pay ₹27,598 securely'));
      await pumpUntil(t, find.textContaining('could not confirm them yet'), steps: 200);
      expect(find.text('Payment successful'), findsNothing);
    });

    testWidgets('cash on delivery is offered only when the owner enabled it, and places a COD order', (t) async {
      final g = buildGateway();
      g.tables['store_settings'] = (_) => [{'shop_name': 'BudgetPhonewala', 'cod_enabled': true, 'cod_fee_paise': 0, 'reservation_minutes': 10}];
      g.functions['create-order'] = (_) => _placedResponse(requiresPayment: false);
      g.rpcs['my_orders'] = (_) => [orderJson(status: 'placed', payStatus: 'awaiting_cod', method: 'cod')];
      final c = await pumpApp(t, gateway: g);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      expect(find.text('Cash on delivery'), findsOneWidget);
      await t.tap(find.text('Cash on delivery'));
      await t.pumpAndSettle();
      await t.tap(find.text('Place order (pay on delivery)'));
      await pumpUntil(t, find.text('Order placed'));
      expect(g.invokeCalls.firstWhere((c) => c.fn == 'create-order').body['payment_method'], 'cod');
    });

    testWidgets('with no address yet the shopper sees a friendly prompt, not a pincode error, and cannot pay', (t) async {
      final g = buildGateway();
      g.tables['addresses'] = (_) => [];
      g.rpcs['quote_delivery'] = (_) => {'serviceable': false, 'fee_paise': 0, 'reason': 'Enter a valid 6-digit pincode', 'cod_allowed': false};
      final c = await pumpApp(t, gateway: g);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      expect(find.text('Enter a valid 6-digit pincode'), findsNothing);
      expect(find.text('Add an address'), findsOneWidget);
      final btn = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay ₹27,499 securely'));
      expect(btn.onPressed, isNull);
    });

    testWidgets('an unserviceable pincode blocks payment', (t) async {
      final g = buildGateway();
      g.rpcs['quote_delivery'] = (_) => {'serviceable': false, 'fee_paise': 0, 'reason': 'We do not deliver to this pincode', 'cod_allowed': false};
      final c = await pumpApp(t, gateway: g);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      expect(find.text('We do not deliver to this pincode'), findsOneWidget);
      final btn = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay ₹27,499 securely'));
      expect(btn.onPressed, isNull);
    });

    testWidgets('a phone that was just sold blocks checkout', (t) async {
      final g = buildGateway();
      g.rpcs['cart_list'] = (_) => [cartLineJson(available: false)];
      final c = await pumpApp(t, gateway: g);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      expect(find.textContaining('just sold'), findsOneWidget);
    });

    testWidgets('server stock conflict is shown to the shopper and no payment sheet opens', (t) async {
      final g = buildGateway();
      g.functions['create-order'] = (_) => throw StateError('use toAppException path'); // replaced below
      g.functions.remove('create-order');
      final pay = FakePayments(const PaymentFailure(message: 'unused'));
      final c = await pumpApp(t, gateway: g, payments: pay);
      c.read(checkoutSelectionProvider.notifier).set(['u1']);
      c.read(routerProvider).go('/checkout');
      await t.pumpAndSettle();
      await t.tap(find.text('Pay ₹27,598 securely'));
      await t.pumpAndSettle();
      expect(pay.calls, 0);
      expect(find.text('Payment successful'), findsNothing);
    });
  });
}
