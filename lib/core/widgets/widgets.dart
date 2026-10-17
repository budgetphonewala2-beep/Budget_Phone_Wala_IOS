import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../errors/app_exception.dart';
import '../models/catalog.dart';
import '../util/format.dart';

// ---------- shimmer / skeletons ----------
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = 10});
  final double? width, height, radius;
  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // respects the system "remove animations" setting
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius ?? 10),
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _c.value, 0),
            end: Alignment(1 + 2 * _c.value, 0),
            colors: [s.surfaceContainerHigh, s.surfaceContainerHighest, s.surfaceContainerHigh],
          ),
        ),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          AspectRatio(aspectRatio: 1, child: ShimmerBox(radius: 0)),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShimmerBox(height: 14), SizedBox(height: 8), ShimmerBox(width: 90, height: 14), SizedBox(height: 10),
              ShimmerBox(width: 70, height: 18), SizedBox(height: 10), ShimmerBox(width: 110, height: 12),
            ]),
          ),
        ]),
      );
}

// ---------- buttons / fields ----------
enum BtnStyle { primary, outlined, tonal }

class AppButton extends StatelessWidget {
  const AppButton(this.label, this.onPressed, {super.key, this.style = BtnStyle.primary, this.loading = false, this.icon, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final BtnStyle style;
  final bool loading, expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: style == BtnStyle.primary ? Theme.of(context).colorScheme.onPrimary : null))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]);
    final cb = enabled ? onPressed : null;
    final b = switch (style) {
      BtnStyle.primary => FilledButton(onPressed: cb, child: child),
      BtnStyle.tonal => FilledButton.tonal(onPressed: cb, child: child),
      BtnStyle.outlined => OutlinedButton(onPressed: cb, child: child),
    };
    return expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}

/// Visible label above-floating, error text below the field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key, required this.label, this.controller, this.validator, this.keyboardType, this.maxLines = 1, this.minLines,
    this.prefixText, this.obscure = false, this.suffix, this.onChanged, this.helper, this.maxLength, this.textInputAction,
    this.autofillHints, this.enabled = true, this.onFieldSubmitted,
  });
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines, maxLength;
  final String? prefixText, helper;
  final bool obscure, enabled;
  final Widget? suffix;
  final ValueChanged<String>? onChanged, onFieldSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: obscure ? 1 : maxLines,
        minLines: minLines,
        maxLength: maxLength,
        obscureText: obscure,
        enabled: enabled,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(labelText: label, prefixText: prefixText, suffixIcon: suffix, helperText: helper, counterText: ''),
      );
}

// ---------- status / states ----------
enum Tone { neutral, success, warning, danger, brand }

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.tone = Tone.neutral});
  final String text;
  final Tone tone;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final dark = s.brightness == Brightness.dark;
    final (bg, fg) = switch (tone) {
      Tone.success => (s.tertiaryContainer, s.onTertiaryContainer),
      Tone.danger => (s.errorContainer, s.onErrorContainer),
      Tone.brand => (s.primaryContainer, s.onPrimaryContainer),
      Tone.warning => (dark ? const Color(0xFF3B2F0B) : const Color(0xFFFEF3C7), dark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
      Tone.neutral => (s.surfaceContainerHigh, s.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title, body;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: s.primaryContainer), child: Icon(icon, size: 34, color: s.onPrimaryContainer)),
          const SizedBox(height: 16),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[const SizedBox(height: 20), AppButton(actionLabel!, onAction, expand: false)],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final e = toAppException(error);
    return EmptyState(
      icon: e.isNetwork ? Icons.wifi_off_outlined : Icons.error_outline,
      title: e.isNetwork ? 'You are offline' : 'Could not load',
      body: e.message, actionLabel: 'Try again', onAction: onRetry,
    );
  }
}

