import 'package:flutter/material.dart';

class MiqdarColors {
  // Core Brand Emeralds & Mints
  static const emeraldDeep = Color(0xFF064E3B);
  static const primary = Color(0xFF059669); // Vibrant modern emerald
  static const emeraldBright = Color(0xFF10B981);
  static const mintGlow = Color(0xFF34D399);
  static const lime = Color(0xFF84CC16);
  static const softGreen = Color(0xFFECFDF5);
  static const mintBorder = Color(0xFFA7F3D0);

  // Neutral Slates (Light Mode)
  static const dark = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const muted = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const background = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);

  // Dark Mode Surfaces
  static const darkCanvas = Color(0xFF0A120E);
  static const darkSurface = Color(0xFF121F18);
  static const darkCard = Color(0xFF182920);
  static const darkBorder = Color(0xFF263E31);
  static const darkText = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8);

  // Semantic & Categorical Nutrient Colors (DES-03)
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const danger = Color(0xFFE11D48);
  static const dangerBg = Color(0xFFFFF1F2);
  static const info = Color(0xFF0284C7);
  static const infoBg = Color(0xFFF0F9FF);

  static const caloriesAccent = Color(0xFF059669);
  static const proteinAccent = Color(0xFF0D9488);
  static const carbsAccent = Color(0xFFD97706);
  static const fatAccent = Color(0xFF3B82F6);
  static const sugarAccent = Color(0xFFEC4899);
  static const fiberAccent = Color(0xFF16A34A);
  static const sodiumAccent = Color(0xFF6366F1);
  static const potassiumAccent = Color(0xFF8B5CF6);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF042F2E),
      Color(0xFF065F46),
      Color(0xFF059669),
    ],
  );

  static const darkHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF06281E),
      Color(0xFF064E3B),
      Color(0xFF047857),
    ],
  );

  static List<BoxShadow> ambientShadow(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
}

ThemeData miqdarTheme({bool isDark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: MiqdarColors.primary,
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: isDark ? MiqdarColors.mintGlow : MiqdarColors.primary,
    onPrimary: isDark ? MiqdarColors.darkCanvas : Colors.white,
    secondary: MiqdarColors.proteinAccent,
    surface: isDark ? MiqdarColors.darkSurface : MiqdarColors.surface,
    onSurface: isDark ? MiqdarColors.darkText : MiqdarColors.dark,
    error: MiqdarColors.danger,
  );

  final textColor = isDark ? MiqdarColors.darkText : MiqdarColors.dark;
  final mutedColor = isDark ? MiqdarColors.darkMuted : MiqdarColors.muted;
  final cardBg = isDark ? MiqdarColors.darkCard : Colors.white;
  final borderCol = isDark ? MiqdarColors.darkBorder : MiqdarColors.border;

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? MiqdarColors.darkCanvas : MiqdarColors.background,
    fontFamilyFallback: const [
      'SF Pro Display',
      'Inter',
      'Cairo',
      'Tajawal',
      'IBM Plex Sans Arabic',
      'Geeza Pro',
      'Arial',
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? MiqdarColors.darkCanvas : MiqdarColors.background,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: -0.3,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.8),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.4),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      titleSmall: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      bodyLarge: TextStyle(color: textColor, height: 1.45),
      bodyMedium: TextStyle(color: mutedColor, height: 1.45),
      bodySmall: TextStyle(color: mutedColor, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.65)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderCol),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? MiqdarColors.mintGlow : MiqdarColors.primary,
          width: 2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? MiqdarColors.emeraldBright : MiqdarColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        minimumSize: const Size(88, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: borderCol, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardBg,
      selectedColor: isDark ? MiqdarColors.emeraldDeep : MiqdarColors.softGreen,
      side: BorderSide(color: borderCol),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12.5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? MiqdarColors.darkSurface : Colors.white,
      indicatorColor: isDark
          ? MiqdarColors.emeraldBright.withValues(alpha: 0.22)
          : MiqdarColors.softGreen,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected
              ? (isDark ? MiqdarColors.mintGlow : MiqdarColors.primary)
              : mutedColor,
        );
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
