import 'dart:async';

import 'package:budgetphonewala/app.dart';
import 'package:budgetphonewala/core/data/gateway.dart';
import 'package:budgetphonewala/core/data/services.dart';
import 'package:budgetphonewala/core/providers.dart';
import 'package:budgetphonewala/core/router/app_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef RpcHandler = dynamic Function(Map<String, dynamic>? params);

/// Scriptable in-memory backend. Records every call so tests can assert what the app sent.
class FakeGateway implements Gateway {
  FakeGateway({this._userId, this.email = 'buyer@test.local'});

  String? _userId;
  final String email;
  final _ids = StreamController<String?>.broadcast();
  final Map<String, RpcHandler> rpcs = {};
  final Map<String, List<Map<String, dynamic>> Function(Map<String, Object>? eq)> tables = {};
  final Map<String, Map<String, dynamic> Function(Map<String, dynamic> body)> functions = {};
  final List<({String fn, Map<String, dynamic>? params})> rpcCalls = [];
  final List<({String fn, Map<String, dynamic> body, Map<String, String>? headers})> invokeCalls = [];
  final List<({String table, Map<String, dynamic> row})> inserts = [];

  @override
  String? get userId => _userId;
  @override
  String? get userEmail => _userId == null ? null : email;
  @override
  Stream<String?> get userIdChanges => _ids.stream;

  void signIn(String id) {
    _userId = id;
    _ids.add(id);
  }

  void signOut() {
    _userId = null;
    _ids.add(null);
  }

  @override
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) async {
    rpcCalls.add((fn: fn, params: params));
    final h = rpcs[fn];
    if (h == null) throw StateError('No fake RPC handler for $fn');
    return h(params);
  }

  @override
  Future<List<Map<String, dynamic>>> select(String table, {String columns = '*', Map<String, Object>? eq, String? orderBy, bool ascending = true, int? limit}) async {
    final h = tables[table];
    return h == null ? <Map<String, dynamic>>[] : h(eq);
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) async => inserts.add((table: table, row: row));
  @override
  Future<void> updateRow(String table, Map<String, dynamic> values, Map<String, Object> eq) async {}
  @override
  Future<void> deleteRow(String table, Map<String, Object> eq) async {}

  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    invokeCalls.add((fn: fn, body: body, headers: headers));
    final h = functions[fn];
    if (h == null) throw StateError('No fake function handler for $fn');
    return h(body);
  }

  @override
  Future<void> uploadBytes(String bucket, String path, Uint8List bytes, String contentType) async {}
}

