import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../core/widgets/widgets.dart';

/// In-app notification history (server stored). Push delivery needs Firebase credentials from the owner.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(
          onPressed: () async {
            try {
              await ref.read(accountRepoProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            } catch (e) {
              if (context.mounted) showSnack(context, toAppException(e).message);
            }
          },
          child: const Text('Mark all read'),
        ),
      ]),
      body: AsyncBody<List<AppNotification>>(
        value: list,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) => items.isEmpty
            ? const EmptyState(icon: Icons.notifications_none, title: 'Nothing here yet', body: 'Order, payment, delivery and warranty updates will appear here.')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    return ListTile(
                      leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: n.read ? null : Theme.of(context).colorScheme.primary),
                      title: Text(n.title, style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text('${n.body}\n${formatDateTime(n.createdAt)}'),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});
  @override
  ConsumerState<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends ConsumerState<NotificationPrefsScreen> {
  NotificationPrefs? _p;
  bool _busy = false;

  Future<void> _save(NotificationPrefs p) async {
    final before = _p;
    setState(() { _p = p; _busy = true; });
    try {
      await ref.read(accountRepoProvider).savePrefs(p);
      ref.invalidate(notificationPrefsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _p = before);
        showSnack(context, toAppException(e).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: AsyncBody<NotificationPrefs>(
        value: prefs,
        onRetry: () => ref.invalidate(notificationPrefsProvider),
        data: (server) {
          final p = _p ?? server;
          return ListView(padding: const EdgeInsets.all(8), children: [
            SwitchListTile(
              title: const Text('Order and payment updates'), subtitle: const Text('Confirmation, dispatch, delivery, refunds and warranty updates'),
              value: p.pushTransactional, onChanged: _busy ? null : (v) => _save(NotificationPrefs(pushTransactional: v, pushMarketing: p.pushMarketing, emailMarketing: p.emailMarketing)),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Offers and promotions (push)'), subtitle: const Text('Only if you agree. You can switch this off any time.'),
              value: p.pushMarketing, onChanged: _busy ? null : (v) => _save(NotificationPrefs(pushTransactional: p.pushTransactional, pushMarketing: v, emailMarketing: p.emailMarketing)),
            ),
            SwitchListTile(
              title: const Text('Offers and promotions (email)'), subtitle: const Text('Marketing consent is separate from order updates.'),
              value: p.emailMarketing, onChanged: _busy ? null : (v) => _save(NotificationPrefs(pushTransactional: p.pushTransactional, pushMarketing: p.pushMarketing, emailMarketing: v)),
            ),
          ]);
        },
      ),
    );
  }
}
