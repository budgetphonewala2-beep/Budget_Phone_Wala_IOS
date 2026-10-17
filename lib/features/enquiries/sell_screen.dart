import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/util/actions.dart';
import '../../core/util/format.dart';
import '../../core/util/validators.dart';
import '../../core/widgets/widgets.dart';
import '../auth/guest_prompt.dart';

/// Sell or exchange enquiry: details, optional private photos, then the shop replies with an offer.
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});
  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final _form0 = GlobalKey<FormState>();
  final _form1 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _price = TextEditingController();
  int _step = 0;
  bool _exchange = false, _busy = false, _prefilled = false;
  int _storage = 128;
  double _battery = 85;
  String _condition = 'Good';
  bool _box = false, _bill = false, _charger = true;
  String? _wantModelId, _wantTitle;
  final List<({Uint8List bytes, String contentType})> _photos = [];
  String? _error, _done;

  @override
  void dispose() {
    for (final c in [_name, _phone, _brand, _model, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    if (_photos.length >= 6) return;
    final f = await ImagePicker().pickMultiImage(limit: 6 - _photos.length, maxWidth: 1600, imageQuality: 82);
    for (final x in f) {
      final b = await x.readAsBytes();
      if (b.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) showSnack(context, 'A photo was larger than 5 MB and was skipped.');
        continue;
      }
      final ext = x.name.toLowerCase();
      _photos.add((bytes: b, contentType: ext.endsWith('.png') ? 'image/png' : (ext.endsWith('.webp') ? 'image/webp' : 'image/jpeg')));
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final no = await ref.read(enquiryRepoProvider).submit({
        'type': _exchange ? 'exchange' : 'sell', 'contact_name': _name.text.trim(), 'contact_phone': _phone.text.trim(),
        'brand': _brand.text.trim(), 'model': _model.text.trim(), 'storage_gb': _storage, 'battery_health_pct': _battery.round(),
        'condition': _condition, 'accessories': [if (_box) 'Box', if (_bill) 'Bill', if (_charger) 'Charger'].join(', '),
        'expected_price_paise': (int.tryParse(_price.text) ?? 0) * 100, 'exchange_model_id': _exchange ? _wantModelId : null,
      }, photos: _photos);
      ref.invalidate(enquiriesProvider);
      if (mounted) setState(() { _done = no; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _error = toAppException(e).message; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isSignedInProvider)) {
      return const SafeArea(child: GuestPrompt(title: 'Sign in to sell or exchange', body: 'We need an account so we can reply to you with an offer and keep your photos private.', icon: Icons.sell_outlined));
    }
    final profile = ref.watch(profileProvider).value;
    if (!_prefilled && profile != null && !profile.isEmpty) {
      _name.text = profile.fullName;
      _phone.text = profile.phone;
      _prefilled = true;
    }
    final settings = ref.watch(settingsProvider).value ?? const StoreSettings();
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;

    if (_done != null) {
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline, size: 72, color: s.tertiary),
              const SizedBox(height: 16),
              Text('Request sent', style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(_done!, style: t.titleLarge?.copyWith(color: s.primary)),
              const SizedBox(height: 12),
              Text(_photos.isEmpty ? 'Send clear photos of your phone (front, back, screen on) on WhatsApp with this request number. We will reply with a final offer.' : 'We received your details and photos. We will review them and reply with an offer.', textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant)),
              const SizedBox(height: 24),
              if (_photos.isEmpty) AppButton('Send photos on WhatsApp', () => openWhatsApp(context, settings, 'Hello! I submitted sell/exchange request $_done. I am sending photos of my phone.'), icon: Icons.chat_outlined),
              const SizedBox(height: 10),
              AppButton('Track my request', () => context.go('/orders'), style: BtnStyle.outlined),
              TextButton(onPressed: () => setState(() { _done = null; _step = 0; _brand.clear(); _model.clear(); _price.clear(); _photos.clear(); _wantModelId = null; }), child: const Text('Submit another phone')),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Sell or exchange', style: t.headlineMedium),
            const SizedBox(height: 4),
            Text('Step ${_step + 1} of 3', style: t.labelLarge?.copyWith(color: s.onSurfaceVariant)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 6, backgroundColor: s.surfaceContainerHighest)),
            const SizedBox(height: 16),
            if (_step == 0) Form(key: _form0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('What would you like to do?', style: t.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Sell for cash')), ButtonSegment(value: true, label: Text('Exchange'))], selected: {_exchange}, onSelectionChanged: (v) => setState(() => _exchange = v.first)),
              const SizedBox(height: 16),
              Text('Your contact', style: t.titleMedium),
              const SizedBox(height: 8),
              AppTextField(label: 'Your name', controller: _name, validator: validateName),
              const SizedBox(height: 12),
              AppTextField(label: 'Mobile number', controller: _phone, validator: validatePhone, keyboardType: TextInputType.phone, prefixText: '+91 ', maxLength: 10),
            ])),
            if (_step == 1) Form(key: _form1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppTextField(label: 'Brand (e.g. Samsung)', controller: _brand, validator: (v) => (v == null || v.trim().length < 2) ? 'Enter the brand' : null),
              const SizedBox(height: 12),
              AppTextField(label: 'Model (e.g. Galaxy M34)', controller: _model, validator: (v) => (v == null || v.trim().length < 2) ? 'Enter the model' : null),
              const SizedBox(height: 16),
              Text('Storage', style: t.titleSmall),
              Wrap(spacing: 8, children: [for (final x in const [32, 64, 128, 256, 512]) ChoiceChip(label: Text('${x}GB'), selected: _storage == x, onSelected: (_) => setState(() => _storage = x))]),
              const SizedBox(height: 12),
              Text('Battery health: ${_battery.round()}%', style: t.titleSmall),
              Slider(value: _battery, min: 50, max: 100, divisions: 50, label: '${_battery.round()}%', onChanged: (v) => setState(() => _battery = v)),
              Text('Condition', style: t.titleSmall),
              Wrap(spacing: 8, children: [for (final c in const ['Like new', 'Good', 'Fair', 'Has issues']) ChoiceChip(label: Text(c), selected: _condition == c, onSelected: (_) => setState(() => _condition = c))]),
              const SizedBox(height: 12),
              Text('What you have', style: t.titleSmall),
              Wrap(spacing: 8, children: [
                FilterChip(label: const Text('Box'), selected: _box, onSelected: (v) => setState(() => _box = v)),
                FilterChip(label: const Text('Bill'), selected: _bill, onSelected: (v) => setState(() => _bill = v)),
                FilterChip(label: const Text('Charger'), selected: _charger, onSelected: (v) => setState(() => _charger = v)),
              ]),
              const SizedBox(height: 16),
              AppTextField(label: 'Your expected price', controller: _price, prefixText: '₹ ', keyboardType: TextInputType.number, maxLength: 6, validator: (v) => (int.tryParse(v ?? '') ?? 0) < 500 ? 'Enter the price you expect' : null),
              if (_exchange) ...[
                const SizedBox(height: 16),
                Text('Phone you want in exchange', style: t.titleSmall),
                const SizedBox(height: 6),
                ref.watch(newArrivalsProvider).when(
                      data: (p) => Wrap(spacing: 8, runSpacing: 4, children: [for (final m in p.items) ChoiceChip(label: Text('${m.title} from ${rupees(m.fromPricePaise)}'), selected: _wantModelId == m.id, onSelected: (_) => setState(() { _wantModelId = m.id; _wantTitle = m.title; }))]),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(toAppException(e).message),
                    ),
              ],
              const SizedBox(height: 16),
              Text('Photos (optional, private)', style: t.titleSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_photos[i].bytes, width: 72, height: 72, fit: BoxFit.cover)),
                    Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => _photos.removeAt(i)), child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                  ]),
                if (_photos.length < 6) OutlinedButton.icon(onPressed: _pick, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 72)), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add')),
              ]),
            ])),
            if (_step == 2) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Review and send', style: t.titleMedium),
              const SizedBox(height: 8),
              _R('Type', _exchange ? 'Exchange' : 'Sell for cash'),
              _R('Name', _name.text.trim()),
              _R('Mobile', '+91 ${_phone.text}'),
              _R('Phone', '${_brand.text.trim()} ${_model.text.trim()}, ${_storage}GB'),
              _R('Battery and condition', '${_battery.round()}%, $_condition'),
              _R('You have', [if (_box) 'Box', if (_bill) 'Bill', if (_charger) 'Charger'].join(', ').ifEmpty('Phone only')),
              _R('Your asking price', rupees((int.tryParse(_price.text) ?? 0) * 100)),
              if (_exchange && _wantTitle != null) _R('You want', _wantTitle!),
              _R('Photos', '${_photos.length}'),
              const SizedBox(height: 8),
              Text('We will check your details and message you with a final offer. Your photos are private to you and the shop.', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: s.error))),
            ]),
          ]),
        ),
        Material(
          elevation: 8, color: s.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (_step > 0) Expanded(child: AppButton('Back', () => setState(() { _step--; _error = null; }), style: BtnStyle.outlined)),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(_step < 2 ? 'Next' : 'Submit request', _busy ? null : () {
                  if (_step == 0) {
                    if (_form0.currentState!.validate()) setState(() => _step = 1);
                  } else if (_step == 1) {
                    if (!_form1.currentState!.validate()) return;
                    if (_exchange && _wantModelId == null) { showSnack(context, 'Pick the phone you want in exchange.'); return; }
                    setState(() => _step = 2);
                  } else if (_step == 2) {
                    _submit();
                  }
                }, loading: _busy),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String d) => isEmpty ? d : this;
}

class _R extends StatelessWidget {
  const _R(this.l, this.v);
  final String l, v;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(l, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(flex: 6, child: Text(v, style: Theme.of(context).textTheme.titleSmall)),
        ]),
      );
}