class FakeAuth implements AuthService {
  FakeAuth(this.gateway);
  final FakeGateway gateway;
  bool requireVerification = false;
  @override
  Future<bool> signUp({required String email, required String password, required String fullName}) async {
    if (requireVerification) return false;
    gateway.signIn('new-user');
    return true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async => gateway.signIn('user-a');
  @override
  Future<void> signInWithGoogle() async => gateway.signIn('user-g');
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async => gateway.signOut();
}

class FakePayments implements PaymentLauncher {
  FakePayments(this.outcome);
  PaymentOutcome outcome;
  int calls = 0;
  @override
  Future<PaymentOutcome> pay({required String keyId, required String razorpayOrderId, required int amountPaise, required String name, required String description, String? contact, String? email}) async {
    calls++;
    return outcome;
  }
}

Map<String, dynamic> modelJson({String id = 'm1', String slug = 'iphone-12', String name = 'iPhone 12', String brand = 'Apple', int from = 2749900, int mrp = 5990000, int units = 1}) => {
      'id': id, 'slug': slug, 'name': name, 'brand': brand, 'from_price_paise': from, 'max_mrp_paise': mrp, 'available_units': units,
      'network': '5G', 'storages': [128], 'colors': ['Blue'], 'grades': ['A+'], 'max_battery': 89, 'warranty_months': 12, 'primary_image': null,
    };

Map<String, dynamic> unitJson({String id = 'u1', int price = 2749900, int mrp = 5990000}) => {
      'id': id, 'unit_code': 'U-000001', 'model_id': 'm1', 'storage_gb': 128, 'ram_gb': 4, 'color': 'Blue', 'condition_grade': 'A+',
      'battery_health_pct': 89, 'selling_price_paise': price, 'mrp_paise': mrp, 'has_bill': true, 'has_box': true, 'accessories': 'Charger',
      'defects_notes': 'No visible scratches', 'warranty_months': 12, 'images': [], 'inspection': {}, 'inspection_notes': '',
    };

Map<String, dynamic> cartLineJson({String unit = 'u1', int price = 2749900, bool available = true}) => {
      'unit_id': unit, 'model_id': 'm1', 'model_slug': 'iphone-12', 'title': 'Apple iPhone 12, 128GB, Blue', 'brand': 'Apple',
      'price_paise': price, 'mrp_paise': 5990000, 'condition_grade': 'A+', 'battery_health_pct': 89, 'image': null, 'available': available,
    };

Map<String, dynamic> addressJson({String id = 'a1', String pin = '413304'}) => {
      'id': id, 'label': 'Home', 'full_name': 'Test Buyer', 'phone': '9822145678', 'line1': 'Station Road 12', 'line2': '', 'landmark': '',
      'city': 'Pandharpur', 'state': 'MH', 'pincode': pin, 'is_default': true,
    };

Map<String, dynamic> orderJson({String id = 'o1', String number = 'BPW-2026-01001', String status = 'placed', String payStatus = 'captured', String method = 'razorpay', int total = 2759800}) => {
      'id': id, 'order_number': number, 'status': status, 'payment_method': method, 'payment_status': payStatus, 'fulfillment_type': 'delivery',
      'subtotal_paise': 2749900, 'discount_paise': 0, 'delivery_fee_paise': 9900, 'cod_fee_paise': 0, 'tax_paise': 0, 'total_paise': total,
      'customer_name': 'Test Buyer', 'customer_phone': '9822145678', 'address': {'line1': 'Station Road 12', 'pincode': '413304'}, 'pickup': {},
      'created_at': DateTime.now().toIso8601String(), 'expires_at': null,
      'items': [{'id': 'i1', 'unit_id': 'u1', 'model_id': 'm1', 'title': 'Apple iPhone 12, 128GB, Blue', 'price_paise': 2749900, 'image': null, 'warranty_months': 12}],
      'history': [{'status': status, 'at': DateTime.now().toIso8601String(), 'note': ''}], 'fulfillment': {}, 'refunds': [],
    };

/// A backend with sensible defaults for a signed-in shopper. Tests override what they care about.
FakeGateway buildGateway({String? userId = 'user-a'}) {
  final g = FakeGateway(userId: userId);
  g.rpcs['catalog_search'] = (_) => {'total': 1, 'items': [modelJson()]};
  g.rpcs['catalog_model_detail'] = (p) => {'model': modelJson(), 'images': [], 'units': [unitJson()]};
  g.rpcs['cart_list'] = (_) => [cartLineJson()];
  g.rpcs['wishlist_list'] = (_) => [];
  g.rpcs['my_orders'] = (_) => [];
  g.rpcs['quote_delivery'] = (p) => {'serviceable': true, 'fee_paise': p?['p_fulfillment'] == 'pickup' ? 0 : 9900, 'cod_allowed': true};
  g.rpcs['cart_add'] = (_) => null;
  g.rpcs['cart_remove'] = (_) => null;
  g.rpcs['wishlist_toggle'] = (_) => true;
  g.tables['store_settings'] = (_) => [{'shop_name': 'BudgetPhonewala', 'address': 'Pandharpur', 'cod_enabled': false, 'reservation_minutes': 10, 'pickup_enabled': true, 'delivery_enabled': true}];
  g.tables['brands'] = (_) => [{'name': 'Apple'}];
  g.tables['banners'] = (_) => [];
  g.tables['faqs'] = (_) => [];
  g.tables['addresses'] = (_) => [addressJson()];
  g.tables['customer_profiles'] = (_) => [{'full_name': 'Test Buyer', 'phone': '9822145678', 'email': 'buyer@test.local'}];
  g.tables['notification_preferences'] = (_) => [];
  return g;
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required FakeGateway gateway,
  PaymentLauncher? payments,
  String location = '/',
  bool reduceMotion = true,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': true});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    gatewayProvider.overrideWithValue(gateway),
    authServiceProvider.overrideWithValue(FakeAuth(gateway)),
    if (payments != null) paymentLauncherProvider.overrideWithValue(payments),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const BudgetPhoneApp()));
  await tester.pump(const Duration(milliseconds: 900)); // splash
  await tester.pump();
  if (location != '/') {
    container.read(routerProvider).go(location);
  }
  await tester.pumpAndSettle();
  return container;
}
