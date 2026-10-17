import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/services.dart';
import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/actions.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';
import 'orders_screen.dart' show holdLeft, toneFor;

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() => _now = DateTime.now()) : null);
    Future.microtask(() => ref.invalidate(ordersProvider));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _payNow(Order o) async {
    final profile = ref.read(profileProvider).value ?? const Profile();
    setState(() { _busy = true; _msg = null; });
    try {
      final repo = ref.read(orderRepoProvider);
      final placed = await repo.resumePayment(o.id);
      final outcome = await ref.read(paymentLauncherProvider).pay(
            keyId: placed.razorpayKey!, razorpayOrderId: placed.razorpayOrderId!, amountPaise: placed.totalPaise,
            name: o.name, description: 'Order ${placed.orderNumber}', contact: o.phone, email: profile.email.isEmpty ? null : profile.email,
          );
      switch (outcome) {
        case PaymentFailure f:
          _msg = f.cancelled ? 'Payment was cancelled. You can try again while the phone is held.' : '${f.message} You can try again.';
        case PaymentSuccess ok:
          await repo.verifyPayment(razorpayOrderId: ok.orderId, paymentId: ok.paymentId, signature: ok.signature).catchError((_) => '');
          for (var i = 0; i < 3; i++) {
            final list = await repo.orders().catchError((_) => <Order>[]);
            final cur = list.where((e) => e.id == o.id).firstOrNull;
            if (cur != null && cur.isPaidOnline) break;
            await repo.syncPayment(placed.razorpayOrderId!).catchError((_) => '');
            await Future<void>.delayed(const Duration(seconds: 2));
          }
      }
    } catch (e) {
      _msg = toAppException(e).message;
    }
    ref.invalidate(ordersProvider);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel(Order o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(o.isPaidOnline ? 'Your payment will be refunded after our team approves the cancellation.' : 'The phone will be released for other buyers.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep order')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel order'))],
      ),
    );
    if (ok != true) return;
    setState(() { _busy = true; _msg = null; });
    try {
      await ref.read(orderRepoProvider).cancel(o.id, reason: 'Cancelled by customer');
    } catch (e) {
      _msg = toAppException(e).message;
    }
    ref.invalidate(ordersProvider);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final settings = ref.watch(settingsProvider).value ?? const StoreSettings();
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: AsyncBody<List<Order>>(
        value: orders,
        onRetry: () => ref.invalidate(ordersProvider),
        data: (list) {
          final o = list.where((e) => e.id == widget.orderId).firstOrNull;
          if (o == null) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found', body: 'It may still be loading. Pull to refresh on the Orders tab.');
          final payable = o.canPay(_now);
          final expired = o.status == 'pending_payment' && !payable;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (_msg != null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.errorContainer, borderRadius: AppShapes.controlBorder), child: Text(_msg!, style: t.bodyMedium?.copyWith(color: s.onErrorContainer))),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.number, style: t.titleLarge),
                      Text(formatDateTime(o.createdAt), style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    ])),
                    StatusPill(expired ? 'Payment expired' : orderStatusLabel(o.status, pickup: o.isPickup), tone: expired ? Tone.neutral : toneFor(o.status)),
                  ]),
                  if (payable) ...[
                    const SizedBox(height: 12),
                    Text(holdLeft(o, _now), style: t.labelLarge?.copyWith(color: s.error)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(flex: 2, child: AppButton('Pay ${rupees(o.totalPaise)}', _busy ? null : () => _payNow(o), loading: _busy)),
                      const SizedBox(width: 10),
                      Expanded(child: AppButton('Cancel', _busy ? null : () => _cancel(o), style: BtnStyle.outlined)),
                    ]),
                  ] else if (o.canCancel && !_busy) ...[
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _cancel(o), child: const Text('Cancel order'))),
                  ],
                  if (o.paymentStatus == 'refund_pending' || o.refunds.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_refundText(o), style: t.bodyMedium),
                  ),
                  if (o.status == 'cancelled' && (o.cancelReason ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Reason: ${o.cancelReason}', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant))),
                ]),
              ),
            ),
            if (o.status != 'cancelled' && o.status != 'pending_payment') ...[
              const SizedBox(height: 16),
              _Section('Progress', child: _Timeline(order: o)),
            ],
            const SizedBox(height: 16),
            _Section('Items', child: Column(children: [
              for (final i in o.items) _ItemRow(order: o, item: i),
            ])),
            const SizedBox(height: 16),
            _Section('Payment summary', child: Column(children: [
              _Line('Subtotal', rupees(o.subtotalPaise)),
              if (o.discountPaise > 0) _Line('Discount', '-${rupees(o.discountPaise)}'),
              _Line('Delivery', o.deliveryFeePaise == 0 ? 'Free' : rupees(o.deliveryFeePaise)),
              if (o.codFeePaise > 0) _Line('Cash on delivery fee', rupees(o.codFeePaise)),
              _Line('Payment', o.isCod ? 'Cash on delivery (${o.paymentStatus == 'cod_collected' ? 'collected' : 'pay on delivery'})' : 'Online'),
              const Divider(height: 20),
              Row(children: [Expanded(child: Text('Total', style: t.titleMedium)), Text(rupees(o.totalPaise), style: t.titleMedium)]),
            ])),
            const SizedBox(height: 16),
            _Section(o.isPickup ? 'Pickup' : 'Delivery address', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.name, style: t.titleSmall),
              Text('+91 ${o.phone}', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(o.isPickup ? 'Collect from ${settings.shopName}${settings.address.isEmpty ? '' : ', ${settings.address}'}' : [(o.address['line1'] ?? '').toString(), (o.address['line2'] ?? '').toString(), (o.address['city'] ?? '').toString(), (o.address['pincode'] ?? '').toString()].where((e) => e.isNotEmpty).join(', '), style: t.bodyMedium),
              if (!o.isPickup && (o.fulfillmentInfo['courier_name'] ?? '').toString().isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Courier: ${o.fulfillmentInfo['courier_name']}${(o.fulfillmentInfo['tracking_reference'] ?? '').toString().isEmpty ? '' : ' | Tracking: ${o.fulfillmentInfo['tracking_reference']}'}', style: t.bodyMedium),
              ),
            ])),
            const SizedBox(height: 16),
            Row(children: [
              if (o.isPaidOnline || o.paymentStatus == 'cod_collected') ...[
                Expanded(child: AppButton('Share receipt', () => SharePlus.instance.share(ShareParams(text: _receipt(o, settings.shopName))), style: BtnStyle.outlined, icon: Icons.share_outlined)),
                const SizedBox(width: 10),
              ],
              Expanded(child: AppButton('Need help?', () => openWhatsApp(context, settings, 'Hello! I need help with order ${o.number} (${rupees(o.totalPaise)}, ${orderStatusLabel(o.status, pickup: o.isPickup)}).'), style: BtnStyle.tonal, icon: Icons.chat_outlined)),
            ]),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }

  String _refundText(Order o) {
    if (o.refunds.isEmpty) return 'A refund is being arranged for this order.';
    final r = o.refunds.first;
    final st = (r['status'] ?? '').toString();
    final amt = rupees((r['amount_paise'] as num?) ?? 0);
    return switch (st) {
      'processed' => 'Refund of $amt has been processed to your original payment method.',
      'failed' => 'Refund of $amt could not be completed yet. Our team is looking into it.',
      _ => 'Refund of $amt is in progress.',
    };
  }

  String _receipt(Order o, String shop) => [
        '$shop - Order receipt', 'Order ${o.number}', 'Date: ${formatDateTime(o.createdAt)}',
        'Status: ${orderStatusLabel(o.status, pickup: o.isPickup)}', '',
        for (final i in o.items) '${i.title}: ${rupees(i.pricePaise)}', '',
        'Subtotal: ${rupees(o.subtotalPaise)}', if (o.discountPaise > 0) 'Discount: -${rupees(o.discountPaise)}',
        if (o.deliveryFeePaise > 0) 'Delivery: ${rupees(o.deliveryFeePaise)}', 'Total: ${rupees(o.totalPaise)}',
      ].join('\n');
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: child))),
      ]);
}

