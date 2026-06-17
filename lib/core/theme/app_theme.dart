import 'package:flutter/material.dart';

/// Central design system for the BRF Samlat mobile app.
///
/// A fresh, modern look built around an emerald-green brand palette paired with
/// cool slate neutrals. The whole app inherits these tokens through [ThemeData],
/// so most screens restyle themselves without per-page changes.
class AppTheme {
  // ---------------------------------------------------------------------------
  // Brand palette — emerald green
  // ---------------------------------------------------------------------------
  static const Color primaryColor = Color(0xFF10B981); // emerald 500
  static const Color primaryDarken1 = Color(0xFF059669); // emerald 600
  static const Color primaryDarken2 = Color(0xFF047857); // emerald 700
  static const Color primaryDeep = Color(0xFF065F46); // emerald 800
  static const Color primaryDeepest = Color(0xFF064E3B); // emerald 900
  static const Color primaryLighten1 = Color(0xFF34D399); // emerald 400
  static const Color primaryLighten2 = Color(0xFFA7F3D0); // emerald 200
  static const Color surfaceLight = Color(0xFFECFDF5); // emerald 50

  /// Brand gradient used for hero headers, logos and emphasis surfaces.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primaryDarken1, primaryColor],
  );

  // ---------------------------------------------------------------------------
  // Neutrals (light)
  // ---------------------------------------------------------------------------
  static const Color ink = Color(0xFF0F172A); // slate 900
  static const Color inkMuted = Color(0xFF64748B); // slate 500
  static const Color inkFaint = Color(0xFF94A3B8); // slate 400
  static const Color border = Color(0xFFE7ECEA); // soft green-grey hairline
  static const Color background = Color(0xFFF6F8F7); // app canvas

  // Shape tokens
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------
  static final ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: surfaceLight,
    onPrimaryContainer: primaryDeep,
    secondary: primaryDarken2,
    onSecondary: Colors.white,
    secondaryContainer: surfaceLight,
    onSecondaryContainer: primaryDeep,
    surface: Colors.white,
    onSurface: ink,
    surfaceContainerHighest: const Color(0xFFF1F5F4),
    onSurfaceVariant: inkMuted,
    error: const Color(0xFFDC2626),
    onError: Colors.white,
    outline: border,
    outlineVariant: const Color(0xFFEEF2F1),
  );

  static ThemeData get lightTheme => _buildTheme(
        scheme: _colorScheme,
        scaffold: background,
        cardColor: Colors.white,
        fieldFill: const Color(0xFFF3F6F5),
        onPrimaryForButtons: Colors.white,
      );

  // ---------------------------------------------------------------------------
  // Dark theme — keeps the brand green as an accent on deep neutral surfaces.
  // ---------------------------------------------------------------------------
  static const Color _darkBackground = Color(0xFF0B1220);
  static const Color _darkSurface = Color(0xFF111A2B);
  static const Color _darkSurfaceHigh = Color(0xFF18233A);
  static const Color _darkOnSurface = Color(0xFFE6EAF2);
  static const Color _darkBorder = Color(0xFF223047);

  static final ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryLighten1,
    onPrimary: const Color(0xFF06281C),
    primaryContainer: primaryDeep,
    onPrimaryContainer: primaryLighten2,
    secondary: primaryLighten1,
    onSecondary: const Color(0xFF06281C),
    secondaryContainer: primaryDeepest,
    onSecondaryContainer: primaryLighten2,
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    surfaceContainerHighest: _darkSurfaceHigh,
    onSurfaceVariant: const Color(0xFF9AA7BD),
    error: const Color(0xFFF87171),
    onError: const Color(0xFF2A0A0A),
    outline: _darkBorder,
    outlineVariant: _darkBorder,
  );

  static ThemeData get darkTheme => _buildTheme(
        scheme: _darkColorScheme,
        scaffold: _darkBackground,
        cardColor: _darkSurface,
        fieldFill: _darkSurfaceHigh,
        onPrimaryForButtons: const Color(0xFF06281C),
      );

  // ---------------------------------------------------------------------------
  // Shared theme builder
  // ---------------------------------------------------------------------------
  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color cardColor,
    required Color fieldFill,
    required Color onPrimaryForButtons,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(scheme.onSurface, scheme.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryForButtons,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryForButtons,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? primaryLighten1 : primaryDarken1,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? primaryLighten1 : primaryDarken1,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryForButtons,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkSurfaceHigh : surfaceLight,
        selectedColor: primaryColor,
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        backgroundColor: scheme.surface,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isDark ? primaryDeep : surfaceLight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? (isDark ? primaryLighten1 : primaryDarken2)
                : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? primaryLighten1 : primaryDarken2)
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? _darkSurfaceHigh : ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? primaryDeep : primaryLighten2;
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      headlineSmall: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: onSurface, height: 1.4),
      bodySmall: TextStyle(color: onSurfaceVariant, height: 1.35),
      labelLarge: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
