import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../errors/app_exception.dart';
import '../models/catalog.dart';
import '../providers.dart';
import '../widgets/widgets.dart';

/// Account-specific actions need a signed-in customer; guests are sent to sign in and returned here afterwards.
bool ensureSignedIn(BuildContext context, WidgetRef ref) {
  if (ref.read(isSignedInProvider)) return true;
  final here = GoRouterState.of(context).uri.toString();
  context.push('/auth?from=${Uri.encodeComponent(here)}');
  return false;
}

Future<void> toggleWishlist(BuildContext context, WidgetRef ref, String modelId) async {
  if (!ensureSignedIn(context, ref)) return;
  try {
    await ref.read(cartRepoProvider).toggleWishlist(modelId);
    ref.invalidate(wishlistProvider);
  } catch (e) {
    if (context.mounted) showSnack(context, toAppException(e).message);
  }
}

/// Returns true if the unit is now in the cart.
Future<bool> addUnitToCart(BuildContext context, WidgetRef ref, String unitId) async {
  if (!ensureSignedIn(context, ref)) return false;
  try {
    await ref.read(cartRepoProvider).add(unitId);
    ref.invalidate(cartProvider);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, toAppException(e).message);
    return false;
  }
}

Future<void> _launch(BuildContext context, Uri uri, String failure) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) showSnack(context, failure);
}

Future<void> openWhatsApp(BuildContext context, StoreSettings s, String text) async {
  final n = s.whatsappNumber;
  if (n == null) {
    showSnack(context, 'The shop has not added a WhatsApp number yet.');
    return;
  }
  await _launch(context, Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}'), 'WhatsApp is not installed');
}

Future<void> callShop(BuildContext context, StoreSettings s) async {
  final n = s.callNumber;
  if (n == null) {
    showSnack(context, 'The shop has not added a phone number yet.');
    return;
  }
  await _launch(context, Uri.parse('tel:+$n'), 'Could not open the dialer');
}

Future<void> openMaps(BuildContext context, StoreSettings s) async {
  if (s.address.trim().isEmpty) {
    showSnack(context, 'The shop has not added an address yet.');
    return;
  }
  await _launch(context, Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(s.address)}'), 'No maps app found');
}

Future<void> openUrl(BuildContext context, String url) async {
  if (url.isEmpty) return;
  await _launch(context, Uri.parse(url), 'Could not open the link');
}
