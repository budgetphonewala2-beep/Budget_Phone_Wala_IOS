import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/util/actions.dart';
import '../../core/widgets/widgets.dart';

/// Equal-height card rows (robust at large font sizes). Two columns on phones, more on wide screens.
int gridColumns(double width) => width >= 840 ? 4 : (width >= 600 ? 3 : 2);

class SliverModelGrid extends ConsumerWidget {
  const SliverModelGrid({super.key, required this.items, this.padding = const EdgeInsets.symmetric(horizontal: 16)});
  final List<CatalogModel> items;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(wishlistIdsProvider);
    return SliverLayoutBuilder(builder: (context, constraints) {
      final cols = gridColumns(constraints.crossAxisExtent);
      final rows = <List<CatalogModel>>[for (var i = 0; i < items.length; i += cols) items.sublist(i, i + cols > items.length ? items.length : i + cols)];
      return SliverList.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, r) => Padding(
          padding: padding,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: c < rows[r].length
                      ? ModelCard(
                          model: rows[r][c],
                          wished: wished.contains(rows[r][c].id),
                          onWish: () => toggleWishlist(context, ref, rows[r][c].id),
                          onTap: () => context.push('/model/${rows[r][c].slug}'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        ),
      );
    });
  }
}

class SliverCardSkeletons extends StatelessWidget {
  const SliverCardSkeletons({super.key, this.rows = 2});
  final int rows;
  @override
  Widget build(BuildContext context) => SliverList.separated(
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: ProductCardSkeleton()), SizedBox(width: 12), Expanded(child: ProductCardSkeleton()),
          ])),
        ),
      );
}
