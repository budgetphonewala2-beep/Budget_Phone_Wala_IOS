import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/actions.dart';
import '../../core/widgets/widgets.dart';
import 'model_grid.dart';

const _fallbackBanners = [
  HomeBanner('Premium phones at smart prices', '1 year warranty, quality checked, easy exchange'),
  HomeBanner('Sell your phone in 2 minutes', 'Get an instant estimate and a final offer on WhatsApp'),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrivals = ref.watch(newArrivalsProvider);
    final banners = ref.watch(bannersProvider).value ?? const <HomeBanner>[];
    final brands = ref.watch(brandsProvider).value ?? const <String>[];
    final settings = ref.watch(settingsProvider).value ?? const StoreSettings();
    final profile = ref.watch(profileProvider).value;
    final first = (profile?.fullName ?? '').trim().split(' ').first;
    final wishCount = ref.watch(wishlistProvider).value?.length ?? 0;
    final cartCount = ref.watch(cartCountProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(newArrivalsProvider);
          ref.invalidate(bannersProvider);
          ref.invalidate(brandsProvider);
          ref.invalidate(settingsProvider);
          await ref.read(newArrivalsProvider.future).catchError((_) => const CatalogPage(total: 0, items: []));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(firstName: first, wishCount: wishCount, cartCount: cartCount)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SearchEntry())),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _BannerPager(banners: banners.isEmpty ? _fallbackBanners : banners))),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _QuickActions(settings: settings))),
            if (brands.isNotEmpty) ...[
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: SectionHeader('Shop by brand'))),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: brands.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ActionChip(label: Text(brands[i]), onPressed: () => context.go('/search?brand=${Uri.encodeComponent(brands[i])}')),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: SectionHeader('Shop by budget'))),
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _BudgetTiles())),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TrustStrip())),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: SectionHeader('New arrivals', action: 'See all', onAction: () => context.go('/search')))),
            ...arrivals.when(
              data: (p) => p.items.isEmpty
                  ? [const SliverToBoxAdapter(child: SizedBox(height: 280, child: EmptyState(icon: Icons.smartphone_outlined, title: 'New stock coming soon', body: 'We are adding phones. Message us on WhatsApp for what you need.')))]
                  : [SliverModelGrid(items: p.items)],
              loading: () => [const SliverCardSkeletons()],
              error: (e, _) => [SliverToBoxAdapter(child: SizedBox(height: 320, child: ErrorState(error: e, onRetry: () => ref.invalidate(newArrivalsProvider))))],
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 96), child: _StoreCard(settings: settings))),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.wishCount, required this.cartCount});
  final String firstName;
  final int wishCount, cartCount;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final big = MediaQuery.textScalerOf(context).scale(10) > 12.5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(children: [
        const LogoBadge(size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(firstName.isNotEmpty ? 'Hi, $firstName' : 'BudgetPhonewala', maxLines: 1, overflow: TextOverflow.ellipsis, style: big ? t.titleSmall : t.titleLarge),
            if (!big) Text('Budget Aapka, Phone Hamara', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        IconButton(
          tooltip: 'Wishlist, $wishCount saved',
          onPressed: () => context.push('/wishlist'),
          icon: Badge(isLabelVisible: wishCount > 0, label: Text('$wishCount'), child: const Icon(Icons.favorite_border)),
        ),
        IconButton(
          tooltip: 'Cart, $cartCount items',
          onPressed: () => context.push('/cart'),
          icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: const Icon(Icons.shopping_cart_outlined)),
        ),
      ]),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surface,
      shape: StadiumBorder(side: BorderSide(color: s.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.go('/search'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.search, color: s.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text('Search phones', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: s.onSurfaceVariant))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BannerPager extends StatefulWidget {
  const _BannerPager({required this.banners});
  final List<HomeBanner> banners;
  @override
  State<_BannerPager> createState() => _BannerPagerState();
}

class _BannerPagerState extends State<_BannerPager> {
  final _c = PageController();
  Timer? _timer;
  int _i = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    // auto-advance every 5 s unless the system asks for reduced animations
    if (widget.banners.length > 1 && !MediaQuery.of(context).disableAnimations) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_c.hasClients) return;
        _c.animateToPage((_i + 1) % widget.banners.length, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      SizedBox(
        height: 164,
        child: PageView.builder(
          controller: _c,
          itemCount: widget.banners.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final b = widget.banners[i];
            return Padding(
              padding: const EdgeInsets.only(right: 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: s.primary, borderRadius: AppShapes.cardBorder),
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleLarge?.copyWith(color: s.onPrimary)),
                      const SizedBox(height: 6),
                      Text(b.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: s.onPrimary.withValues(alpha: 0.9))),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  const LogoBadge(size: 60),
                ]),
              ),
            );
          },
        ),
      ),
      if (widget.banners.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < widget.banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6, width: _i == i ? 18 : 6,
                decoration: ShapeDecoration(shape: const StadiumBorder(), color: _i == i ? s.primary : s.outlineVariant),
              ),
          ]),
        ),
    ]);
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.settings});
  final StoreSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true, label: label,
            child: InkWell(
              borderRadius: AppShapes.cardBorder,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer), child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(label, textScaler: TextScaler.noScaling, maxLines: 1, style: Theme.of(context).textTheme.labelMedium),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      item(Icons.sell_outlined, 'Sell phone', () => context.go('/sell')),
      item(Icons.swap_horiz, 'Exchange', () => context.go('/sell')),
      item(Icons.storefront_outlined, 'Visit store', () => openMaps(context, settings)),
      item(Icons.call_outlined, 'Call us', () => callShop(context, settings)),
    ]);
  }
}

class _BudgetTiles extends StatelessWidget {
  const _BudgetTiles();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(children: [
      for (final (v, label) in const [(10000, '10k'), (15000, '15k'), (20000, '20k'), (30000, '30k')])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Card(
              child: InkWell(
                borderRadius: AppShapes.cardBorder,
                onTap: () => context.go('/search?max=$v'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(children: [
                    Text('Under', textScaler: TextScaler.noScaling, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant)),
                    Text('₹$label', maxLines: 1, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: s.primary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget item(IconData i, String l) => Expanded(
          child: Column(children: [
            Icon(i, color: s.tertiary),
            const SizedBox(height: 4),
            Text(l, textScaler: TextScaler.noScaling, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          item(Icons.verified_outlined, 'Quality\nchecked'),
          item(Icons.shield_outlined, 'Warranty\nincluded'),
          item(Icons.swap_horiz, 'Easy\nexchange'),
          item(Icons.lock_outline, 'Secure\npayment'),
        ]),
      ),
    );
  }
}

class _StoreCard extends ConsumerWidget {
  const _StoreCard({required this.settings});
  final StoreSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(settings.shopName, style: t.titleMedium),
          if (settings.address.isNotEmpty) Text(settings.address, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppButton('Directions', () => openMaps(context, settings), style: BtnStyle.outlined, icon: Icons.place_outlined)),
            const SizedBox(width: 8),
            Expanded(child: AppButton('Call', () => callShop(context, settings), style: BtnStyle.outlined, icon: Icons.call_outlined)),
          ]),
        ]),
      ),
    );
  }
}
