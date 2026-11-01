import 'package:flutter/material.dart';

/// The Miqdar brand: date-brown ink on warm laban paper, with saffron for what matters.
/// Named after Saudi kitchen staples so the palette has a reason to exist.
class MiqdarColors {
  // Brand
  static const ink = Color(0xFF20160F); // tamr, dark date
  static const paper = Color(0xFFF6F1E7); // laban
  static const cream = Color(0xFFFFFCF6);
  static const saffron = Color(0xFFE8861A); // za'faran, the accent
  static const saffronDeep = Color(0xFFB85F08); // saffron readable as text on paper
  static const saffronWash = Color(0xFFFBEBD3);
  static const saffronEdge = Color(0xFFEFCB98);

  // Roles kept for shared widgets
  static const deep = ink;
  static const primary = saffronDeep;
  static const accentBright = saffron;
  static const accentGlow = Color(0xFFF2A048);
  static const accentWash = saffronWash;
  static const accentEdge = saffronEdge;

  // Neutrals, light
  static const dark = ink;
  static const muted = Color(0xFF75675A);
  static const slate400 = Color(0xFFA99B8B);
  static const border = Color(0xFFE5DBCA);
  static const background = paper;
  static const surface = cream;

  // Neutrals, dark
  static const darkCanvas = Color(0xFF14100C);
  static const darkSurface = Color(0xFF1C1611);
  static const darkCard = Color(0xFF241D16);
  static const darkBorder = Color(0xFF3A2F25);
  static const darkText = Color(0xFFF6EEDF);
  static const darkMuted = Color(0xFFA99B8B);

  // Meaning
  static const warning = Color(0xFFB9690A);
  static const warningBg = Color(0xFFFBEFD9);
  static const danger = Color(0xFFA92B38); // pomegranate
  static const dangerBg = Color(0xFFF9E7E5);
  static const info = Color(0xFF2B7780);
  static const infoBg = Color(0xFFE4F0EF);

  // Nutrients, drawn from the same kitchen
  static const caloriesAccent = saffron;
  static const proteinAccent = Color(0xFFA92B38); // pomegranate
  static const carbsAccent = Color(0xFFD9A321); // turmeric
  static const fatAccent = Color(0xFF6E7F35); // olive
  static const sugarAccent = Color(0xFFC55A7B); // rose
  static const fiberAccent = Color(0xFF3F7C58); // cardamom
  static const sodiumAccent = Color(0xFF2B7780); // gulf
  static const potassiumAccent = Color(0xFF6A4A7C); // aubergine

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, Color(0xFF33241A)],
  );

  /// Flat by design: edges come from hairlines, not shadows.
  static List<BoxShadow> ambientShadow(bool isDark) => const [];
}

/// The colors that change with light and dark, for code that needs them directly.
class Miq {
  const Miq._(this.isDark);
  factory Miq.of(BuildContext context) => Miq._(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;

  Color get canvas => isDark ? MiqdarColors.darkCanvas : MiqdarColors.paper;
  Color get surface => isDark ? MiqdarColors.darkCard : MiqdarColors.cream;
  Color get text => isDark ? MiqdarColors.darkText : MiqdarColors.ink;
  Color get muted => isDark ? MiqdarColors.darkMuted : MiqdarColors.muted;
  Color get hairline => isDark ? MiqdarColors.darkBorder : MiqdarColors.border;
  Color get accent => isDark ? MiqdarColors.accentGlow : MiqdarColors.saffronDeep;
  Color get track => isDark ? const Color(0xFF3A2F25) : const Color(0xFFE9DFCE);
}

/// Display type: the serif for numbers, names and titles. Arabic falls back to Amiri,
/// which needs a little more line height.
class MiqType {
  static const serif = 'MiqdarSerif';

