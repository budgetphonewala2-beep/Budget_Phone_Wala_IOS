import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/providers.dart';
import '../../core/util/validators.dart';
import '../../core/widgets/widgets.dart';

/// Add or edit an address in a bottom sheet. Returns true when saved.
Future<bool> showAddressSheet(BuildContext context, WidgetRef ref, {Address? existing}) async {
  final r = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => _AddressForm(existing: existing),
  );
  return r == true;
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({this.existing});
  final Address? existing;
  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? 'Home');
  late final _name = TextEditingController(text: widget.existing?.fullName ?? ref.read(profileProvider).value?.fullName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? ref.read(profileProvider).value?.phone ?? '');
  late final _line1 = TextEditingController(text: widget.existing?.line1 ?? '');
  late final _line2 = TextEditingController(text: widget.existing?.line2 ?? '');
  late final _landmark = TextEditingController(text: widget.existing?.landmark ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _state = TextEditingController(text: widget.existing?.state ?? '');
  late final _pin = TextEditingController(text: widget.existing?.pincode ?? '');
  late bool _default = widget.existing?.isDefault ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _name, _phone, _line1, _line2, _landmark, _city, _state, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final a = Address(
      id: widget.existing?.id ?? '', label: _label.text.trim().isEmpty ? 'Home' : _label.text.trim(), fullName: _name.text.trim(),
      phone: _phone.text.trim(), line1: _line1.text.trim(), line2: _line2.text.trim(), landmark: _landmark.text.trim(),
      city: _city.text.trim(), state: _state.text.trim(), pincode: _pin.text.trim(), isDefault: _default,
    );
    try {
      final repo = ref.read(accountRepoProvider);
      if (widget.existing == null) {
        await repo.addAddress(a);
      } else {
        await repo.updateAddress(a);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = toAppException(e).message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.existing == null ? 'Add address' : 'Edit address', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            AppTextField(label: 'Label (Home, Work)', controller: _label, textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            AppTextField(label: 'Full name', controller: _name, validator: validateName, textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            AppTextField(label: 'Mobile number', controller: _phone, validator: validatePhone, keyboardType: TextInputType.phone, prefixText: '+91 ', maxLength: 10),
            const SizedBox(height: 12),
            AppTextField(label: 'House, street and area', controller: _line1, validator: validateAddressLine, maxLines: 2),
            const SizedBox(height: 12),
            AppTextField(label: 'Apartment, floor (optional)', controller: _line2),
            const SizedBox(height: 12),
            AppTextField(label: 'Landmark (optional)', controller: _landmark),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AppTextField(label: 'City', controller: _city)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(label: 'Pincode', controller: _pin, validator: validatePincode, keyboardType: TextInputType.number, maxLength: 6)),
            ]),
            const SizedBox(height: 12),
            AppTextField(label: 'State', controller: _state),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Make this my default address'), value: _default, onChanged: (v) => setState(() => _default = v)),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            AppButton('Save address', _busy ? null : _save, loading: _busy),
          ]),
        ),
      ),
    );
  }
}
