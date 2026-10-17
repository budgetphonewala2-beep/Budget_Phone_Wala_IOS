import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/account.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/guest_prompt.dart';

Tone toneFor(String status) => switch (status) {
      'pending_payment' || 'delivery_failed' => Tone.warning,
      'delivered' || 'picked_up' => Tone.success,
      'cancelled' || 'returned' => Tone.neutral,
      _ => Tone.brand,
    };

String holdLeft(Order o, DateTime now) {
  final s = (o.expiresAt!.difference(now).inSeconds).clamp(0, 86400);
  return 'Pay within ${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  int _tab = 0;
  Timer? _tick, _poll;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => mounted ? setState(() => _now = DateTime.now()) : null);
    // refresh every 30 s while this tab is open
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ref.read(isSignedInProvider)) {
        ref.invalidate(ordersProvider);
        ref.invalidate(enquiriesProvider);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(ordersProvider);
    ref.invalidate(enquiriesProvider);
    await ref.read(ordersProvider.future).catchError((_) => <Order>[]);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    final t = Theme.of(context).textTheme;
    if (!signedIn) {
      return const SafeArea(child: GuestPrompt(title: 'Sign in to see your orders', body: 'Your orders, payments and enquiries appear here once you sign in.', icon: Icons.receipt_long_outlined));
    }
    final orders = ref.watch(ordersProvider);
    final enquiries = ref.watch(enquiriesProvider);
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text('My orders', style: t.headlineMedium)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text('Purchases (${orders.value?.length ?? 0})')),
                ButtonSegment(value: 1, label: Text('Enquiries (${enquiries.value?.length ?? 0})')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _tab == 0
                ? AsyncBody<List<Order>>(
                    value: orders,
                    onRetry: () => ref.invalidate(ordersProvider),
                    data: (list) => list.isEmpty
                        ? ListView(children: [SizedBox(height: 360, child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet', body: 'Orders you place appear here with live status.', actionLabel: 'Browse phones', onAction: () => context.go('/')))])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _OrderCard(order: list[i], now: _now),
                          ),
                  )
                : AsyncBody<List<SellEnquiry>>(
                    value: enquiries,
                    onRetry: () => ref.invalidate(enquiriesProvider),
                    data: (list) => list.isEmpty
                        ? ListView(children: [SizedBox(height: 360, child: EmptyState(icon: Icons.sell_outlined, title: 'No enquiries', body: 'Want to sell or exchange your old phone? Send us the details.', actionLabel: 'Sell or exchange', onAction: () => context.go('/sell')))])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _EnquiryCard(e: list[i]),
                          ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.now});
  final Order order;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final payable = order.canPay(now);
    final expired = order.status == 'pending_payment' && !payable;
    return Card(
      child: InkWell(
        borderRadius: AppShapes.cardBorder,
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.number, style: t.titleMedium),
                Text(formatDateTime(order.createdAt), style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
              ])),
              StatusPill(expired ? 'Payment expired' : orderStatusLabel(order.status, pickup: order.isPickup), tone: expired ? Tone.neutral : toneFor(order.status)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 48.0 + (order.items.take(3).length - 1).clamp(0, 2) * 38,
                height: 48,
                child: Stack(children: [
                  for (var i = 0; i < order.items.take(3).length; i++)
                    Positioned(left: i * 38.0, child: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: s.surface, border: Border.all(color: s.surface, width: 2)), child: ClipOval(child: RemoteImage(order.items[i].image)))),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.items.isEmpty ? '' : order.items.first.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                if (order.items.length > 1) Text('+${order.items.length - 1} more', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                Text(order.isCod ? 'Cash on delivery' : 'Paid online', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
              ])),
              Text(rupees(order.totalPaise), style: t.titleMedium),
            ]),
            if (payable) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(holdLeft(order, now), style: t.labelMedium?.copyWith(color: s.error))),
                AppButton('Pay now', () => context.push('/orders/${order.id}'), expand: false),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _EnquiryCard extends StatelessWidget {
  const _EnquiryCard({required this.e});
  final SellEnquiry e;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.number, style: t.titleMedium),
              Text(formatDateTime(e.createdAt), style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
            ])),
            StatusPill(e.status.replaceAll('_', ' '), tone: Tone.brand),
          ]),
          const SizedBox(height: 8),
          Text('${e.brand} ${e.model}', style: t.titleSmall),
          Text('${e.type == 'exchange' ? 'Exchange' : 'Sell'}${e.expectedPaise != null ? ' | You asked ${rupees(e.expectedPaise!)}' : ''}', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
          if (e.offerPaise != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Our offer: ${rupees(e.offerPaise!)}', style: t.titleSmall?.copyWith(color: s.tertiary))),
          if (e.notes.isNotEmpty) Text(e.notes, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
