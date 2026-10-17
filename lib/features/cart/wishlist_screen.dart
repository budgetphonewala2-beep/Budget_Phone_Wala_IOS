import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/account.dart';
import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';
import '../catalogue/model_grid.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  CatalogModel _asModel(WishlistEntry e) => CatalogModel(
        id: e.modelId, slug: e.slug, name: e.name, brand: e.brand, fromPricePaise: e.fromPricePaise, maxMrpPaise: 0,
        availableUnits: e.availableUnits, network: '', storages: const [], colors: const [], grades: const [], maxBattery: 0,
        warrantyMonths: 0, primaryImage: e.image,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(wishlistProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved phones')),
      body: AsyncBody<List<WishlistEntry>>(
        value: w,
        onRetry: () => ref.invalidate(wishlistProvider),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.favorite_border, title: 'No saved phones yet', body: 'Tap the heart on any phone to save it here.', actionLabel: 'Browse phones', onAction: () => context.go('/'))
            : CustomScrollView(slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverModelGrid(items: items.map(_asModel).toList()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ]),
      ),
    );
  }
}
