import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/util/actions.dart';
import '../../core/widgets/widgets.dart';

/// Two cards per row with equal heights (robust at large font sizes).
class SliverModelGrid extends ConsumerWidget {
  const SliverModelGrid({super.key, required this.items, this.padding = const EdgeInsets.symmetric(horizontal: 16)});
  final List<CatalogModel> items;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(wishlistIdsProvider);
    final rows = <List<CatalogModel>>[for (var i = 0; i < items.length; i += 2) items.sublist(i, i + 2 > items.length ? items.length : i + 2)];
    return SliverList.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, r) => Padding(
        padding: padding,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var c = 0; c < 2; c++) ...[
              if (c == 1) const SizedBox(width: 12),
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
