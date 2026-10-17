import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/cart/wishlist_screen.dart';
import '../../features/catalogue/home_screen.dart';
import '../../features/catalogue/product_detail_screen.dart';
import '../../features/catalogue/search_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/success_screen.dart';
import '../../features/enquiries/sell_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/addresses_screen.dart';
import '../../features/profile/notifications_screen.dart';
import '../../features/profile/privacy_screen.dart';
import '../../features/profile/profile_edit_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../models/catalog.dart';
import '../providers.dart';

/// Paths that need a signed-in customer. Guests can browse the catalogue freely.
bool isProtectedPath(String path) =>
    path == '/cart' || path == '/wishlist' || path.startsWith('/checkout') || path.startsWith('/orders/') ||
    path.startsWith('/profile/') || path == '/notifications';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(currentUserIdProvider, (_, _) => refresh.ping());
  ref.listen(onboardingSeenProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(currentUserIdProvider) != null;
      final path = state.uri.path;
      if (path == '/auth' && signedIn) return state.uri.queryParameters['from'] ?? '/';
      if (!signedIn && isProtectedPath(path)) {
        return '/auth?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (_, s) => AuthScreen(from: s.uri.queryParameters['from'])),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (_, s) {
                final q = s.uri.queryParameters;
                final max = int.tryParse(q['max'] ?? '');
                final initial = CatalogFilters(
                  brands: q['brand'] == null ? const {} : {q['brand']!},
                  maxPricePaise: max == null ? null : max * 100,
                );
                return SearchScreen(key: ValueKey(s.uri.toString()), initial: initial);
              },
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/sell', builder: (_, _) => const SellScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/model/:slug', builder: (_, s) => ProductDetailScreen(slug: s.pathParameters['slug']!, unitId: s.uri.queryParameters['unit'])),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen()),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/checkout/success',
        builder: (_, s) => SuccessScreen(orderNumber: s.uri.queryParameters['order'] ?? '', cod: s.uri.queryParameters['cod'] == '1', refundPending: s.uri.queryParameters['refund'] == '1'),
      ),
      GoRoute(path: '/orders/:id', builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!)),
      GoRoute(path: '/profile/edit', builder: (_, _) => const ProfileEditScreen()),
      GoRoute(path: '/profile/addresses', builder: (_, _) => const AddressesScreen()),
      GoRoute(path: '/profile/notifications', builder: (_, _) => const NotificationPrefsScreen()),
      GoRoute(path: '/profile/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    ],
    errorBuilder: (_, s) => Scaffold(appBar: AppBar(), body: Center(child: Text('Page not found: ${s.uri.path}'))),
    debugLogDiagnostics: kDebugMode,
  );
  ref.onDispose(router.dispose);
  return router;
});
