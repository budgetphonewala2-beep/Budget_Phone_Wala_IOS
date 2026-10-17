import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/util/validators.dart';
import '../../core/widgets/widgets.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loaded = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(accountRepoProvider).saveProfile(fullName: _name.text, phone: _phone.text.trim());
      ref.invalidate(profileProvider);
      if (mounted) {
        showSnack(context, 'Profile saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = toAppException(e).message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final email = ref.read(gatewayProvider).userEmail ?? '';
    final p = profile.value;
    if (p != null && !_loaded) {
      _name.text = p.fullName;
      _phone.text = p.phone;
      _loaded = true;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: AsyncBody(
        value: profile,
        onRetry: () => ref.invalidate(profileProvider),
        data: (_) => Column(children: [
          Expanded(
            child: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text('These details prefill checkout. Your email comes from your sign-in and cannot be changed here.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                AppTextField(label: 'Full name', controller: _name, validator: validateName, textInputAction: TextInputAction.next),
                const SizedBox(height: 12),
                AppTextField(label: 'Mobile number', controller: _phone, validator: (v) => (v == null || v.isEmpty) ? null : validatePhone(v), keyboardType: TextInputType.phone, prefixText: '+91 ', maxLength: 10, helper: 'Used for delivery contact. It is not verified by OTP.'),
                const SizedBox(height: 12),
                AppTextField(label: 'Email', controller: TextEditingController(text: email), enabled: false),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ]),
            ),
          ),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: AppButton('Save changes', _busy ? null : _save, loading: _busy))),
        ]),
      ),
    );
  }
}
