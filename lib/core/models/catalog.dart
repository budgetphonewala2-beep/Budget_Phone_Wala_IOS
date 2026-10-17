int _i(dynamic v, [int d = 0]) => v == null ? d : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? d);
String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
bool _b(dynamic v) => v == true;
List<T> _list<T>(dynamic v, T Function(dynamic) f) => v is List ? v.map(f).toList() : <T>[];

/// Customer-facing model page (grouped listing): several physical units can sit under one model.
class CatalogModel {
  const CatalogModel({
    required this.id, required this.slug, required this.name, required this.brand, required this.fromPricePaise,
    required this.maxMrpPaise, required this.availableUnits, required this.network, required this.storages,
    required this.colors, required this.grades, required this.maxBattery, required this.warrantyMonths,
    this.primaryImage, this.description = '', this.display, this.camera, this.batteryMah, this.os, this.minRam,
  });

  final String id, slug, name, brand, network, description;
  final int fromPricePaise, maxMrpPaise, availableUnits, maxBattery, warrantyMonths;
  final List<int> storages;
  final List<String> colors, grades;
  final String? primaryImage, display, camera, os;
  final int? batteryMah, minRam;

  int get discountPct => maxMrpPaise > fromPricePaise ? ((maxMrpPaise - fromPricePaise) * 100 ~/ maxMrpPaise) : 0;
  String get title => '$brand $name';

  factory CatalogModel.fromJson(Map<String, dynamic> j) => CatalogModel(
        id: _s(j['id']), slug: _s(j['slug']), name: _s(j['name']), brand: _s(j['brand']),
        fromPricePaise: _i(j['from_price_paise']), maxMrpPaise: _i(j['max_mrp_paise']),
        availableUnits: _i(j['available_units']), network: _s(j['network'], '4G'),
        storages: _list(j['storages'], (e) => _i(e)), colors: _list(j['colors'], (e) => _s(e)),
        grades: _list(j['grades'], (e) => _s(e)), maxBattery: _i(j['max_battery']),
        warrantyMonths: _i(j['warranty_months'], 12), primaryImage: j['primary_image'] as String?,
        description: _s(j['description']), display: j['display'] as String?, camera: j['camera'] as String?,
        batteryMah: j['battery_mah'] == null ? null : _i(j['battery_mah']), os: j['os'] as String?,
        minRam: j['min_ram'] == null ? null : _i(j['min_ram']),
      );
}

class CatalogUnit {
  const CatalogUnit({
    required this.id, required this.unitCode, required this.modelId, required this.storageGb, required this.ramGb,
    required this.color, required this.grade, required this.battery, required this.pricePaise, required this.mrpPaise,
    required this.hasBill, required this.hasBox, required this.accessories, required this.defects,
    required this.warrantyMonths, required this.images, this.inspectionNotes = '', this.inspection = const {},
  });

  final String id, unitCode, modelId, color, grade, accessories, defects, inspectionNotes;
  final int storageGb, ramGb, battery, pricePaise, mrpPaise, warrantyMonths;
  final bool hasBill, hasBox;
  final List<String> images;
  final Map<String, dynamic> inspection;

  int get discountPct => mrpPaise > pricePaise ? ((mrpPaise - pricePaise) * 100 ~/ mrpPaise) : 0;

  factory CatalogUnit.fromJson(Map<String, dynamic> j) => CatalogUnit(
        id: _s(j['id']), unitCode: _s(j['unit_code']), modelId: _s(j['model_id']), storageGb: _i(j['storage_gb']),
        ramGb: _i(j['ram_gb']), color: _s(j['color']), grade: _s(j['condition_grade'], 'A'),
        battery: _i(j['battery_health_pct']), pricePaise: _i(j['selling_price_paise']), mrpPaise: _i(j['mrp_paise']),
        hasBill: _b(j['has_bill']), hasBox: _b(j['has_box']), accessories: _s(j['accessories']),
        defects: _s(j['defects_notes']), warrantyMonths: _i(j['warranty_months'], 12),
        images: _list(j['images'], (e) => _s(e)), inspectionNotes: _s(j['inspection_notes']),
        inspection: j['inspection'] is Map ? Map<String, dynamic>.from(j['inspection'] as Map) : const {},
      );
}

class ModelDetail {
  const ModelDetail({required this.model, required this.images, required this.units});
  final CatalogModel model;
  final List<String> images;
  final List<CatalogUnit> units;

  factory ModelDetail.fromJson(Map<String, dynamic> j) => ModelDetail(
        model: CatalogModel.fromJson(Map<String, dynamic>.from(j['model'] as Map)),
        images: _list(j['images'], (e) => _s(e)),
        units: _list(j['units'], (e) => CatalogUnit.fromJson(Map<String, dynamic>.from(e as Map))),
      );
}

class CatalogPage {
  const CatalogPage({required this.total, required this.items});
  final int total;
  final List<CatalogModel> items;
  factory CatalogPage.fromJson(Map<String, dynamic> j) => CatalogPage(
        total: _i(j['total']),
        items: _list(j['items'], (e) => CatalogModel.fromJson(Map<String, dynamic>.from(e as Map))),
      );
}

class CatalogFilters {
  const CatalogFilters({
    this.query = '', this.brands = const {}, this.maxPricePaise, this.grades = const {}, this.storage = const {},
    this.minRam, this.minBattery, this.network = const {}, this.sort = 'new',
  });

