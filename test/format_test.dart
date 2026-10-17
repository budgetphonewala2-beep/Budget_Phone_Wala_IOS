import 'package:budgetphonewala/core/models/account.dart';
import 'package:budgetphonewala/core/models/catalog.dart';
import 'package:budgetphonewala/core/util/format.dart';
import 'package:budgetphonewala/core/util/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rupees (paise in, Indian grouping out)', () {
    test('groups digits the Indian way', () {
      expect(rupees(2749900), '₹27,499');
      expect(rupees(12345600), '₹1,23,456');
      expect(rupees(100000000), '₹10,00,000');
      expect(rupees(99900), '₹999');
    });
    test('keeps paise only when present and handles zero/negative', () {
      expect(rupees(150), '₹1.50');
      expect(rupees(0), '₹0');
      expect(rupees(-50000), '-₹500');
    });
  });

  test('discount percent and warranty label', () {
    expect(discountPercent(5990000, 2749900), 54);
    expect(discountPercent(1000, 2000), 0);
    expect(warrantyLabel(12), '1 year warranty');
    expect(warrantyLabel(18), '18 month warranty');
  });

  group('validators', () {
    test('Indian mobile numbers must start with 6-9 and have 10 digits', () {
      expect(isValidPhone('9822145678'), isTrue);
      expect(isValidPhone('5822145678'), isFalse);
      expect(isValidPhone('98221456'), isFalse);
      expect(validatePhone('12'), isNotNull);
    });
    test('pincode, email, password, name', () {
      expect(isValidPincode('413304'), isTrue);
      expect(isValidPincode('41330'), isFalse);
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('nope'), isFalse);
      expect(validatePassword('short'), isNotNull);
      expect(validatePassword('longenough1'), isNull);
      expect(validateName(' A '), isNotNull);
    });
  });

  group('models', () {
    test('catalogue filters serialise only what is set', () {
      const f = CatalogFilters(query: ' iphone ', brands: {'Apple'}, maxPricePaise: 2000000);
      final p = f.toRpc(limit: 10, offset: 20);
      expect(p['p_query'], 'iphone');
      expect(p['p_brands'], ['Apple']);
      expect(p['p_grades'], isNull);
      expect(p['p_max_price_paise'], 2000000);
      expect(p['p_limit'], 10);
      expect(p['p_offset'], 20);
      expect(f.activeCount, 2);
    });

    test('order payment window', () {
      final base = {
        'id': 'o1', 'order_number': 'BPW-2026-01001', 'status': 'pending_payment', 'payment_method': 'razorpay', 'payment_status': 'unpaid',
        'fulfillment_type': 'delivery', 'total_paise': 100000, 'items': [], 'history': [],
      };
      final open = Order.fromJson({...base, 'expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String()});
      final expired = Order.fromJson({...base, 'expires_at': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String()});
      expect(open.canPay(), isTrue);
      expect(expired.canPay(), isFalse);
      expect(open.canCancel, isTrue);
      expect(Order.fromJson({...base, 'status': 'packed'}).canCancel, isFalse);
    });

    test('store settings never invent a whatsapp number', () {
      expect(const StoreSettings().whatsappNumber, isNull);
      expect(StoreSettings.fromJson({'whatsapp': '9822145678'}).whatsappNumber, '919822145678');
    });
  });
}
