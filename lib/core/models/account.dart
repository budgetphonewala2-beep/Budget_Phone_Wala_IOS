import '../util/format.dart';

int _i(dynamic v, [int d = 0]) => v == null ? d : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? d);
String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
List<T> _list<T>(dynamic v, T Function(dynamic) f) => v is List ? v.map(f).toList() : <T>[];
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class Profile {
  const Profile({this.fullName = '', this.phone = '', this.email = ''});
  final String fullName, phone, email;
  bool get isEmpty => fullName.isEmpty && phone.isEmpty;
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : 'BP';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(fullName: _s(j['full_name']), phone: _s(j['phone']), email: _s(j['email']));
}

class Address {
  const Address({
    required this.id, required this.label, required this.fullName, required this.phone, required this.line1,
    this.line2 = '', this.landmark = '', this.city = '', this.state = '', required this.pincode, this.isDefault = false,
  });
  final String id, label, fullName, phone, line1, line2, landmark, city, state, pincode;
  final bool isDefault;

  String get oneLine => [line1, if (line2.isNotEmpty) line2, if (city.isNotEmpty) city, pincode].join(', ');

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: _s(j['id']), label: _s(j['label'], 'Home'), fullName: _s(j['full_name']), phone: _s(j['phone']),
        line1: _s(j['line1']), line2: _s(j['line2']), landmark: _s(j['landmark']), city: _s(j['city']),
        state: _s(j['state']), pincode: _s(j['pincode']), isDefault: j['is_default'] == true,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId, 'label': label, 'full_name': fullName, 'phone': phone, 'line1': line1, 'line2': line2,
        'landmark': landmark, 'city': city, 'state': state, 'pincode': pincode, 'is_default': isDefault,
      };
}

class CartLine {
  const CartLine({
    required this.unitId, required this.modelId, required this.modelSlug, required this.title, required this.pricePaise,
    required this.mrpPaise, required this.grade, required this.battery, required this.available, this.image,
  });
  final String unitId, modelId, modelSlug, title, grade;
  final int pricePaise, mrpPaise, battery;
  final bool available;
  final String? image;

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        unitId: _s(j['unit_id']), modelId: _s(j['model_id']), modelSlug: _s(j['model_slug']), title: _s(j['title']),
        pricePaise: _i(j['price_paise']), mrpPaise: _i(j['mrp_paise']), grade: _s(j['condition_grade']),
        battery: _i(j['battery_health_pct']), available: j['available'] == true, image: j['image'] as String?,
      );
}

class WishlistEntry {
  const WishlistEntry({required this.modelId, required this.slug, required this.name, required this.brand, required this.fromPricePaise, required this.availableUnits, this.image});
  final String modelId, slug, name, brand;
  final int fromPricePaise, availableUnits;
  final String? image;
  factory WishlistEntry.fromJson(Map<String, dynamic> j) => WishlistEntry(
        modelId: _s(j['model_id']), slug: _s(j['slug']), name: _s(j['name']), brand: _s(j['brand']),
        fromPricePaise: _i(j['from_price_paise']), availableUnits: _i(j['available_units']), image: j['image'] as String?,
      );
}

class OrderItem {
  const OrderItem({required this.id, required this.unitId, required this.modelId, required this.title, required this.pricePaise, required this.warrantyMonths, this.image, this.warrantyEnd});
  final String id, unitId, modelId, title;
  final int pricePaise, warrantyMonths;
  final String? image;
  final DateTime? warrantyEnd;
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: _s(j['id']), unitId: _s(j['unit_id']), modelId: _s(j['model_id']), title: _s(j['title']),
        pricePaise: _i(j['price_paise']), warrantyMonths: _i(j['warranty_months']), image: j['image'] as String?,
        warrantyEnd: parseDate(j['warranty_end']),
      );
}

class OrderStep {
  const OrderStep(this.status, this.at, this.note);
  final String status, note;
  final DateTime? at;
}

class Order {
  const Order({
    required this.id, required this.number, required this.status, required this.paymentMethod, required this.paymentStatus,
    required this.fulfillment, required this.subtotalPaise, required this.discountPaise, required this.deliveryFeePaise,
    required this.codFeePaise, required this.totalPaise, required this.name, required this.phone, required this.address,
    required this.pickup, required this.createdAt, required this.expiresAt, required this.items, required this.history,
    required this.fulfillmentInfo, required this.refunds, this.cancelReason,
  });

  final String id, number, status, paymentMethod, paymentStatus, fulfillment, name, phone;
  final int subtotalPaise, discountPaise, deliveryFeePaise, codFeePaise, totalPaise;
  final Map<String, dynamic> address, pickup, fulfillmentInfo;
  final DateTime? createdAt, expiresAt;
  final List<OrderItem> items;
  final List<OrderStep> history;
  final List<Map<String, dynamic>> refunds;
  final String? cancelReason;

