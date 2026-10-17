import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/actions.dart';

/// Bottom navigation (Home, Search, Sell, Orders, Profile) with the WhatsApp action on Home.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.search, Icons.search, 'Search'),
    (Icons.sell_outlined, Icons.sell, 'Sell'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).value ?? const [];
    final needsPayment = orders.any((o) => o.canPay());
    final settings = ref.watch(settingsProvider).value;
    final i = shell.currentIndex;
    return PopScope(
      // back from another tab returns to Home first (same as the legacy app)
      canPop: i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && i != 0) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        floatingActionButton: i == 0
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.whatsapp,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                onPressed: () => openWhatsApp(context, settings ?? const StoreSettings(), 'Hello BudgetPhonewala! I am looking for a phone.'),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            : null,
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.0,
          child: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (n) => shell.goBranch(n, initialLocation: n == i),
          destinations: [
            for (var n = 0; n < _tabs.length; n++)
              NavigationDestination(
                icon: Badge(isLabelVisible: n == 3 && needsPayment, smallSize: 8, child: Icon(_tabs[n].$1)),
                selectedIcon: Icon(_tabs[n].$2),
                // fixed size so labels are never cut at large system font sizes
                label: _tabs[n].$3,
              ),
          ],
        )),
      ),
    );
  }
}
