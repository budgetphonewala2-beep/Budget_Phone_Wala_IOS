import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/error_reporter.dart';
import 'data/gateway.dart';
import 'data/repositories.dart';
import 'data/services.dart';
import 'models/account.dart';
import 'models/catalog.dart';

// ---------- infrastructure (overridden in tests) ----------
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main()'));
final gatewayProvider = Provider<Gateway>((ref) => SupabaseGateway(Supabase.instance.client));
final authServiceProvider = Provider<AuthService>((ref) => SupabaseAuthService(Supabase.instance.client));
final paymentLauncherProvider = Provider<PaymentLauncher>((ref) => RazorpayLauncher());

final catalogRepoProvider = Provider((ref) => CatalogRepository(ref.watch(gatewayProvider)));
final cartRepoProvider = Provider((ref) => CartRepository(ref.watch(gatewayProvider)));
final accountRepoProvider = Provider((ref) => AccountRepository(ref.watch(gatewayProvider)));
final orderRepoProvider = Provider((ref) => OrderRepository(ref.watch(gatewayProvider)));
final enquiryRepoProvider = Provider((ref) => EnquiryRepository(ref.watch(gatewayProvider)));
final warrantyRepoProvider = Provider((ref) => WarrantyRepository(ref.watch(gatewayProvider)));

// ---------- session ----------
/// Signed-in user id (null for guests). Every private provider watches this so that signing out or switching
/// accounts rebuilds them and no data from the previous account stays visible.
final userIdProvider = StreamProvider<String?>((ref) async* {
  final g = ref.watch(gatewayProvider);
  yield g.userId;
  yield* g.userIdChanges;
});
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(userIdProvider).value ?? ref.watch(gatewayProvider).userId);
final isSignedInProvider = Provider<bool>((ref) => ref.watch(currentUserIdProvider) != null);

/// Crash and error reporting. A no-op until main() installs the real reporter, so tests never send anything.
final errorReporterProvider = Provider<ErrorReporter>((ref) => const NoopErrorReporter());

// ---------- preferences ----------
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  @override
  ThemeMode build() {
    final v = ref.watch(sharedPrefsProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode m) {
    state = m;
    ref.read(sharedPrefsProvider).setString(_key, m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class OnboardingController extends Notifier<bool> {
  static const _key = 'onboarding_seen';
  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(_key) ?? false;
  void markSeen() {
    state = true;
    ref.read(sharedPrefsProvider).setBool(_key, true);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingController, bool>(OnboardingController.new);

class RecentSearches extends Notifier<List<String>> {
  static const _key = 'recent_searches';
  @override
  List<String> build() {
    // recent searches belong to the account that made them
    ref.watch(currentUserIdProvider);
    return ref.watch(sharedPrefsProvider).getStringList(_key) ?? const [];
  }

  void add(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    state = [t, ...state.where((e) => e.toLowerCase() != t.toLowerCase())].take(6).toList();
    ref.read(sharedPrefsProvider).setStringList(_key, state);
  }

  void clear() {
    state = const [];
    ref.read(sharedPrefsProvider).remove(_key);
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

// ---------- public content ----------
final settingsProvider = FutureProvider<StoreSettings>((ref) => ref.watch(catalogRepoProvider).settings());
final bannersProvider = FutureProvider<List<HomeBanner>>((ref) => ref.watch(catalogRepoProvider).banners());
final faqsProvider = FutureProvider<List<Faq>>((ref) => ref.watch(catalogRepoProvider).faqs());
final brandsProvider = FutureProvider<List<String>>((ref) => ref.watch(catalogRepoProvider).brands());
final newArrivalsProvider = FutureProvider<CatalogPage>((ref) => ref.watch(catalogRepoProvider).search(const CatalogFilters(), limit: 12));
final modelDetailProvider = FutureProvider.family<ModelDetail?, String>((ref, slug) => ref.watch(catalogRepoProvider).detail(slug));

// ---------- private data (rebuilt per account) ----------
final cartProvider = FutureProvider<List<CartLine>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(cartRepoProvider).cart();
});
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).value?.length ?? 0);

final wishlistProvider = FutureProvider<List<WishlistEntry>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(cartRepoProvider).wishlist();
});
final wishlistIdsProvider = Provider<Set<String>>((ref) => (ref.watch(wishlistProvider).value ?? const []).map((e) => e.modelId).toSet());

final profileProvider = FutureProvider<Profile>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const Profile();
  return ref.watch(accountRepoProvider).profile();
});
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(accountRepoProvider).addresses();
});
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(orderRepoProvider).orders();
});
final enquiriesProvider = FutureProvider<List<SellEnquiry>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(enquiryRepoProvider).list();
});
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(accountRepoProvider).notifications();
});
final notificationPrefsProvider = FutureProvider<NotificationPrefs>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const NotificationPrefs();
  return ref.watch(accountRepoProvider).prefs();
});
final claimsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(warrantyRepoProvider).claims();
});
final returnsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(warrantyRepoProvider).returns();
});

/// Phones chosen for the next checkout (Buy now = one unit, cart checkout = all available cart units).
class CheckoutSelection extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(currentUserIdProvider); // never carry a selection across accounts
    return const [];
  }

  void set(List<String> unitIds) => state = List.unmodifiable(unitIds);
  void clear() => state = const [];
}

final checkoutSelectionProvider = NotifierProvider<CheckoutSelection, List<String>>(CheckoutSelection.new);