  static TextStyle display(double size, {Color? color, double? height}) => TextStyle(
        fontFamily: serif,
        fontFamilyFallback: const ['Amiri'],
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: height,
        color: color,
        letterSpacing: -0.01 * size,
      );
}

ThemeData miqdarTheme({bool isDark = false}) {
  final textColor = isDark ? MiqdarColors.darkText : MiqdarColors.ink;
  final mutedColor = isDark ? MiqdarColors.darkMuted : MiqdarColors.muted;
  final cardBg = isDark ? MiqdarColors.darkCard : MiqdarColors.cream;
  final canvas = isDark ? MiqdarColors.darkCanvas : MiqdarColors.paper;
  final borderCol = isDark ? MiqdarColors.darkBorder : MiqdarColors.border;
  final accent = isDark ? MiqdarColors.accentGlow : MiqdarColors.saffronDeep;

  final scheme = ColorScheme.fromSeed(
    seedColor: MiqdarColors.saffron,
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: accent,
    onPrimary: isDark ? MiqdarColors.ink : Colors.white,
    secondary: MiqdarColors.proteinAccent,
    surface: cardBg,
    onSurface: textColor,
    onSurfaceVariant: mutedColor,
    outline: borderCol,
    outlineVariant: borderCol,
    surfaceContainerHighest: isDark ? MiqdarColors.darkBorder : const Color(0xFFEFE6D6),
    error: MiqdarColors.danger,
  );

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(99));

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: 'Plex',
    scaffoldBackgroundColor: canvas,
    dividerTheme: DividerThemeData(color: borderCol, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: MiqType.display(26, color: textColor),
    ),
    textTheme: TextTheme(
      headlineLarge: MiqType.display(44, color: textColor, height: 1.1),
      headlineMedium: MiqType.display(38, color: textColor, height: 1.1),
      headlineSmall: MiqType.display(34, color: textColor, height: 1.15),
      titleLarge: MiqType.display(26, color: textColor, height: 1.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      bodyLarge: TextStyle(color: textColor, height: 1.45),
      bodyMedium: TextStyle(color: mutedColor, height: 1.45),
      bodySmall: TextStyle(color: mutedColor, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(color: mutedColor, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.7)),
      prefixIconColor: mutedColor,
      suffixIconColor: mutedColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderCol),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    ),
    // Main actions are saffron pills with ink text: the highest contrast the accent allows.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MiqdarColors.saffron,
        foregroundColor: MiqdarColors.ink,
        disabledBackgroundColor: isDark ? MiqdarColors.darkBorder : const Color(0xFFE9DFCE),
        disabledForegroundColor: mutedColor,
        minimumSize: const Size(88, 54),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: pill,
        elevation: 0,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600, fontSize: 15.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        minimumSize: const Size(88, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        side: BorderSide(color: isDark ? const Color(0xFF55463A) : const Color(0xFFCFC2AE)),
        shape: pill,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        shape: pill,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardBg,
      selectedColor: isDark ? const Color(0xFF4A3216) : MiqdarColors.saffronWash,
      checkmarkColor: accent,
      side: BorderSide(color: borderCol),
      shape: pill,
      labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 13),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: mutedColor,
        selectedBackgroundColor: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
        selectedForegroundColor: isDark ? MiqdarColors.ink : MiqdarColors.cream,
        side: BorderSide(color: borderCol),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? MiqdarColors.ink : mutedColor,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MiqdarColors.saffron
            : (isDark ? MiqdarColors.darkBorder : const Color(0xFFE9DFCE)),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: MiqdarColors.saffron,
      thumbColor: MiqdarColors.saffron,
      inactiveTrackColor: isDark ? MiqdarColors.darkBorder : const Color(0xFFE9DFCE),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: MiqdarColors.saffron),
    dialogTheme: DialogThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: MiqType.display(26, color: textColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'Plex',
        color: isDark ? MiqdarColors.ink : MiqdarColors.cream,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: isDark ? MiqdarColors.saffronDeep : MiqdarColors.accentGlow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: mutedColor,
      collapsedIconColor: mutedColor,
      textColor: textColor,
      collapsedTextColor: textColor,
    ),
  );
}
