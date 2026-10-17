import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/account.dart';
import '../../core/models/catalog.dart';
import '../../core/providers.dart';
import '../../core/util/actions.dart';
import '../../core/widgets/widgets.dart';
import '../auth/guest_prompt.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _faq = -1;

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
      // private caches are cleared: every private provider watches the user id and rebuilds
      ref.read(recentSearchesProvider.notifier).clear();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) showSnack(context, toAppException(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    final settings = ref.watch(settingsProvider).value ?? const StoreSettings();
    final faqs = ref.watch(faqsProvider).value ?? const <Faq>[];
    final theme = ref.watch(themeModeProvider);
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value ?? const Profile();
    final addresses = ref.watch(addressesProvider).value ?? const <Address>[];
    final orders = ref.watch(ordersProvider).value ?? const <Order>[];
    final wish = ref.watch(wishlistProvider).value ?? const [];
    final cart = ref.watch(cartCountProvider);
    final email = ref.read(gatewayProvider).userEmail ?? profile.email;

    Widget group(String title, List<Widget> children, {String? action, VoidCallback? onAction}) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title, action: action, onAction: onAction),
            const SizedBox(height: 4),
            Card(child: Column(children: children)),
          ]),
        );

    Widget row(IconData icon, String label, String value, {VoidCallback? onTap, bool last = false}) => Column(children: [
          ListTile(
            leading: Icon(icon, color: s.onSurfaceVariant), onTap: onTap,
            title: Text(label, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
            subtitle: Text(value.isEmpty ? 'Not added' : value, style: value.isEmpty ? t.bodyMedium?.copyWith(color: s.outline) : t.titleSmall),
          ),
          if (!last) const Divider(indent: 56),
        ]);

    Widget link(IconData icon, String label, VoidCallback onTap, {bool last = false}) => Column(children: [
          ListTile(leading: Icon(icon, color: s.onSurfaceVariant), title: Text(label, style: t.titleSmall), trailing: Icon(Icons.chevron_right, color: s.outline), onTap: onTap),
          if (!last) const Divider(indent: 56),
        ]);

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (!signedIn)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Card(child: Padding(padding: const EdgeInsets.all(8), child: SizedBox(height: 300, child: GuestPrompt(title: 'Welcome to BudgetPhonewala', body: 'Browse freely. Sign in to save phones, check out and track your orders.')))),
          )
        else ...[
          Row(children: [
            CircleAvatar(radius: 36, backgroundColor: s.primary, child: Text(profile.initials, style: t.headlineSmall?.copyWith(color: s.onPrimary))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.fullName.isEmpty ? 'Welcome' : profile.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
              Text(profile.phone.isNotEmpty ? '+91 ${profile.phone}' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
            ])),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                _Stat('${orders.length}', 'Orders', () => context.go('/orders')),
                _Stat('${wish.length}', 'Saved', () => context.push('/wishlist')),
                _Stat('$cart', 'In cart', () => context.push('/cart')),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          group('My details', [
            row(Icons.person_outline, 'Full name', profile.fullName, onTap: () => context.push('/profile/edit')),
            row(Icons.phone_outlined, 'Mobile number', profile.phone.isEmpty ? '' : '+91 ${profile.phone}', onTap: () => context.push('/profile/edit')),
            row(Icons.email_outlined, 'Email', email, onTap: null),
            row(Icons.home_outlined, 'Saved addresses', addresses.isEmpty ? '' : '${addresses.length} saved${addresses.any((a) => a.isDefault) ? ' (default: ${addresses.firstWhere((a) => a.isDefault).oneLine})' : ''}', onTap: () => context.push('/profile/addresses'), last: true),
          ], action: 'Edit', onAction: () => context.push('/profile/edit')),
          group('Account', [
            link(Icons.notifications_none, 'Notifications', () => context.push('/notifications')),
            link(Icons.tune, 'Notification preferences', () => context.push('/profile/notifications')),
            link(Icons.privacy_tip_outlined, 'Privacy and data', () => context.push('/profile/privacy'), last: true),
          ]),
        ],
        group('Appearance', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [ButtonSegment(value: ThemeMode.system, label: Text('System')), ButtonSegment(value: ThemeMode.light, label: Text('Light')), ButtonSegment(value: ThemeMode.dark, label: Text('Dark'))],
                selected: {theme},
                onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).set(v.first),
              ),
            ),
          ),
        ]),
        group('Contact the shop', [
          link(Icons.call_outlined, 'Call us', () => callShop(context, settings)),
          link(Icons.chat_outlined, 'Chat on WhatsApp', () => openWhatsApp(context, settings, 'Hello BudgetPhonewala!')),
          link(Icons.place_outlined, settings.address.isEmpty ? 'Directions' : settings.address, () => openMaps(context, settings)),
          link(Icons.photo_camera_outlined, 'Instagram', () => openUrl(context, settings.instagram), last: true),
        ]),
        if (faqs.isNotEmpty)
          group('Help and FAQs', [
            for (var i = 0; i < faqs.length; i++) Column(children: [
              ListTile(
                title: Text(faqs[i].q, style: t.titleSmall),
                trailing: Icon(_faq == i ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _faq = _faq == i ? -1 : i),
              ),
              if (_faq == i) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Align(alignment: Alignment.centerLeft, child: Text(faqs[i].a, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)))),
              if (i < faqs.length - 1) const Divider(indent: 16),
            ]),
          ]),
        group('About', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(settings.shopName, style: t.titleSmall),
              const SizedBox(height: 6),
              Text('Budget Aapka, Phone Hamara. Buy, sell or exchange used phones.', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              if (settings.hours.isNotEmpty) Text('Hours: ${settings.hours}', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              if (settings.gst.isNotEmpty) Text('GSTIN: ${settings.gst}', style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text('Payments are processed by Razorpay. We never see or store your card details.', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
            ]),
          ),
        ]),
        if (signedIn) AppButton('Sign out', _signOut, style: BtnStyle.outlined, icon: Icons.logout),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.v, this.l, this.onTap);
  final String v, l;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(children: [
            Text(v, style: Theme.of(context).textTheme.titleLarge),
            Text(l, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
}
