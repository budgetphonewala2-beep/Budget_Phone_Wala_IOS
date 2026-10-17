import 'package:flutter/material.dart';

/// Design tokens recreated from the legacy Compose theme (Color.kt / Theme.kt / Type.kt).
class AppColors {
  const AppColors._();
  static const brandRed = Color(0xFFD7263D);
  static const brandRedLight = Color(0xFFFF6B7D);
  static const whatsapp = Color(0xFF1FA855);

  static const lightBg = Color(0xFFF6F6F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF17171A);
  static const lightInkMuted = Color(0xFF5C5C66);
  static const lightOutline = Color(0xFF8E8E99);
  static const lightOutlineSoft = Color(0xFFE2E2E6);

  static const darkBg = Color(0xFF0E0E10);
  static const darkSurface = Color(0xFF17171A);
  static const darkInk = Color(0xFFF2F2F4);
  static const darkInkMuted = Color(0xFFA8A8B3);
  static const darkOutline = Color(0xFF6E6E7A);
  static const darkOutlineSoft = Color(0xFF2E2E34);

  static const success = Color(0xFF15803D);
  static const successDark = Color(0xFF4ADE80);
}

/// One shape system: cards 16, controls 14, chips pill, sheets 28.
class AppShapes {
  const AppShapes._();
  static const double card = 16;
  static const double control = 14;
  static const double sheet = 28;
  static final cardBorder = BorderRadius.circular(card);
  static final controlBorder = BorderRadius.circular(control);
  static const pill = StadiumBorder();
}

const String _font = 'PlusJakartaSans';

TextStyle _t(double size, double line, int weight, [double spacing = 0]) => TextStyle(
      fontFamily: _font,
      fontSize: size,
      height: line / size,
      fontWeight: FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      letterSpacing: spacing,
    );

TextTheme _textTheme() => TextTheme(
      displaySmall: _t(32, 38, 800, -0.8),
      headlineMedium: _t(26, 32, 800, -0.5),
      headlineSmall: _t(22, 28, 700, -0.3),
      titleLarge: _t(20, 26, 700, -0.2),
      titleMedium: _t(16, 22, 700),
      titleSmall: _t(14, 20, 600),
      bodyLarge: _t(16, 24, 400),
      bodyMedium: _t(14, 21, 400),
      bodySmall: _t(12, 18, 400),
      labelLarge: _t(14, 20, 600),
      labelMedium: _t(12, 16, 600, 0.2),
      labelSmall: _t(11, 14, 600, 0.3),
    );

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.brandRed,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFFDE8EB),
  onPrimaryContainer: Color(0xFF8A1124),
  secondary: Color(0xFF3F3F46),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFEDEDF0),
  onSecondaryContainer: AppColors.lightInk,
  tertiary: AppColors.success,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFDCFCE7),
  onTertiaryContainer: Color(0xFF14532D),
  error: Color(0xFFB42318),
  onError: Colors.white,
  errorContainer: Color(0xFFFEE4E2),
  onErrorContainer: Color(0xFF7A271A),
  surface: AppColors.lightSurface,
  onSurface: AppColors.lightInk,
  onSurfaceVariant: AppColors.lightInkMuted,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFFAFAFA),
  surfaceContainer: Color(0xFFF4F4F5),
  surfaceContainerHigh: Color(0xFFEEEEF0),
  surfaceContainerHighest: Color(0xFFE7E7EA),
  outline: AppColors.lightOutline,
  outlineVariant: AppColors.lightOutlineSoft,
  surfaceTint: Colors.transparent,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.brandRedLight,
  onPrimary: Color(0xFF2A0309),
  primaryContainer: Color(0xFF4A0F19),
  onPrimaryContainer: Color(0xFFFFD9DE),
  secondary: Color(0xFFD4D4DA),
  onSecondary: AppColors.darkBg,
  secondaryContainer: Color(0xFF2A2A30),
  onSecondaryContainer: AppColors.darkInk,
  tertiary: AppColors.successDark,
  onTertiary: Color(0xFF052E16),
  tertiaryContainer: Color(0xFF0F3D22),
  onTertiaryContainer: Color(0xFFBBF7D0),
  error: Color(0xFFFDA29B),
  onError: Color(0xFF55160C),
  errorContainer: Color(0xFF55160C),
  onErrorContainer: Color(0xFFFEE4E2),
  surface: AppColors.darkSurface,
  onSurface: AppColors.darkInk,
  onSurfaceVariant: AppColors.darkInkMuted,
  surfaceContainerLowest: Color(0xFF0B0B0D),
  surfaceContainerLow: Color(0xFF131316),
  surfaceContainer: Color(0xFF1C1C20),
  surfaceContainerHigh: Color(0xFF222227),
  surfaceContainerHighest: Color(0xFF2A2A30),
  outline: AppColors.darkOutline,
  outlineVariant: AppColors.darkOutlineSoft,
  surfaceTint: Colors.transparent,
);

ThemeData buildTheme(Brightness b) {
  final scheme = b == Brightness.dark ? _darkScheme : _lightScheme;
  final bg = b == Brightness.dark ? AppColors.darkBg : AppColors.lightBg;
  final text = _textTheme().apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: _font,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppShapes.cardBorder, side: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: AppShapes.controlBorder, borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: AppShapes.controlBorder, borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: AppShapes.controlBorder, borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: AppShapes.controlBorder, borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: AppShapes.controlBorder, borderSide: BorderSide(color: scheme.error, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder),
        side: BorderSide(color: scheme.outline),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: text.labelLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.sheet))),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppShapes.controlBorder)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppShapes.controlBorder)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
  );
}
