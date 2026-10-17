import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/widgets.dart';

/// Shown on account tabs when the visitor is browsing as a guest.
class GuestPrompt extends StatelessWidget {
  const GuestPrompt({super.key, required this.title, required this.body, this.icon = Icons.person_outline});
  final String title, body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: icon, title: title, body: body, actionLabel: 'Sign in or create account',
        onAction: () => context.push('/auth?from=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}'),
      );
}
