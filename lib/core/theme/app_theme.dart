import 'package:flutter/material.dart';

/// Central design system for the BRF Samlat mobile app.
///
/// Calm, Nordic look (design: "BRF Samlat – app redesign", artboard Grunder):
/// grey-green neutrals, ONE green accent ("tall") for the association and what
/// is yours, and ONE attention colour ("bärnsten") that only means "this needs
/// you". Schibsted Grotesk throughout, 1 px borders instead of shadows, pill
/// buttons. The same tokens are used on the web portal
/// (brf-samlat-nuxt-app). Most screens restyle themselves through [ThemeData].
class AppTheme {
  static const String fontFamily = 'SchibstedGrotesk';

  // ---------------------------------------------------------------------------
  // Tokens (light)
  // ---------------------------------------------------------------------------
  /// Mark — page background.
  static const Color ground = Color(0xFFF3F4F0);

  /// Yta — cards, tab bar, fields.
  static const Color surface = Color(0xFFFFFFFF);

  /// Linje — card borders and dividers.
  static const Color line = Color(0xFFE2E5DF);

  /// Linje stark — field borders and secondary buttons.
  static const Color lineStrong = Color(0xFFC9CFC8);

  /// Neutral chip / disabled / taken slot background.
  static const Color neutralFill = Color(0xFFEEF0EC);

  /// Bläck — text, primary ("do it") buttons, selected states.
  static const Color ink = Color(0xFF17201B);

  /// Bläck 2 — body text inside cards.
  static const Color ink2 = Color(0xFF4A554F);

  /// Bläck 3 — labels, dates, meta.
  static const Color ink3 = Color(0xFF5F6963);

  /// Tall — the association: links, unread, your bookings, brand CTA.
  static const Color pine = Color(0xFF1D5C45);

  /// Tall ljus — active tab, own messages, date blocks.
  static const Color pineLight = Color(0xFFDDEBE3);

  /// Tall mörk — text on [pineLight].
  static const Color pineDark = Color(0xFF14432F);

  /// Bärnsten — "needs you": text on [attentionFill].
  static const Color attention = Color(0xFF8A3F06);
  static const Color attentionFill = Color(0xFFFCEEE1);

  /// Signal — notification badge and dot.
  static const Color signal = Color(0xFFB4470C);

  // ---------------------------------------------------------------------------
  // Older names, kept so existing screens follow the new palette.
  // ---------------------------------------------------------------------------
  static const Color primaryColor = pine;
  static const Color primaryDarken1 = pine;
  static const Color primaryDarken2 = pineDark;
  static const Color primaryDeep = pineDark;
  static const Color primaryDeepest = Color(0xFF0E2E21);
  static const Color primaryLighten1 = Color(0xFF8CCFAE);
  static const Color primaryLighten2 = pineLight;
  static const Color surfaceLight = pineLight;
  static const Color inkMuted = ink3;
  static const Color inkFaint = Color(0xFF8B948E);
  static const Color border = line;
  static const Color background = ground;

  // Shape tokens
  static const double radiusSm = 12; // slots, thumbnails, fields
  static const double radiusMd = 18; // cards
  static const double radiusLg = 22; // dialogs, sheets
  static const double radiusTile = 16;

  // ---------------------------------------------------------------------------
  // Dark tokens — the same roles on deep green-grey neutrals.
  // ---------------------------------------------------------------------------
  static const Color _darkGround = Color(0xFF0F1512);
  static const Color _darkSurface = Color(0xFF161E1A);
  static const Color _darkSurfaceHigh = Color(0xFF1E2823);
  static const Color _darkLine = Color(0xFF2A3530);
  static const Color _darkLineStrong = Color(0xFF3A4741);
  static const Color _darkInk = Color(0xFFE7ECE8);
  static const Color _darkInk3 = Color(0xFFA3AEA7);
  static const Color _darkPine = Color(0xFF8CCFAE);
  static const Color _darkPineFill = Color(0xFF1F3D30);