  bool get isPickup => fulfillment == 'pickup';
  bool get isCod => paymentMethod == 'cod';
  bool get isPaidOnline => paymentStatus == 'captured' || paymentStatus == 'partially_refunded' || paymentStatus == 'refunded';
  bool canPay([DateTime? now]) => paymentMethod == 'razorpay' && status == 'pending_payment' && expiresAt != null && expiresAt!.isAfter(now ?? DateTime.now());
  bool get canCancel => const {'pending_payment', 'placed', 'confirmed'}.contains(status);
  bool get isDelivered => status == 'delivered' || status == 'picked_up';

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _s(j['id']), number: _s(j['order_number']), status: _s(j['status']), paymentMethod: _s(j['payment_method']),
        paymentStatus: _s(j['payment_status']), fulfillment: _s(j['fulfillment_type']), subtotalPaise: _i(j['subtotal_paise']),
        discountPaise: _i(j['discount_paise']), deliveryFeePaise: _i(j['delivery_fee_paise']), codFeePaise: _i(j['cod_fee_paise']),
        totalPaise: _i(j['total_paise']), name: _s(j['customer_name']), phone: _s(j['customer_phone']),
        address: _m(j['address']), pickup: _m(j['pickup']), createdAt: parseDate(j['created_at']),
        expiresAt: parseDate(j['expires_at']), cancelReason: j['cancel_reason'] as String?,
        items: _list(j['items'], (e) => OrderItem.fromJson(_m(e))),
        history: _list(j['history'], (e) {
          final m = _m(e);
          return OrderStep(_s(m['status']), parseDate(m['at']), _s(m['note']));
        }),
        fulfillmentInfo: _m(j['fulfillment']),
        refunds: _list(j['refunds'], (e) => _m(e)),
      );
}

/// Human labels. Pickup orders use pickup wording.
String orderStatusLabel(String status, {bool pickup = false}) {
  switch (status) {
    case 'pending_payment':
      return 'Awaiting payment';
    case 'placed':
      return 'Order placed';
    case 'confirmed':
      return 'Confirmed';
    case 'packed':
      return pickup ? 'Being prepared' : 'Packed';
    case 'dispatched':
      return 'Dispatched';
    case 'out_for_delivery':
      return 'Out for delivery';
    case 'delivered':
      return 'Delivered';
    case 'ready_for_pickup':
      return 'Ready for pickup';
    case 'picked_up':
      return 'Picked up';
    case 'delivery_failed':
      return 'Delivery attempt failed';
    case 'returned':
      return 'Returned';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status.replaceAll('_', ' ');
  }
}

List<String> orderTimeline({required bool pickup, required bool cod}) => pickup
    ? ['placed', 'confirmed', 'packed', 'ready_for_pickup', 'picked_up']
    : ['placed', 'confirmed', 'packed', 'dispatched', 'out_for_delivery', 'delivered'];

class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body, required this.createdAt, required this.read, required this.type});
  final String id, title, body, type;
  final DateTime? createdAt;
  final bool read;
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _s(j['id']), title: _s(j['title']), body: _s(j['body']), type: _s(j['type']),
        createdAt: parseDate(j['created_at']), read: j['read_at'] != null,
      );
}

class NotificationPrefs {
  const NotificationPrefs({this.pushTransactional = true, this.pushMarketing = false, this.emailMarketing = false});
  final bool pushTransactional, pushMarketing, emailMarketing;
  factory NotificationPrefs.fromJson(Map<String, dynamic>? j) => j == null
      ? const NotificationPrefs()
      : NotificationPrefs(pushTransactional: j['push_transactional'] != false, pushMarketing: j['push_marketing'] == true, emailMarketing: j['email_marketing'] == true);
}

class SellEnquiry {
  const SellEnquiry({required this.id, required this.number, required this.type, required this.status, required this.brand, required this.model, this.expectedPaise, this.offerPaise, this.notes = '', this.createdAt});
  final String id, number, type, status, brand, model, notes;
  final int? expectedPaise, offerPaise;
  final DateTime? createdAt;
  factory SellEnquiry.fromJson(Map<String, dynamic> j) => SellEnquiry(
        id: _s(j['id']), number: _s(j['enquiry_number']), type: _s(j['type']), status: _s(j['status']), brand: _s(j['brand']),
        model: _s(j['model']), expectedPaise: j['expected_price_paise'] == null ? null : _i(j['expected_price_paise']),
        offerPaise: j['admin_offer_paise'] == null ? null : _i(j['admin_offer_paise']), notes: _s(j['admin_notes']),
        createdAt: parseDate(j['created_at']),
      );
}

class DeliveryQuote {
  const DeliveryQuote({required this.serviceable, required this.feePaise, required this.codAllowed, this.reason, this.zoneName});
  final bool serviceable, codAllowed;
  final int feePaise;
  final String? reason, zoneName;
  factory DeliveryQuote.fromJson(Map<String, dynamic> j) => DeliveryQuote(
        serviceable: j['serviceable'] == true, feePaise: _i(j['fee_paise']), codAllowed: j['cod_allowed'] != false,
        reason: j['reason'] as String?, zoneName: j['zone_name'] as String?,
      );
}

class CouponQuote {
  const CouponQuote({required this.valid, required this.discountPaise, required this.message, this.code = ''});
  final bool valid;
  final int discountPaise;
  final String message, code;
  factory CouponQuote.fromJson(Map<String, dynamic> j) => CouponQuote(valid: j['valid'] == true, discountPaise: _i(j['discount_paise']), message: _s(j['message']), code: _s(j['code']));
}

class PlacedOrder {
  const PlacedOrder({required this.orderId, required this.orderNumber, required this.totalPaise, required this.requiresPayment, this.razorpayKey, this.razorpayOrderId, this.expiresAt});
  final String orderId, orderNumber;
  final int totalPaise;
  final bool requiresPayment;
  final String? razorpayKey, razorpayOrderId;
  final DateTime? expiresAt;
}
