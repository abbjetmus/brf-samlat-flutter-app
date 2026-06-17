import 'package:flutter/material.dart';

class AppTheme {
  // Colors matching brf-samlat-static Vuetify theme
  static const Color primaryColor = Color(0xFF2ed188);
  static const Color primaryDarken1 = Color(0xFF1db06c);
  static const Color primaryDarken2 = Color(0xFF198754);
  static const Color primaryLighten1 = Color(0xFF4ade94);
  static const Color primaryLighten2 = Color(0xFF86efb8);
  static const Color surfaceLight = Color(0xFFF0FDF6);

  static final ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: primaryLighten2,
    onPrimaryContainer: primaryDarken2,
    secondary: primaryDarken2,
    onSecondary: Colors.white,
    secondaryContainer: surfaceLight,
    onSecondaryContainer: primaryDarken2,
    surface: Colors.white,
    onSurface: const Color(0xFF1C1B1F),
    error: const Color(0xFFB00020),
    onError: Colors.white,
    outline: const Color(0xFF79747E),
  );

  static ThemeData get lightTheme => ThemeData(
    colorScheme: _colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: const CardThemeData(
      elevation: 1,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: primaryLighten2,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(color: primaryDarken2, fontSize: 12);
        }
        return const TextStyle(fontSize: 12);
      }),
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
        if (states.contains(WidgetState.selected)) return primaryLighten2;
        return null;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return null;
      }),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );

  // Dark theme — keeps the brand green as the accent on dark surfaces.
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkOnSurface = Color(0xFFE6E1E5);

  static final ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryColor,
    onPrimary: Colors.black,
    primaryContainer: primaryDarken2,
    onPrimaryContainer: primaryLighten2,
    secondary: primaryLighten1,
    onSecondary: Colors.black,
    secondaryContainer: primaryDarken2,
    onSecondaryContainer: primaryLighten2,
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    error: const Color(0xFFCF6679),
    onError: Colors.black,
    outline: const Color(0xFF938F99),
  );

  static ThemeData get darkTheme => ThemeData(
    colorScheme: _darkColorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: _darkBackground,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: _darkSurface,
      foregroundColor: _darkOnSurface,
      iconTheme: IconThemeData(color: _darkOnSurface),
    ),
    cardTheme: const CardThemeData(
      elevation: 1,
      color: _darkSurface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: _darkSurface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.black,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: primaryDarken2,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: primaryLighten2, fontSize: 12);
        }
        return const TextStyle(fontSize: 12);
      }),
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
        if (states.contains(WidgetState.selected)) return primaryDarken2;
        return null;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return null;
      }),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: _darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
