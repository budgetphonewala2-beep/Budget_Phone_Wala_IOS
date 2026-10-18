import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BudgetPhoneApp extends ConsumerWidget {
  const BudgetPhoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'BudgetPhonewala',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      // Tablets, foldables and landscape (orientation is not locked): keep the phone layout readable instead of stretching it.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 840), child: child)),
      ),
    );
  }
}
