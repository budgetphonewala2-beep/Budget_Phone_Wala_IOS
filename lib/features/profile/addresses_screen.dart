import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';
import 'address_form.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showAddressSheet(context, ref)) ref.invalidate(addressesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: AsyncBody<List<Address>>(
        value: list,
        onRetry: () => ref.invalidate(addressesProvider),
        data: (items) => items.isEmpty
            ? const EmptyState(icon: Icons.home_outlined, title: 'No saved addresses', body: 'Add an address to check out faster.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final a = items[i];
                  final t = Theme.of(context).textTheme;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${a.fullName} • ${a.label}', style: t.titleSmall)),
                          if (a.isDefault) const StatusPill('Default', tone: Tone.brand),
                        ]),
                        const SizedBox(height: 4),
                        Text(a.oneLine, style: t.bodyMedium),
                        Text('+91 ${a.phone}', style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          TextButton(onPressed: () async { if (await showAddressSheet(context, ref, existing: a)) ref.invalidate(addressesProvider); }, child: const Text('Edit')),
                          TextButton(
                            onPressed: () async {
                              try {
                                await ref.read(accountRepoProvider).deleteAddress(a.id);
                                ref.invalidate(addressesProvider);
                              } catch (e) {
                                if (context.mounted) showSnack(context, toAppException(e).message);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
