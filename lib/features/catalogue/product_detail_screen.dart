import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/actions.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.slug, this.unitId});
  final String slug;
  final String? unitId;
  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _unitId;
  final _page = PageController();
  int _img = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  CatalogUnit? _selected(ModelDetail d) {
    if (d.units.isEmpty) return null;
    final id = _unitId ?? widget.unitId;
    return d.units.firstWhere((u) => u.id == id, orElse: () => d.units.first);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(modelDetailProvider(widget.slug));
    final settings = ref.watch(settingsProvider).value ?? const StoreSettings();
    final cartIds = (ref.watch(cartProvider).value ?? const []).map((e) => e.unitId).toSet();
    final wished = detail.value == null ? false : ref.watch(wishlistIdsProvider).contains(detail.value!.model.id);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.model.brand ?? 'Phone'),
        actions: [
          if (detail.value != null) ...[
            IconButton(
              tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
              icon: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? Theme.of(context).colorScheme.primary : null),
              onPressed: () => toggleWishlist(context, ref, detail.value!.model.id),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                final m = detail.value!.model;
                SharePlus.instance.share(ShareParams(text: '${m.title} from ${rupees(m.fromPricePaise)} - BudgetPhonewala: Budget Aapka, Phone Hamara'));
              },
            ),
          ],
          IconButton(
            tooltip: 'Cart, $cartCount items',
            icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: const Icon(Icons.shopping_cart_outlined)),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: AsyncBody<ModelDetail?>(
        value: detail,
        onRetry: () => ref.invalidate(modelDetailProvider(widget.slug)),
        data: (d) {
          if (d == null) {
            return const EmptyState(icon: Icons.search_off, title: 'Phone not found', body: 'This listing is no longer available.');
          }
          return _Body(
            detail: d, unit: _selected(d), settings: settings, cartIds: cartIds, pageController: _page, imageIndex: _img,
            onImage: (i) => setState(() => _img = i),
            onSelectUnit: (u) => setState(() { _unitId = u.id; _img = 0; if (_page.hasClients) _page.jumpToPage(0); }),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.unit, required this.settings, required this.cartIds, required this.pageController, required this.imageIndex, required this.onImage, required this.onSelectUnit});
  final ModelDetail detail;
  final CatalogUnit? unit;
  final StoreSettings settings;
  final Set<String> cartIds;
  final PageController pageController;
  final int imageIndex;
  final ValueChanged<int> onImage;
  final ValueChanged<CatalogUnit> onSelectUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final m = detail.model;
    final u = unit;
    final images = [if (u != null) ...u.images, ...detail.images];
    final unavailable = u == null;
    final inCart = u != null && cartIds.contains(u.id);

    return Column(children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: Stack(children: [
              PageView.builder(
                controller: pageController, onPageChanged: onImage,
                itemCount: images.isEmpty ? 1 : images.length,
                itemBuilder: (_, i) => RemoteImage(images.isEmpty ? null : images[i], semanticLabel: m.title),
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 10, left: 0, right: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < images.length; i++)
                      Container(margin: const EdgeInsets.symmetric(horizontal: 3), height: 6, width: imageIndex == i ? 18 : 6, decoration: ShapeDecoration(shape: const StadiumBorder(), color: imageIndex == i ? Colors.white : Colors.white54)),
                  ]),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (u != null) StatusPill('Grade ${u.grade}', tone: Tone.brand),
                StatusPill(m.network),
                if (unavailable) const StatusPill('Sold out', tone: Tone.danger),
              ]),
              const SizedBox(height: 10),
              Text(m.title, style: t.headlineSmall),
              const SizedBox(height: 8),
              if (u != null) ...[
                PriceRow(pricePaise: u.pricePaise, mrpPaise: u.mrpPaise, big: true),
                if (u.discountPct > 0) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('You save ${rupees(u.mrpPaise - u.pricePaise)} (${u.discountPct}% off MRP)', style: t.labelLarge?.copyWith(color: s.tertiary)),
                ),
              ],
              if (detail.units.length > 1) ...[
                const SizedBox(height: 20),
                const SectionHeader('Choose your phone'),
                const SizedBox(height: 8),
                for (final x in detail.units) _UnitTile(unit: x, selected: x.id == u?.id, onTap: () => onSelectUnit(x)),
              ],
              if (u != null) ...[
                const SizedBox(height: 20),
                const SectionHeader('Specifications'),
                const SizedBox(height: 8),
                _SpecGrid(specs: [
                  (Icons.memory, 'RAM', '${u.ramGb} GB'),
                  (Icons.storage_outlined, 'Storage', '${u.storageGb} GB'),
                  (Icons.battery_charging_full_outlined, 'Battery health', '${u.battery}%'),
                  (Icons.signal_cellular_alt, 'Network', m.network),
                  (Icons.palette_outlined, 'Colour', u.color.isEmpty ? 'As shown' : u.color),
                  (Icons.verified_outlined, 'Warranty', '${u.warrantyMonths} months'),
                ]),
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: u.battery / 100, minHeight: 6, color: s.tertiary, backgroundColor: s.surfaceContainerHighest)),
                const SizedBox(height: 24),
                const SectionHeader('Condition and inclusions'),
                const SizedBox(height: 8),
                if (u.defects.isNotEmpty) Text(u.defects, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
                if (u.inspectionNotes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(u.inspectionNotes, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))),
                const SizedBox(height: 8),
                _CheckRow(u.hasBill, 'Original bill'),
                _CheckRow(u.hasBox, 'Original box'),
                if (u.accessories.isNotEmpty) _CheckRow(true, u.accessories),
                const _CheckRow(true, 'IMEI verified at the store'),
              ],
              if (m.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(m.description, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              ],
              const SizedBox(height: 20),
              AppButton('Ask about this phone on WhatsApp', () => openWhatsApp(context, settings, 'Hello! I want this phone: ${m.title}${u == null ? '' : ' at ${rupees(u.pricePaise)}'}. Is it still available?'), style: BtnStyle.outlined, icon: Icons.chat_outlined),
              const SizedBox(height: 28),
              _Similar(brand: m.brand, excludeId: m.id),
            ]),
          ),
        ]),
      ),
      Material(
        elevation: 8, color: s.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: unavailable
                ? const AppButton('Sold out', null)
                : Row(children: [
                    Expanded(
                      child: inCart
                          ? AppButton('Go to cart', () => context.push('/cart'), style: BtnStyle.outlined, icon: Icons.shopping_cart_outlined)
                          : AppButton('Add to cart', () async {
                              final ok = await addUnitToCart(context, ref, u.id);
                              if (ok && context.mounted) showSnack(context, 'Added to cart');
                            }, style: BtnStyle.outlined),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton('Buy now', () async {
                        // Buy now: the phone goes into the cart (holds nothing yet), checkout is limited to this one unit
                        if (!await addUnitToCart(context, ref, u.id) || !context.mounted) return;
                        ref.read(checkoutSelectionProvider.notifier).set([u.id]);
                        context.push('/checkout');
                      }),
                    ),
                  ]),
          ),
        ),
      ),
    ]);
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.unit, required this.selected, required this.onTap});
  final CatalogUnit unit;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? s.primaryContainer : s.surface,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder, side: BorderSide(color: selected ? s.primary : s.outlineVariant, width: selected ? 2 : 1)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${unit.storageGb}GB${unit.color.isEmpty ? '' : ' • ${unit.color}'}', style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text('Grade ${unit.grade} • Battery ${unit.battery}% • ${unit.warrantyMonths} mo warranty', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                ]),
              ),
              Text(rupees(unit.pricePaise), style: t.titleMedium),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SpecGrid extends StatelessWidget {
  const _SpecGrid({required this.specs});
  final List<(IconData, String, String)> specs;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      for (var i = 0; i < specs.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            for (final sp in specs.skip(i).take(2))
              Expanded(
                child: Row(children: [
                  Icon(sp.$1, size: 22, color: s.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sp.$2, style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
                    Text(sp.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  ])),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.ok, this.text);
  final bool ok;
  final String text;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.remove_circle_outline, size: 20, color: ok ? s.tertiary : s.outline),
        const SizedBox(width: 10),
        Expanded(child: Text(ok ? text : '$text (not available)', style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }
}

class _Similar extends ConsumerWidget {
  const _Similar({required this.brand, required this.excludeId});
  final String brand, excludeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = CatalogFilters(brands: {brand});
    return FutureBuilder<CatalogPage>(
      future: ref.read(catalogRepoProvider).search(f, limit: 8),
      builder: (_, snap) {
        final items = (snap.data?.items ?? const <CatalogModel>[]).where((e) => e.id != excludeId).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final wished = ref.watch(wishlistIdsProvider);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('You may also like'),
          const SizedBox(height: 8),
          SizedBox(
            height: 330,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 172,
                child: ModelCard(model: items[i], wished: wished.contains(items[i].id), onWish: () => toggleWishlist(context, ref, items[i].id), onTap: () => context.push('/model/${items[i].slug}')),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