  /// Attention colours that follow the theme brightness.
  static Color attentionOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF5B57A)
      : attention;
  static Color attentionFillOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF3A2614)
      : attentionFill;

  static final ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: pine,
    onPrimary: Colors.white,
    primaryContainer: pineLight,
    onPrimaryContainer: pineDark,
    secondary: ink,
    onSecondary: Colors.white,
    secondaryContainer: neutralFill,
    onSecondaryContainer: ink,
    tertiary: attention,
    onTertiary: Colors.white,
    tertiaryContainer: attentionFill,
    onTertiaryContainer: attention,
    surface: surface,
    onSurface: ink,
    surfaceContainerLowest: surface,
    surfaceContainerLow: ground,
    surfaceContainer: ground,
    surfaceContainerHigh: neutralFill,
    surfaceContainerHighest: neutralFill,
    onSurfaceVariant: ink3,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    outline: line,
    outlineVariant: neutralFill,
    inverseSurface: ink,
    onInverseSurface: Colors.white,
  );

  static final ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _darkPine,
    onPrimary: const Color(0xFF0B2A1E),
    primaryContainer: _darkPineFill,
    onPrimaryContainer: const Color(0xFFCDE7D9),
    secondary: _darkInk,
    onSecondary: _darkGround,
    secondaryContainer: _darkSurfaceHigh,
    onSecondaryContainer: _darkInk,
    tertiary: const Color(0xFFF5B57A),
    onTertiary: const Color(0xFF2A1606),
    tertiaryContainer: const Color(0xFF3A2614),
    onTertiaryContainer: const Color(0xFFF5B57A),
    surface: _darkSurface,
    onSurface: _darkInk,
    surfaceContainerLowest: _darkGround,
    surfaceContainerLow: _darkGround,
    surfaceContainer: _darkSurface,
    surfaceContainerHigh: _darkSurfaceHigh,
    surfaceContainerHighest: _darkSurfaceHigh,
    onSurfaceVariant: _darkInk3,
    error: const Color(0xFFF2B8B5),
    onError: const Color(0xFF601410),
    outline: _darkLine,
    outlineVariant: _darkSurfaceHigh,
    inverseSurface: _darkInk,
    onInverseSurface: _darkGround,
  );

  static ThemeData get lightTheme => _buildTheme(
    scheme: _colorScheme,
    scaffold: ground,
    strongLine: lineStrong,
    navIndicator: pineLight,
    navSelected: pineDark,
  );

  static ThemeData get darkTheme => _buildTheme(
    scheme: _darkColorScheme,
    scaffold: _darkGround,
    strongLine: _darkLineStrong,
    navIndicator: _darkPineFill,
    navSelected: const Color(0xFFCDE7D9),
  );

  // ---------------------------------------------------------------------------
  // Shared theme builder
  // ---------------------------------------------------------------------------
  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color strongLine,
    required Color navIndicator,
    required Color navSelected,
  }) {
    // "Do it" buttons are ink (inverted in dark mode); the brand green is for
    // the association's own things.
    final actionBg = scheme.secondary;
    final actionFg = scheme.onSecondary;
    const pill = StadiumBorder();
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(scheme.onSurface, scheme.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
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
        iconColor: scheme.primary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: strongLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: strongLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionBg,
          foregroundColor: actionFg,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: buttonText,
          shape: pill,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionBg,
          foregroundColor: actionFg,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: buttonText,
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: strongLine),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: buttonText,
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: buttonText,
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusTile),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: actionBg,
        checkmarkColor: actionFg,
        side: BorderSide(color: strongLine),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          color: actionFg,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(buttonText),
          side: WidgetStatePropertyAll(BorderSide(color: strongLine)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? actionBg : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? actionFg : scheme.onSurface,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? actionFg : scheme.onSurface,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outline,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.onSurface,
        unselectedItemColor: scheme.onSurfaceVariant,
        backgroundColor: scheme.surface,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: navIndicator,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? navSelected : scheme.onSurfaceVariant,
          );
        }),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: signal,
        textColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
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
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color onSurface, Color onSurfaceVariant) {
    TextStyle s(double size, FontWeight w, {double? ls, double? h, Color? c}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: c ?? onSurface,
        );
    return TextTheme(
      displaySmall: s(36, FontWeight.w800, ls: -0.8, h: 1.1),
      headlineLarge: s(32, FontWeight.w800, ls: -0.64, h: 1.1),
      headlineMedium: s(28, FontWeight.w800, ls: -0.56, h: 1.15),
      headlineSmall: s(24, FontWeight.w800, ls: -0.4, h: 1.2),
      titleLarge: s(20, FontWeight.w700, ls: -0.2),
      titleMedium: s(17, FontWeight.w700, ls: -0.1),
      titleSmall: s(15, FontWeight.w600),
      bodyLarge: s(16, FontWeight.w400, h: 1.5),
      bodyMedium: s(15, FontWeight.w400, h: 1.45),
      bodySmall: s(13, FontWeight.w400, h: 1.35, c: onSurfaceVariant),
      labelLarge: s(15, FontWeight.w600),
      labelMedium: s(13, FontWeight.w600),
      labelSmall: s(12, FontWeight.w700, ls: 0.96, c: onSurfaceVariant),
    );
  }
}
