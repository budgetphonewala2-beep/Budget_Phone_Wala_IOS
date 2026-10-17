import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/account.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';

class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key, required this.orderNumber, required this.cod, required this.refundPending});
  final String orderNumber;
  final bool cod, refundPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final Order? order = (ref.watch(ordersProvider).value ?? const <Order>[]).where((o) => o.number == orderNumber).firstOrNull;
    final title = refundPending ? 'Phone no longer available' : (cod ? 'Order placed' : 'Payment successful');
    final body = refundPending
        ? 'Your payment arrived after this phone was sold to another buyer. We will refund the full amount to your original payment method.'
        : cod
            ? 'Thank you! Please keep the cash ready. We will confirm your order and share delivery updates.'
            : (order?.isPickup == true ? 'We have your order. We will message you when your phone is ready for pickup at the store.' : 'Thank you! We will confirm your order and share delivery updates.');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => context.go('/'),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(refundPending ? Icons.schedule : Icons.check_circle_outline, size: 88, color: refundPending ? s.error : s.tertiary),
                const SizedBox(height: 20),
                Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(orderNumber, style: t.titleLarge?.copyWith(color: s.primary)),
                const SizedBox(height: 12),
                Text(body, style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant), textAlign: TextAlign.center),
                if (order != null && !refundPending) Padding(padding: const EdgeInsets.only(top: 16), child: Text(cod ? 'Amount to pay on delivery: ${rupees(order.totalPaise)}' : 'Amount paid: ${rupees(order.totalPaise)}', style: t.titleMedium)),
                const SizedBox(height: 32),
                AppButton('View order', () => order == null ? context.go('/orders') : context.go('/orders/${order.id}')),
                const SizedBox(height: 10),
                AppButton('Continue shopping', () => context.go('/'), style: BtnStyle.outlined),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