/// Standard loading / error / data switch for AsyncValue-backed screens.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, required this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback onRetry;
  final Widget? loading;
  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => loading ?? const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(error: e, onRetry: onRetry),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium))),
        if (action != null && onAction != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// ---------- imagery ----------
class RemoteImage extends StatelessWidget {
  const RemoteImage(this.path, {super.key, this.fit = BoxFit.cover, this.semanticLabel});
  final String? path;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget placeholder() => Container(color: s.surfaceContainerHigh, alignment: Alignment.center, child: Icon(Icons.smartphone_outlined, size: 44, color: s.outline));
    final p = path;
    if (p == null || p.isEmpty) return placeholder();
    final url = p.startsWith('http') ? p : AppEnv.productImageUrl(p);
    return CachedNetworkImage(
      imageUrl: url, fit: fit,
      placeholder: (_, _) => const ShimmerBox(radius: 0),
      errorWidget: (_, _, _) => placeholder(),
      imageBuilder: (_, provider) => Semantics(label: semanticLabel, image: true, child: Image(image: provider, fit: fit)),
    );
  }
}

class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, padding: EdgeInsets.all(size * 0.07),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain, semanticLabel: 'BudgetPhonewala logo')),
      );
}

// ---------- price + product card ----------
class PriceRow extends StatelessWidget {
  const PriceRow({super.key, required this.pricePaise, this.mrpPaise = 0, this.big = false, this.fromLabel = false});
  final int pricePaise, mrpPaise;
  final bool big, fromLabel;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
      if (fromLabel) Text('from', style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
      Text(rupees(pricePaise), style: (big ? t.headlineMedium : t.titleMedium)?.copyWith(fontWeight: FontWeight.w800)),
      if (mrpPaise > pricePaise)
        Text(rupees(mrpPaise), style: (big ? t.bodyLarge : t.bodySmall)?.copyWith(decoration: TextDecoration.lineThrough, color: s.onSurfaceVariant)),
    ]);
  }
}

class ModelCard extends StatelessWidget {
  const ModelCard({super.key, required this.model, required this.wished, required this.onWish, required this.onTap});
  final CatalogModel model;
  final bool wished;
  final VoidCallback onWish, onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fixed = TextScaler.noScaling;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              RemoteImage(model.primaryImage, semanticLabel: model.title),
              if (model.discountPct > 0)
                Positioned(
                  left: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: ShapeDecoration(color: s.primary, shape: const StadiumBorder()),
                    child: Text('${model.discountPct}% off', textScaler: fixed, style: t.labelSmall?.copyWith(color: s.onPrimary, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (model.availableUnits == 0)
                Container(color: Colors.black54, alignment: Alignment.center, child: Text('Sold out', style: t.titleMedium?.copyWith(color: Colors.white))),
              Positioned(
                right: 4, top: 4,
                child: Material(
                  color: s.surface.withValues(alpha: 0.92), shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
                    onPressed: onWish,
                    icon: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? s.primary : s.onSurface, size: 22),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 40, child: Text(model.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall)),
              const SizedBox(height: 6),
              PriceRow(pricePaise: model.fromPricePaise, mrpPaise: model.maxMrpPaise, fromLabel: model.availableUnits > 1),
              const SizedBox(height: 8),
              if (model.maxBattery > 0 || model.grades.isNotEmpty) Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.battery_charging_full_outlined, size: 15, color: s.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text('${model.maxBattery}%', textScaler: fixed, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
                ]),
                Text('Grade ${model.grades.isEmpty ? '-' : model.grades.first}', textScaler: fixed, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
              ]),
              if (model.warrantyMonths > 0) const SizedBox(height: 6),
              if (model.warrantyMonths > 0) Row(children: [
                Icon(Icons.verified_outlined, size: 15, color: s.tertiary),
                const SizedBox(width: 4),
                Expanded(child: Text(warrantyLabel(model.warrantyMonths), textScaler: fixed, maxLines: 2, style: t.labelMedium?.copyWith(color: s.tertiary))),
              ]),
              if (model.availableUnits > 1) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${model.availableUnits} units available', textScaler: fixed, style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
