import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: AsyncBody<List<CartLine>>(
        value: cart,
        onRetry: () => ref.invalidate(cartProvider),
        data: (lines) {
          if (lines.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined, title: 'Your cart is empty',
              body: 'Every phone is a single unit, so someone else may buy it first. Add what you like.',
              actionLabel: 'Browse phones', onAction: () => context.go('/'),
            );
          }
          final buyable = lines.where((l) => l.available).toList();
          final unavailable = lines.length - buyable.length;
          final s = Theme.of(context).colorScheme;
          final t = Theme.of(context).textTheme;
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (unavailable > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: s.errorContainer, borderRadius: AppShapes.controlBorder),
                    child: Text('$unavailable phone${unavailable > 1 ? 's were' : ' was'} just sold. Remove ${unavailable > 1 ? 'them' : 'it'} to continue.', style: t.bodyMedium?.copyWith(color: s.onErrorContainer)),
                  ),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: AppShapes.cardBorder,
                        onTap: () => context.push('/model/${l.modelSlug}?unit=${l.unitId}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            ClipRRect(borderRadius: AppShapes.controlBorder, child: SizedBox(width: 76, height: 76, child: RemoteImage(l.image, semanticLabel: l.title))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                                const SizedBox(height: 4),
                                l.available ? Text(rupees(l.pricePaise), style: t.titleMedium) : const StatusPill('Sold out', tone: Tone.danger),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Remove ${l.title} from cart', icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await ref.read(cartRepoProvider).remove(l.unitId);
                                  ref.invalidate(cartProvider);
                                } catch (e) {
                                  if (context.mounted) showSnack(context, toAppException(e).message);
                                }
                              },
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            Material(
              elevation: 8, color: s.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Subtotal (${buyable.length} item${buyable.length == 1 ? '' : 's'})', style: t.bodyLarge)),
                      Text(rupees(buyable.fold<int>(0, (a, b) => a + b.pricePaise)), style: t.titleMedium),
                    ]),
                    Text('Delivery and coupons are applied at checkout', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    AppButton('Checkout', unavailable > 0 || buyable.isEmpty ? null : () {
                      ref.read(checkoutSelectionProvider.notifier).set(buyable.map((e) => e.unitId).toList());
                      context.push('/checkout');
                    }),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
