import 'dart:typed_data';

import '../errors/app_exception.dart';
import '../models/account.dart';
import '../models/catalog.dart';
import 'gateway.dart';

List<Map<String, dynamic>> _rows(dynamic d) => d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
Map<String, dynamic> _map(dynamic d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

/// Public catalogue, store content and policies. Readable by guests.
class CatalogRepository {
  CatalogRepository(this._g);
  final Gateway _g;

  Future<CatalogPage> search(CatalogFilters f, {int limit = 24, int offset = 0}) async =>
      CatalogPage.fromJson(_map(await _g.rpc('catalog_search', f.toRpc(limit: limit, offset: offset))));

  Future<ModelDetail?> detail(String slug) async {
    final d = await _g.rpc('catalog_model_detail', {'p_slug': slug});
    return d == null ? null : ModelDetail.fromJson(_map(d));
  }

  Future<List<String>> brands() async {
    final r = await _g.select('brands', columns: 'name', eq: {'is_active': true}, orderBy: 'name');
    return r.map((e) => e['name'].toString()).toList();
  }

  Future<StoreSettings> settings() async {
    final r = await _g.select('store_settings', eq: {'id': 1}, limit: 1);
    return r.isEmpty ? const StoreSettings() : StoreSettings.fromJson(r.first);
  }

  Future<List<HomeBanner>> banners() async =>
      (await _g.select('banners', columns: 'title,subtitle', orderBy: 'sort_order')).map(HomeBanner.fromJson).toList();

  Future<List<Faq>> faqs() async => (await _g.select('faqs', columns: 'q,a', orderBy: 'sort_order')).map(Faq.fromJson).toList();

  /// Active owner-approved policy text (null until the owner approves one).
  Future<Map<String, dynamic>?> activeReturnPolicy() async {
    final r = await _g.select('return_policies', eq: {'is_active': true}, limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> activeWarrantyPolicy() async {
    final r = await _g.select('warranty_policies', eq: {'is_active': true}, limit: 1);
    return r.isEmpty ? null : r.first;
  }
}

/// Cart and wishlist are stored on the server for the signed-in customer.
class CartRepository {
  CartRepository(this._g);
  final Gateway _g;

  Future<List<CartLine>> cart() async => _rows(await _g.rpc('cart_list')).map(CartLine.fromJson).toList();
  Future<void> add(String unitId) => _g.rpc('cart_add', {'p_unit': unitId});
  Future<void> remove(String unitId) => _g.rpc('cart_remove', {'p_unit': unitId});
  Future<void> clear() => _g.rpc('cart_clear');

  Future<List<WishlistEntry>> wishlist() async => _rows(await _g.rpc('wishlist_list')).map(WishlistEntry.fromJson).toList();
  Future<bool> toggleWishlist(String modelId) async => (await _g.rpc('wishlist_toggle', {'p_model': modelId})) == true;
}

class AccountRepository {
  AccountRepository(this._g);
  final Gateway _g;

  String _uid() {
    final id = _g.userId;
    if (id == null) throw AppException('UNAUTHENTICATED', 'Please sign in to continue.');
    return id;
  }

  Future<Profile> profile() async {
    final r = await _g.select('customer_profiles', eq: {'id': _uid()}, limit: 1);
    return r.isEmpty ? Profile(email: _g.userEmail ?? '') : Profile.fromJson(r.first);
  }

  Future<void> saveProfile({required String fullName, required String phone}) => _g.updateRow(
      'customer_profiles', {'full_name': fullName.trim(), 'phone': phone.isEmpty ? null : phone}, {'id': _uid()});

  Future<List<Address>> addresses() async =>
      (await _g.select('addresses', orderBy: 'created_at', ascending: false)).map(Address.fromJson).toList();

  Future<void> addAddress(Address a) => _g.insert('addresses', a.toInsert(_uid()));

  Future<void> updateAddress(Address a) {
    final v = a.toInsert(_uid())..remove('user_id');
    return _g.updateRow('addresses', v, {'id': a.id});
  }

  Future<void> deleteAddress(String id) => _g.deleteRow('addresses', {'id': id});

  Future<List<AppNotification>> notifications() async =>
      (await _g.select('notifications', orderBy: 'created_at', ascending: false, limit: 60)).map(AppNotification.fromJson).toList();

  Future<void> markAllRead() => _g.rpc('mark_notifications_read');

  Future<NotificationPrefs> prefs() async {
    final r = await _g.select('notification_preferences', limit: 1);
    return NotificationPrefs.fromJson(r.isEmpty ? null : r.first);
  }

  Future<void> savePrefs(NotificationPrefs p) => _g.rpc('set_notification_preferences', {
        'p_push_transactional': p.pushTransactional, 'p_push_marketing': p.pushMarketing, 'p_email_marketing': p.emailMarketing,
      });

  Future<void> registerDeviceToken(String token, String platform) => _g.rpc('register_device_token', {'p_token': token, 'p_platform': platform});
  Future<void> revokeDeviceToken(String token) => _g.rpc('revoke_device_token', {'p_token': token});

  Future<void> requestAccountDeletion() => _g.rpc('request_account_deletion');
  Future<Map<String, dynamic>> exportMyData() async => _map(await _g.rpc('export_my_data'));
}

class OrderRepository {
  OrderRepository(this._g);
  final Gateway _g;

  Future<List<Order>> orders() async => _rows(await _g.rpc('my_orders')).map(Order.fromJson).toList();

  Future<DeliveryQuote> quoteDelivery({String? pincode, required int subtotalPaise, required bool pickup}) async =>
      DeliveryQuote.fromJson(_map(await _g.rpc('quote_delivery', {
        'p_pincode': pincode, 'p_subtotal_paise': subtotalPaise, 'p_fulfillment': pickup ? 'pickup' : 'delivery',
      })));

  Future<CouponQuote> quoteCoupon(String code, int subtotalPaise) async =>
      CouponQuote.fromJson(_map(await _g.rpc('coupon_quote', {'p_code': code, 'p_subtotal_paise': subtotalPaise})));

  /// The server prices the order. Only ids, choices and an idempotency key are sent.
  Future<PlacedOrder> placeOrder({
    required String idempotencyKey, required List<String> unitIds, required bool pickup, required String paymentMethod,
    String? addressId, String? coupon, Map<String, String>? contact,
  }) async {
    final r = await _g.invoke(
      'create-order',
      {
        'unit_ids': unitIds, 'fulfillment': pickup ? 'pickup' : 'delivery', 'payment_method': paymentMethod,
        'address_id': addressId, 'coupon': coupon, 'contact': contact ?? {}, 'idempotency_key': idempotencyKey,
      },
      headers: {'x-idempotency-key': idempotencyKey},
    );
    final o = _map(r['order']);
    final rz = r['razorpay'] is Map ? _map(r['razorpay']) : null;
    return PlacedOrder(
      orderId: '${o['order_id']}', orderNumber: '${o['order_number']}', totalPaise: (o['total_paise'] as num).toInt(),
      requiresPayment: o['requires_payment'] == true, razorpayKey: rz?['key_id'] as String?,
      razorpayOrderId: rz?['order_id'] as String?, expiresAt: parseDateSafe(o['expires_at']),
    );
  }

  /// Re-open payment for an unpaid order that still holds its phones.
  Future<PlacedOrder> resumePayment(String orderId) async {
    final r = await _g.invoke('create-order', {'action': 'resume', 'order_id': orderId});
    final rz = _map(r['razorpay']);
    return PlacedOrder(
      orderId: '${r['order_id']}', orderNumber: '${r['order_number']}', totalPaise: (r['total_paise'] as num).toInt(),
      requiresPayment: true, razorpayKey: rz['key_id'] as String?, razorpayOrderId: rz['order_id'] as String?,
      expiresAt: parseDateSafe(r['expires_at']),
    );
  }

  /// The Razorpay callback is only a signal; the server verifies the signature and the provider's own record.
  Future<String> verifyPayment({required String razorpayOrderId, required String paymentId, required String signature}) async {
    final r = await _g.invoke('verify-payment', {
      'razorpay_order_id': razorpayOrderId, 'razorpay_payment_id': paymentId, 'razorpay_signature': signature,
    });
    return '${r['status'] ?? 'unknown'}';
  }

  /// Asks the server to reconcile with Razorpay (used if the app was closed mid-payment).
  Future<String> syncPayment(String razorpayOrderId) async {
    final r = await _g.invoke('verify-payment', {'action': 'sync', 'razorpay_order_id': razorpayOrderId});
    return '${r['status'] ?? 'unknown'}';
  }

  Future<void> cancel(String orderId, {String reason = ''}) => _g.rpc('customer_cancel_order', {'p_order': orderId, 'p_reason': reason});
}

DateTime? parseDateSafe(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class EnquiryRepository {
  EnquiryRepository(this._g);
  final Gateway _g;

  Future<List<SellEnquiry>> list() async =>
      (await _g.select('sell_enquiries', orderBy: 'created_at', ascending: false)).map(SellEnquiry.fromJson).toList();

  Future<String> submit(Map<String, dynamic> payload, {List<({Uint8List bytes, String contentType})> photos = const []}) async {
    final uid = _g.userId;
    if (uid == null) throw AppException('UNAUTHENTICATED', 'Please sign in to continue.');
    final r = _map(await _g.rpc('submit_sell_enquiry', {'p': payload}));
    final id = '${r['id']}';
    var n = 0;
    for (final p in photos.take(6)) {
      final ext = p.contentType.contains('png') ? 'png' : (p.contentType.contains('webp') ? 'webp' : 'jpg');
      final path = '$uid/${id}_${n++}.$ext';
      await _g.uploadBytes('enquiry-photos', path, p.bytes, p.contentType);
      await _g.rpc('add_enquiry_photo', {'p_enquiry': id, 'p_path': path});
    }
    return '${r['enquiry_number']}';
  }
}

class WarrantyRepository {
  WarrantyRepository(this._g);
  final Gateway _g;

  Future<List<Map<String, dynamic>>> claims() => _g.select('warranty_claims', orderBy: 'created_at', ascending: false);
  Future<List<Map<String, dynamic>>> returns() => _g.select('return_requests', orderBy: 'created_at', ascending: false);

  Future<String> submitClaim(String orderItemId, String issue) async =>
      '${_map(await _g.rpc('submit_warranty_claim', {'p_order_item': orderItemId, 'p_issue': issue}))['claim_number']}';

  Future<String> submitReturn(String orderItemId, String reason) async =>
      '${_map(await _g.rpc('submit_return_request', {'p_order_item': orderItemId, 'p_reason': reason}))['request_number']}';
}
