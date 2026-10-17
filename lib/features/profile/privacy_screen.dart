import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';

/// Data access (export) and account deletion request. Orders and invoices are retained as the law requires.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});
  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(accountRepoProvider).exportMyData();
      await SharePlus.instance.share(ShareParams(text: const JsonEncoder.withIndent('  ').convert(data), subject: 'My BudgetPhonewala data'));
    } catch (e) {
      if (mounted) showSnack(context, toAppException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text('The shop will review your request. Your saved addresses, wishlist, cart and notifications will be removed. Past orders and invoices are kept for accounting and warranty, without your profile details.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep my account')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Request deletion'))],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountRepoProvider).requestAccountDeletion();
      if (mounted) showSnack(context, 'Deletion requested. We will confirm once it is processed.');
    } catch (e) {
      if (mounted) showSnack(context, toAppException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and data')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Your data', style: t.titleMedium),
        const SizedBox(height: 8),
        Text('We store your name, mobile number, email, addresses, orders and enquiries to run your orders. Card details are handled by Razorpay and never stored by us.', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
        const SizedBox(height: 16),
        AppButton('Download my data', _busy ? null : _export, style: BtnStyle.outlined, icon: Icons.download_outlined, loading: _busy),
        const SizedBox(height: 24),
        Text('Delete my account', style: t.titleMedium),
        const SizedBox(height: 8),
        Text('You can ask us to delete your account. Records we must keep by law, such as orders and invoices, are retained without your profile details.', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
        const SizedBox(height: 16),
        AppButton('Request account deletion', _busy ? null : _delete, style: BtnStyle.outlined, icon: Icons.delete_outline),
      ]),
    );
  }
}