class _Line extends StatelessWidget {
  const _Line(this.l, this.v);
  final String l, v;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(l, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))), Flexible(child: Text(v, textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleSmall))]),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final Order order;
  @override
  Widget build(BuildContext context) {
    final steps = orderTimeline(pickup: order.isPickup, cod: order.isCod);
    var reached = -1;
    for (var i = 0; i < steps.length; i++) {
      if (order.history.any((h) => h.status == steps[i]) || order.status == steps[i]) reached = i;
    }
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(i <= reached ? Icons.check_circle_outline : Icons.radio_button_unchecked, color: i <= reached ? s.tertiary : s.outline),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(orderStatusLabel(steps[i], pickup: order.isPickup), style: t.titleSmall?.copyWith(color: i <= reached ? s.onSurface : s.onSurfaceVariant)),
              Builder(builder: (_) {
                final at = order.history.where((h) => h.status == steps[i]).lastOrNull?.at;
                return at == null ? const SizedBox.shrink() : Text(formatDateTime(at), style: t.bodySmall?.copyWith(color: s.onSurfaceVariant));
              }),
            ])),
          ]),
        ),
    ]);
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.order, required this.item});
  final Order order;
  final OrderItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final underWarranty = order.isDelivered && item.warrantyEnd != null && !item.warrantyEnd!.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(borderRadius: AppShapes.controlBorder, child: SizedBox(width: 56, height: 56, child: RemoteImage(item.image))),
          const SizedBox(width: 12),
          Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall)),
          const SizedBox(width: 8),
          Text(rupees(item.pricePaise), style: t.titleSmall),
        ]),
        if (item.warrantyEnd != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Warranty until ${formatDate(item.warrantyEnd)}', style: t.bodySmall?.copyWith(color: s.tertiary)),
        ),
        if (order.isDelivered) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, children: [
            if (underWarranty) OutlinedButton(onPressed: () => _ask(context, ref, true), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), child: const Text('Warranty claim')),
            OutlinedButton(onPressed: () => _ask(context, ref, false), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), child: const Text('Request return')),
          ]),
        ),
      ]),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref, bool claim) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(claim ? 'Warranty claim' : 'Request a return'),
        content: TextField(controller: c, maxLines: 3, autofocus: true, decoration: InputDecoration(labelText: claim ? 'Describe the problem' : 'Why do you want to return it?')),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')), TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Submit'))],
      ),
    );
    if (text == null || !context.mounted) return;
    if (text.length < 5) {
      showSnack(context, 'Please write a few more words.');
      return;
    }
    try {
      final repo = ref.read(warrantyRepoProvider);
      final no = claim ? await repo.submitClaim(item.id, text) : await repo.submitReturn(item.id, text);
      ref.invalidate(claimsProvider);
      ref.invalidate(returnsProvider);
      if (context.mounted) showSnack(context, 'Submitted. Reference $no');
    } catch (e) {
      if (context.mounted) showSnack(context, toAppException(e).message);
    }
  }
}
