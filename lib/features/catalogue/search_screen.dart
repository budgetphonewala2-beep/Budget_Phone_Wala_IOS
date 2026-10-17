import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';
import 'model_grid.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initial = const CatalogFilters()});
  final CatalogFilters initial;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _pageSize = 24;
  final _q = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late CatalogFilters _f = widget.initial;
  List<CatalogModel> _items = const [];
  int _total = 0;
  bool _loading = true, _loadingMore = false;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _q.text = widget.initial.query;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() { _loading = true; _error = null; });
    try {
      final page = await ref.read(catalogRepoProvider).search(_f, limit: _pageSize);
      if (!mounted || gen != _gen) return;
      setState(() { _items = page.items; _total = page.total; _loading = false; });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _items.length >= _total) return;
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(catalogRepoProvider).search(_f, limit: _pageSize, offset: _items.length);
      if (!mounted || gen != _gen) return;
      setState(() { _items = [..._items, ...page.items]; _loadingMore = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        showSnack(context, toAppException(e).message);
      }
    }
  }

  void _apply(CatalogFilters f) {
    _f = f;
    _load();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _apply(_f.copyWith(query: v)));
  }

  Future<void> _openFilters() async {
    final brands = ref.read(brandsProvider).value ?? const <String>[];
    final r = await showModalBottomSheet<CatalogFilters>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _f, brands: brands),
    );
    if (r != null) _apply(r);
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final recent = ref.watch(recentSearchesProvider);
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onChanged: (v) { setState(() {}); _onQuery(v); },
            onSubmitted: (v) { ref.read(recentSearchesProvider.notifier).add(v); _apply(_f.copyWith(query: v)); },
            decoration: InputDecoration(
              hintText: 'Search phones, brands, models',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide(color: s.outlineVariant)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide(color: s.outlineVariant)),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_q.text.isNotEmpty) IconButton(tooltip: 'Clear search', icon: const Icon(Icons.clear), onPressed: () { _q.clear(); setState(() {}); _apply(_f.copyWith(query: '')); }),
                IconButton(tooltip: 'Filters', onPressed: _openFilters, icon: Badge(isLabelVisible: _f.activeCount > 0, label: Text('${_f.activeCount}'), child: const Icon(Icons.tune))),
              ]),
            ),
          ),
        ),
        if (_q.text.isEmpty && recent.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.history, size: 18, color: s.onSurfaceVariant))),
              for (final r in recent) Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(r), onPressed: () { _q.text = r; setState(() {}); _apply(_f.copyWith(query: r)); })),
              TextButton(onPressed: () => ref.read(recentSearchesProvider.notifier).clear(), child: const Text('Clear')),
            ]),
          ),
        if (_f.activeCount > 0)
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
              for (final b in _f.brands) _chip(b, () => _apply(_f.copyWith(brands: {..._f.brands}..remove(b)))),
              for (final g in _f.grades) _chip('Grade $g', () => _apply(_f.copyWith(grades: {..._f.grades}..remove(g)))),
              for (final n in _f.network) _chip(n, () => _apply(_f.copyWith(network: {..._f.network}..remove(n)))),
              for (final x in _f.storage) _chip('${x}GB', () => _apply(_f.copyWith(storage: {..._f.storage}..remove(x)))),
              if (_f.maxPricePaise != null) _chip('Under ${rupees(_f.maxPricePaise!)}', () => _apply(_f.copyWith(clearMaxPrice: true))),
              if (_f.minRam != null) _chip('${_f.minRam}GB+ RAM', () => _apply(_f.copyWith(clearMinRam: true))),
              if (_f.minBattery != null) _chip('Battery ${_f.minBattery}%+', () => _apply(_f.copyWith(clearMinBattery: true))),
            ]),
          ),
        Expanded(
          child: _error != null && _items.isEmpty
              ? ErrorState(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(controller: _scroll, slivers: [
                    if (_loading) const SliverCardSkeletons(rows: 3)
                    else if (_items.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.search_off, title: 'No phones found', body: 'Try a brand like Samsung, or clear some filters.', actionLabel: 'Clear all', onAction: () { _q.clear(); _apply(const CatalogFilters()); }))
                    else ...[
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Text('$_total phone${_total == 1 ? '' : 's'}', style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)))),
                      SliverModelGrid(items: _items),
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: _loadingMore ? const CircularProgressIndicator() : (_items.length < _total ? TextButton(onPressed: _loadMore, child: const Text('Load more')) : const SizedBox(height: 24))))),
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(label: Text(label), selected: true, onPressed: onRemove, onDeleted: onRemove, deleteButtonTooltipMessage: 'Remove $label filter', showCheckmark: false),
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.brands});
  final CatalogFilters initial;
  final List<String> brands;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CatalogFilters f = widget.initial;

  Widget group(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: chips),
        ]),
      );

  Set<T> toggle<T>(Set<T> s, T v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
          if (widget.brands.isNotEmpty) group('Brand', [for (final b in widget.brands) FilterChip(label: Text(b), selected: f.brands.contains(b), onSelected: (_) => setState(() => f = f.copyWith(brands: toggle(f.brands, b))))]),
          group('Budget', [for (final v in const [10000, 15000, 20000, 30000]) FilterChip(label: Text('Under ${rupees(v * 100)}'), selected: f.maxPricePaise == v * 100, onSelected: (_) => setState(() => f = f.maxPricePaise == v * 100 ? f.copyWith(clearMaxPrice: true) : f.copyWith(maxPricePaise: v * 100)))]),
          group('Condition grade', [for (final g in const ['A+', 'A', 'B', 'C']) FilterChip(label: Text('Grade $g'), selected: f.grades.contains(g), onSelected: (_) => setState(() => f = f.copyWith(grades: toggle(f.grades, g))))]),
          group('Network', [for (final n in const ['5G', '4G']) FilterChip(label: Text(n), selected: f.network.contains(n), onSelected: (_) => setState(() => f = f.copyWith(network: toggle(f.network, n))))]),
          group('Storage', [for (final x in const [64, 128, 256, 512]) FilterChip(label: Text('${x}GB'), selected: f.storage.contains(x), onSelected: (_) => setState(() => f = f.copyWith(storage: toggle(f.storage, x))))]),
          group('RAM', [for (final r in const [4, 6, 8]) FilterChip(label: Text('${r}GB+'), selected: f.minRam == r, onSelected: (_) => setState(() => f = f.minRam == r ? f.copyWith(clearMinRam: true) : f.copyWith(minRam: r)))]),
          group('Battery health', [for (final b in const [80, 85, 90]) FilterChip(label: Text('$b%+'), selected: f.minBattery == b, onSelected: (_) => setState(() => f = f.minBattery == b ? f.copyWith(clearMinBattery: true) : f.copyWith(minBattery: b)))]),
          group('Sort by', [for (final (v, l) in const [('new', 'Newest'), ('price_low', 'Price: low to high'), ('price_high', 'Price: high to low'), ('battery', 'Battery health')]) ChoiceChip(label: Text(l), selected: f.sort == v, onSelected: (_) => setState(() => f = f.copyWith(sort: v)))]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: AppButton('Reset', () => setState(() => f = CatalogFilters(query: f.query)), style: BtnStyle.outlined)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: AppButton('Apply filters', () => Navigator.pop(context, f))),
          ]),
        ]),
      ),
    );
  }
}
