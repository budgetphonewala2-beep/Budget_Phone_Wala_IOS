import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/services.dart';
import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/util/validators.dart';
import '../../core/widgets/widgets.dart';
import '../profile/address_form.dart';

enum _Phase { editing, placing, paying, confirming }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _coupon = TextEditingController();
  bool _pickup = false;
  bool _cod = false;
  String? _addressId;
  CouponQuote? _applied;
  String? _couponError;
  bool _couponBusy = false;
  DeliveryQuote? _quote;
  String _quoteKey = '';
  _Phase _phase = _Phase.editing;
  String? _error;
  String _idempotencyKey = const Uuid().v4();
  PlacedOrder? _placed; // an order exists on the server; retry resumes it instead of creating another
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _coupon.dispose();
    super.dispose();
  }

  List<CartLine> _items() {
    final sel = ref.read(checkoutSelectionProvider);
    final lines = ref.read(cartProvider).value ?? const <CartLine>[];
    final chosen = sel.isEmpty ? lines : lines.where((l) => sel.contains(l.unitId)).toList();
    return chosen;
  }

  int get _subtotal => _items().where((l) => l.available).fold(0, (a, b) => a + b.pricePaise);
  int get _discount => _applied?.valid == true ? _applied!.discountPaise : 0;

  Future<void> _refreshQuote(Address? addr, StoreSettings s) async {
    final key = '${_pickup ? 'p' : 'd'}|${addr?.pincode}|${_subtotal - _discount}';
    if (key == _quoteKey) return;
    _quoteKey = key;
    try {
      final q = await ref.read(orderRepoProvider).quoteDelivery(pincode: addr?.pincode, subtotalPaise: _subtotal - _discount, pickup: _pickup);
      if (mounted && key == _quoteKey) setState(() => _quote = q);
    } catch (_) {
      if (mounted && key == _quoteKey) setState(() => _quote = null);
    }
  }

  int _tax(StoreSettings s) {
    final base = _subtotal - _discount;
    if (s.taxMode == 'exclusive') return (base * s.taxRateBps / 10000).round();
    return 0;
  }

  int _total(StoreSettings s) => _subtotal - _discount + (_quote?.feePaise ?? 0) + (_cod ? s.codFeePaise : 0) + _tax(s);

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.length < 3) return;
    setState(() { _couponBusy = true; _couponError = null; });
    try {
      final q = await ref.read(orderRepoProvider).quoteCoupon(code, _subtotal);
      if (!mounted) return;
      setState(() { if (q.valid) { _applied = q; _quoteKey = ''; } else { _couponError = q.message; } });
    } catch (e) {
      if (mounted) setState(() => _couponError = toAppException(e).message);
    } finally {
      if (mounted) setState(() => _couponBusy = false);
    }
  }

  Future<void> _addAddress() async {
    final saved = await showAddressSheet(context, ref);
    if (saved) {
      ref.invalidate(addressesProvider);
      final list = await ref.read(addressesProvider.future);
      if (mounted && list.isNotEmpty) setState(() { _addressId = list.first.id; _quoteKey = ''; });
    }
  }

  Future<void> _place(StoreSettings s, Profile profile) async {
    setState(() => _error = null);
    final items = _items().where((l) => l.available).toList();
    if (items.isEmpty) return;
    if (!_pickup && _addressId == null) {
      setState(() => _error = 'Choose or add a delivery address.');
      return;
    }
    if (_pickup && !(_form.currentState?.validate() ?? false)) return;
    if (_quote?.serviceable == false) {
      setState(() => _error = _quote?.reason ?? 'Delivery is not available for this address.');
      return;
    }
    setState(() => _phase = _Phase.placing);
    try {
      final repo = ref.read(orderRepoProvider);
      var placed = _placed;
      if (placed == null) {
        placed = await repo.placeOrder(
          idempotencyKey: _idempotencyKey, unitIds: items.map((e) => e.unitId).toList(), pickup: _pickup,
          paymentMethod: _cod ? 'cod' : 'razorpay', addressId: _pickup ? null : _addressId,
          coupon: _applied?.valid == true ? _applied!.code : null,
          contact: _pickup ? {'name': _name.text.trim(), 'phone': _phone.text.trim()} : null,
        );
        _placed = placed;
      } else if (placed.requiresPayment) {
        placed = await repo.resumePayment(placed.orderId);
        _placed = placed;
      }
      if (!placed.requiresPayment) {
        await _afterSuccess(items, placed, cod: true);
        return;
      }
      await _payOnline(placed, items, profile);
    } catch (e) {
      final ex = toAppException(e);
      if (ex.code == 'ERROR') ref.read(errorReporterProvider).report(e, null, operation: 'place_order', category: 'checkout');
      if (ex.code == 'UNAVAILABLE') ref.invalidate(cartProvider);
      if (ex.code == 'BAD_COUPON') _applied = null;
      if (mounted) setState(() { _phase = _Phase.editing; _error = ex.message; });
    }
  }

  Future<void> _payOnline(PlacedOrder placed, List<CartLine> items, Profile profile) async {
    setState(() => _phase = _Phase.paying);
    // prefill the payment sheet with who is receiving the phone, so the shopper never retypes it
    final addr = (ref.read(addressesProvider).value ?? const <Address>[]).where((a) => a.id == _addressId).firstOrNull;
    final name = _pickup ? _name.text.trim() : (addr?.fullName.isNotEmpty == true ? addr!.fullName : profile.fullName);
    final phone = _pickup ? _phone.text.trim() : (addr?.phone.isNotEmpty == true ? addr!.phone : profile.phone);
    final outcome = await ref.read(paymentLauncherProvider).pay(
          keyId: placed.razorpayKey!, razorpayOrderId: placed.razorpayOrderId!, amountPaise: placed.totalPaise,
          name: name, description: 'Order ${placed.orderNumber}',
          contact: phone, email: profile.email.isEmpty ? null : profile.email,
        );
    if (!mounted) return;
    switch (outcome) {
      case PaymentFailure f:
        if (!f.cancelled) ref.read(errorReporterProvider).report(f.message, null, operation: 'razorpay_checkout', category: 'payment');
        setState(() { _phase = _Phase.editing; _error = f.cancelled ? 'Payment was cancelled. Your phone is held for a few minutes, you can try again.' : '${f.message} You can try again.'; });
      case PaymentSuccess ok:
        setState(() => _phase = _Phase.confirming);
        try {
          await ref.read(orderRepoProvider).verifyPayment(razorpayOrderId: ok.orderId, paymentId: ok.paymentId, signature: ok.signature);
        } catch (_) {
          // network hiccup: the order may still be confirmed by the server, so fall through to the status check
        }
        await _confirmPaid(items, placed);
    }
  }

  /// Success is decided by the order's payment status from the server, never by the client callback.
  Future<void> _confirmPaid(List<CartLine> items, PlacedOrder placed) async {
    final repo = ref.read(orderRepoProvider);
    for (var i = 0; i < 4; i++) {
      final orders = await repo.orders().catchError((_) => <Order>[]);
      final o = orders.where((e) => e.id == placed.orderId).firstOrNull;
      if (o != null && o.isPaidOnline) {
        await _afterSuccess(items, placed, cod: false);
        return;
      }
      if (o != null && o.status == 'cancelled') break;
      await repo.syncPayment(placed.razorpayOrderId!).catchError((_) => '');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.editing;
      _error = 'We received your payment details but could not confirm them yet. Open Orders in a minute to see the result. Do not pay again.';
    });
    ref.invalidate(ordersProvider);
  }

  Future<void> _afterSuccess(List<CartLine> items, PlacedOrder placed, {required bool cod}) async {
    final cart = ref.read(cartRepoProvider);
    for (final i in items) {
      await cart.remove(i.unitId).catchError((_) {});
    }
    ref.read(checkoutSelectionProvider.notifier).clear();
    ref.invalidate(cartProvider);
    ref.invalidate(ordersProvider);
    if (mounted) context.go('/checkout/success?order=${Uri.encodeComponent(placed.orderNumber)}&cod=${cod ? 1 : 0}');
  }

  Future<void> _cancelHeldOrder() async {
    final p = _placed;
    if (p == null) return;
    try {
      await ref.read(orderRepoProvider).cancel(p.orderId, reason: 'Cancelled from checkout');
      _placed = null;
      _idempotencyKey = const Uuid().v4();
      ref.invalidate(ordersProvider);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = toAppException(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const StoreSettings();
    final profile = ref.watch(profileProvider).value ?? const Profile();
    final addresses = ref.watch(addressesProvider);
    final cartAsync = ref.watch(cartProvider);
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    if (!_prefilled && !profile.isEmpty) {
      _name.text = profile.fullName;
      _phone.text = profile.phone;
      _prefilled = true;
    }
    final addrList = addresses.value ?? const <Address>[];
    if (_addressId == null && addrList.isNotEmpty) _addressId = (addrList.where((a) => a.isDefault).firstOrNull ?? addrList.first).id;
    final addr = addrList.where((a) => a.id == _addressId).firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && cartAsync.hasValue) _refreshQuote(addr, settings); });
    final items = cartAsync.hasValue ? _items() : const <CartLine>[];
    final soldCount = items.where((l) => !l.available).length;
    final busy = _phase != _Phase.editing;
    final total = _total(settings);
    final codOk = !_pickup && settings.codEnabled && (_quote?.codAllowed ?? true);
    if (_cod && !codOk) _cod = false;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Stack(children: [
        Column(children: [
          Expanded(
            child: AsyncBody<List<CartLine>>(
              value: cartAsync,
              onRetry: () => ref.invalidate(cartProvider),
              data: (_) => items.isEmpty
                  ? EmptyState(icon: Icons.shopping_cart_outlined, title: 'Nothing to check out', body: 'Add a phone to your cart first.', actionLabel: 'Browse phones', onAction: () => context.go('/'))
                  : Form(
                      key: _form,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        if (_error != null) _Banner(_error!, error: true, action: _placed != null ? ('Cancel this order', _cancelHeldOrder) : null),
                        if (soldCount > 0) const _Banner('One or more phones were just sold. Go back to your cart and remove them.', error: true),
                        Text('How do you want it?', style: t.titleMedium),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(value: false, label: const Text('Home delivery'), enabled: settings.deliveryEnabled),
                            ButtonSegment(value: true, label: const Text('Store pickup'), enabled: settings.pickupEnabled),
                          ],
                          selected: {_pickup},
                          onSelectionChanged: busy ? null : (v) => setState(() { _pickup = v.first; _quoteKey = ''; if (_pickup) _cod = false; }),
                        ),
                        const SizedBox(height: 16),
                        if (_pickup) ...[
                          Text('Your details', style: t.titleMedium),
                          const SizedBox(height: 8),
                          AppTextField(label: 'Full name', controller: _name, validator: validateName, textInputAction: TextInputAction.next),
                          const SizedBox(height: 12),
                          AppTextField(label: 'Mobile number', controller: _phone, validator: validatePhone, keyboardType: TextInputType.phone, prefixText: '+91 ', maxLength: 10, helper: 'We will contact you on this number'),
                          const SizedBox(height: 8),
                          _PickupInfo(settings.pickupLocation, settings.address),
                        ] else ...[
                          Row(children: [
                            Expanded(child: Text('Delivery address', style: t.titleMedium)),
                            TextButton.icon(onPressed: busy ? null : _addAddress, icon: const Icon(Icons.add), label: const Text('Add new')),
                          ]),
                          if (addresses.isLoading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                          else if (addrList.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Add a delivery address to continue.', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))))
                          else for (final a in addrList)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: a.id == _addressId ? s.primaryContainer : s.surface,
                                shape: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder, side: BorderSide(color: a.id == _addressId ? s.primary : s.outlineVariant, width: a.id == _addressId ? 2 : 1)),
                                child: InkWell(
                                  customBorder: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder),
                                  onTap: busy ? null : () => setState(() { _addressId = a.id; _quoteKey = ''; }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${a.fullName} • ${a.label}', style: t.titleSmall),
                                      Text(a.oneLine, style: t.bodyMedium),
                                      Text('+91 ${a.phone}', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                          if (addr != null && _quote != null && !_quote!.serviceable) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_quote!.reason ?? 'We do not deliver to this pincode', style: t.bodyMedium?.copyWith(color: s.error))),
                        ],
                        const SizedBox(height: 16),
                        Text('Payment', style: t.titleMedium),
                        const SizedBox(height: 8),
                        RadioGroup<bool>(
                          groupValue: _cod,
                          onChanged: (v) { if (!busy && v != null) setState(() => _cod = v); },
                          child: Column(children: [
                            const RadioListTile<bool>(value: false, title: Text('Pay online'), subtitle: Text('UPI, cards, netbanking and wallets via Razorpay'), contentPadding: EdgeInsets.zero),
                            if (codOk) RadioListTile<bool>(value: true, title: const Text('Cash on delivery'), subtitle: Text('Pay when your phone arrives${settings.codFeePaise > 0 ? ' (+${rupees(settings.codFeePaise)} fee)' : ''}'), contentPadding: EdgeInsets.zero),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text('Coupon', style: t.titleMedium),
                        const SizedBox(height: 8),
                        if (_applied?.valid == true)
                          Container(
                            padding: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(color: s.tertiaryContainer, borderRadius: AppShapes.controlBorder),
                            child: Row(children: [
                              Icon(Icons.check_circle_outline, color: s.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${_applied!.code} saved you ${rupees(_applied!.discountPaise)}', style: t.labelLarge?.copyWith(color: s.onTertiaryContainer))),
                              TextButton(onPressed: busy ? null : () => setState(() { _applied = null; _quoteKey = ''; }), child: const Text('Remove')),
                            ]),
                          )
                        else
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: TextField(controller: _coupon, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'Coupon code', errorText: _couponError))),
                            const SizedBox(width: 10),
                            Padding(padding: const EdgeInsets.only(top: 4), child: SizedBox(width: 96, child: AppButton('Apply', _couponBusy || busy ? null : _applyCoupon, style: BtnStyle.tonal, loading: _couponBusy))),
                          ]),
                        const SizedBox(height: 16),
                        Text('Order summary', style: t.titleMedium),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              for (final l in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(children: [
                                    ClipRRect(borderRadius: AppShapes.controlBorder, child: SizedBox(width: 44, height: 44, child: RemoteImage(l.image))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium)),
                                    const SizedBox(width: 8),
                                    Text(rupees(l.pricePaise), style: t.titleSmall),
                                  ]),
                                ),
                              const Divider(),
                              const SizedBox(height: 8),
                              _Line('Subtotal', rupees(_subtotal)),
                              if (_discount > 0) _Line('Coupon discount', '-${rupees(_discount)}', good: true),
                              _Line('Delivery', _pickup ? (_quote == null || _quote!.feePaise == 0 ? 'Free (pickup)' : rupees(_quote!.feePaise)) : (addr == null ? 'Add an address' : (_quote == null ? '...' : (_quote!.feePaise == 0 ? 'Free' : rupees(_quote!.feePaise))))),
                              if (_cod && settings.codFeePaise > 0) _Line('Cash on delivery fee', rupees(settings.codFeePaise)),
                              if (_tax(settings) > 0) _Line('Tax', rupees(_tax(settings))),
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(children: [Expanded(child: Text('Total', style: t.titleMedium)), Text(rupees(total), style: t.headlineSmall)]),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.schedule, size: 18, color: s.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Once you place the order, your phone is held for ${settings.reservationMinutes} minutes so nobody else can buy it.', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant))),
                        ]),
                        const SizedBox(height: 8),
                        Text('The final amount is calculated and confirmed by our server when you place the order.', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                      ]),
                    ),
            ),
          ),
          Material(
            elevation: 8, color: s.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AppButton(
                    _cod ? 'Place order (pay on delivery)' : 'Pay ${rupees(total)} securely',
                    busy || items.isEmpty || soldCount > 0 || (!_pickup && addr == null) || (_quote?.serviceable == false) ? null : () => _place(settings, profile),
                    icon: _cod ? Icons.local_shipping_outlined : Icons.lock_outline,
                  ),
                  const SizedBox(height: 6),
                  Text(_cod ? 'Pay the courier in cash on delivery' : 'UPI, cards, netbanking and wallets via Razorpay', style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
        ]),
        if (busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(switch (_phase) { _Phase.placing => 'Securing your phone...', _Phase.paying => 'Opening secure payment...', _ => 'Confirming your payment...' }, style: t.titleSmall),
                      Text('Please do not close the app', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.good = false});
  final String label, value;
  final bool good;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))),
        Text(value, style: t.titleSmall?.copyWith(color: good ? s.tertiary : s.onSurface)),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.error = false, this.action});
  final String text;
  final bool error;
  final (String, VoidCallback)? action;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: error ? s.errorContainer : s.surfaceContainerHigh, borderRadius: AppShapes.controlBorder),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, color: error ? s.onErrorContainer : s.onSurface),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: error ? s.onErrorContainer : s.onSurface))),
        ]),
        if (action != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: action!.$2, child: Text(action!.$1))),
      ]),
    );
  }
}

class _PickupInfo extends StatelessWidget {
  const _PickupInfo(this.loc, this.address);
  final Map<String, dynamic> loc;
  final String address;
  @override
  Widget build(BuildContext context) {
    final name = (loc['name'] ?? '').toString();
    final addr = (loc['address'] ?? address).toString();
    final ins = (loc['instructions'] ?? '').toString();
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pickup location', style: t.titleSmall),
          const SizedBox(height: 4),
          Text([if (name.isNotEmpty) name, if (addr.isNotEmpty) addr].join('\n').isEmpty ? 'The shop will confirm the pickup location after you order.' : [if (name.isNotEmpty) name, if (addr.isNotEmpty) addr].join('\n'), style: t.bodyMedium),
          if (ins.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ins, style: t.bodySmall)),
        ]),
      ),
    );
  }
}
