import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  static const _slides = [
    (Icons.verified_outlined, 'Every phone is checked', 'Real photos, tested hardware and battery health shown on every listing.'),
    (Icons.shield_outlined, 'Warranty on every phone', 'Buy with confidence. Hardware faults are covered for the warranty period shown on the phone.'),
    (Icons.swap_horiz, 'Buy, sell or exchange', 'Pay securely online or choose cash on delivery where available, or trade in your old phone.'),
  ];

  void _finish() {
    ref.read(onboardingSeenProvider.notifier).markSeen();
    context.go('/');
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _finish, child: const Text('Skip'))),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final (icon, title, body) = _slides[i];
                  return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: s.primaryContainer), child: Icon(icon, size: 56, color: s.onPrimaryContainer)),
                    const SizedBox(height: 32),
                    Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(body, style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant), textAlign: TextAlign.center),
                  ]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8, width: _i == i ? 24 : 8,
                    decoration: ShapeDecoration(shape: const StadiumBorder(), color: _i == i ? s.primary : s.outlineVariant),
                  ),
              ]),
            ),
            AppButton(last ? 'Get started' : 'Next', () {
              if (last) {
                _finish();
              } else {
                _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              }
            }),
          ]),
        ),
      ),
    );
  }
}