  final String query;
  final Set<String> brands, grades, network;
  final Set<int> storage;
  final int? maxPricePaise, minRam, minBattery;
  final String sort;

  int get activeCount =>
      brands.length + grades.length + storage.length + network.length +
      (maxPricePaise != null ? 1 : 0) + (minRam != null ? 1 : 0) + (minBattery != null ? 1 : 0);

  CatalogFilters copyWith({
    String? query, Set<String>? brands, Set<String>? grades, Set<String>? network, Set<int>? storage,
    int? maxPricePaise, int? minRam, int? minBattery, String? sort,
    bool clearMaxPrice = false, bool clearMinRam = false, bool clearMinBattery = false,
  }) =>
      CatalogFilters(
        query: query ?? this.query, brands: brands ?? this.brands, grades: grades ?? this.grades,
        network: network ?? this.network, storage: storage ?? this.storage,
        maxPricePaise: clearMaxPrice ? null : (maxPricePaise ?? this.maxPricePaise),
        minRam: clearMinRam ? null : (minRam ?? this.minRam),
        minBattery: clearMinBattery ? null : (minBattery ?? this.minBattery), sort: sort ?? this.sort,
      );

  Map<String, dynamic> toRpc({int limit = 24, int offset = 0}) => {
        'p_query': query.trim().isEmpty ? null : query.trim(),
        'p_brands': brands.isEmpty ? null : brands.toList(),
        'p_max_price_paise': maxPricePaise,
        'p_grades': grades.isEmpty ? null : grades.toList(),
        'p_storage': storage.isEmpty ? null : storage.toList(),
        'p_min_ram': minRam,
        'p_min_battery': minBattery,
        'p_network': network.isEmpty ? null : network.toList(),
        'p_sort': sort,
        'p_limit': limit,
        'p_offset': offset,
      };

  @override
  bool operator ==(Object other) =>
      other is CatalogFilters && other.query == query && _setEq(other.brands, brands) && _setEq(other.grades, grades) &&
      _setEq(other.network, network) && _setEq(other.storage, storage) && other.maxPricePaise == maxPricePaise &&
      other.minRam == minRam && other.minBattery == minBattery && other.sort == sort;

  @override
  int get hashCode => Object.hash(query, brands.length, grades.length, network.length, storage.length, maxPricePaise, minRam, minBattery, sort);
}

bool _setEq<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

class StoreSettings {
  const StoreSettings({
    this.shopName = 'BudgetPhonewala', this.address = '', this.phone = '', this.whatsapp = '', this.instagram = '',
    this.hours = '', this.gst = '', this.codEnabled = false, this.codMinPaise = 0, this.codMaxPaise,
    this.pickupEnabled = true, this.deliveryEnabled = true, this.pickupLocation = const {}, this.defaultWarrantyMonths = 12,
    this.reservationMinutes = 10, this.supportEmail = '', this.codFeePaise = 0, this.taxMode = 'none', this.taxRateBps = 0,
  });

  final String shopName, address, phone, whatsapp, instagram, hours, gst, supportEmail;
  final bool codEnabled, pickupEnabled, deliveryEnabled;
  final int codMinPaise, defaultWarrantyMonths, reservationMinutes, codFeePaise, taxRateBps;
  final String taxMode;
  final int? codMaxPaise;
  final Map<String, dynamic> pickupLocation;

  /// WhatsApp wa.me number with country code, or null when the owner has not configured one.
  String? get whatsappNumber {
    final d = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return null;
    return d.length == 10 ? '91$d' : d;
  }

  String? get callNumber {
    final d = (phone.isNotEmpty ? phone : whatsapp).replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return null;
    return d.length == 10 ? '91$d' : d;
  }

  factory StoreSettings.fromJson(Map<String, dynamic> j) => StoreSettings(
        shopName: _s(j['shop_name'], 'BudgetPhonewala'), address: _s(j['address']), phone: _s(j['phone']),
        whatsapp: _s(j['whatsapp']), instagram: _s(j['instagram']), hours: _s(j['opening_hours']), gst: _s(j['gst_number']),
        supportEmail: _s(j['support_email']), codEnabled: _b(j['cod_enabled']), codMinPaise: _i(j['cod_min_paise']),
        codMaxPaise: j['cod_max_paise'] == null ? null : _i(j['cod_max_paise']), pickupEnabled: j['pickup_enabled'] != false,
        deliveryEnabled: j['delivery_enabled'] != false,
        pickupLocation: j['pickup_location'] is Map ? Map<String, dynamic>.from(j['pickup_location'] as Map) : const {},
        defaultWarrantyMonths: _i(j['default_warranty_months'], 12), reservationMinutes: _i(j['reservation_minutes'], 10),
        codFeePaise: _i(j['cod_fee_paise']), taxMode: _s(j['tax_mode'], 'none'), taxRateBps: _i(j['tax_rate_bps']),
      );
}

class HomeBanner {
  const HomeBanner(this.title, this.subtitle);
  final String title, subtitle;
  factory HomeBanner.fromJson(Map<String, dynamic> j) => HomeBanner(_s(j['title']), _s(j['subtitle']));
}

class Faq {
  const Faq(this.q, this.a);
  final String q, a;
  factory Faq.fromJson(Map<String, dynamic> j) => Faq(_s(j['q']), _s(j['a']));
}
