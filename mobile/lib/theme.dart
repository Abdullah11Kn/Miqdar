import 'package:flutter/material.dart';

export 'miqdar_icons.dart';

/// Every color in the app, for the current light or dark theme. Use `context.mq`.
/// What each one is for is written in the Miqdar design system.
@immutable
class MiqdarTokens extends ThemeExtension<MiqdarTokens> {
  const MiqdarTokens({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.hero,
    required this.heroEnd,
    required this.onHero,
    required this.onHeroMuted,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentSoft,
    required this.accentOnHero,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.nProtein,
    required this.nCarbs,
    required this.nFat,
    required this.nSugar,
    required this.nFiber,
    required this.nSodium,
    required this.nPotassium,
  });

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color hero;
  final Color heroEnd;
  final Color onHero;
  final Color onHeroMuted;
  final Color accent;
  final Color accentInk;
  final Color onAccent;
  final Color accentSoft;
  final Color accentOnHero;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color nProtein;
  final Color nCarbs;
  final Color nFat;
  final Color nSugar;
  final Color nFiber;
  final Color nSodium;
  final Color nPotassium;

  Color get nCalories => primary;

  /// The only gradient in the app: the Home scale card and the Profile header.
  LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [hero, heroEnd],
      );

  /// Dark mode has no card shadow; the border does the work.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0D1B2921), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0D1B2921), blurRadius: 20, offset: Offset(0, 6)),
        ];

  static const light = MiqdarTokens(
    isDark: false,
    bg: Color(0xFFF8FAF7),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF3EE),
    border: Color(0xFFDCE5DD),
    borderStrong: Color(0xFF7F8F84),
    ink: Color(0xFF1B2921),
    inkMuted: Color(0xFF5B685F),
    primary: Color(0xFF246B4F),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE2F0E6),
    hero: Color(0xFF173F2F),
    heroEnd: Color(0xFF246B4F),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFC9DED1),
    accent: Color(0xFFE9783D),
    accentInk: Color(0xFFA9501F),
    onAccent: Color(0xFF2A1606),
    accentSoft: Color(0xFFFCEADB),
    accentOnHero: Color(0xFFF3A36B),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE4E1),
    info: Color(0xFF2F64A8),
    infoSoft: Color(0xFFE3ECF7),
    nProtein: Color(0xFF1F8A7E),
    nCarbs: Color(0xFFB8761F),
    nFat: Color(0xFF3D78C2),
    nSugar: Color(0xFFC8507A),
    nFiber: Color(0xFF4F9A3A),
    nSodium: Color(0xFF5F64C4),
    nPotassium: Color(0xFF8A5CB8),
  );

  static const dark = MiqdarTokens(
    isDark: true,
    bg: Color(0xFF0E0F0F),
    surface: Color(0xFF18191A),
    surfaceSunken: Color(0xFF222325),
    border: Color(0xFF2E3032),
    borderStrong: Color(0xFF6C7075),
    ink: Color(0xFFF2F3F2),
    inkMuted: Color(0xFFA3A7AB),
    primary: Color(0xFF3ECB7F),
    onPrimary: Color(0xFF04210F),
    primarySoft: Color(0xFF16301F),
    hero: Color(0xFF0E3A27),
    heroEnd: Color(0xFF13583A),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFBCD6C6),
    accent: Color(0xFFF3A36B),
    accentInk: Color(0xFFF3A36B),
    onAccent: Color(0xFF2A1606),
    accentSoft: Color(0xFF36251A),
    accentOnHero: Color(0xFFF6B583),
    danger: Color(0xFFFF8A80),
    dangerSoft: Color(0xFF3A1D1C),
    info: Color(0xFF8DBEF0),
    infoSoft: Color(0xFF1B2736),
    nProtein: Color(0xFF5CC9BC),
    nCarbs: Color(0xFFE6AE5C),
    nFat: Color(0xFF7FAEEB),
    nSugar: Color(0xFFF08AAE),
    nFiber: Color(0xFF8FCB72),
    nSodium: Color(0xFF9EA2F0),
    nPotassium: Color(0xFFC29BEA),
  );

  @override
  MiqdarTokens copyWith() => this;

  @override
  MiqdarTokens lerp(MiqdarTokens? other, double t) => t < 0.5 || other == null ? this : other;
}

extension MiqdarTokensOf on BuildContext {
  MiqdarTokens get mq => Theme.of(this).extension<MiqdarTokens>()!;
}

/// The design system's text styles. They set size and weight; color comes from where they are used.
abstract final class MiqdarType {
  static const _tabular = [FontFeature.tabularFigures()];

  static const weightLive = TextStyle(
    fontSize: 84,
    height: 88 / 84,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    fontFeatures: _tabular,
  );
  static const numberXl = TextStyle(
    fontSize: 48,
    height: 52 / 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );
  static const numberLg = TextStyle(
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );
  static const titleScreen = TextStyle(
    fontSize: 30,
    height: 36 / 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const titleSection = TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700);
  static const titleCard = TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600);
  static const button = TextStyle(fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600);
  static const caption = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);
}

ThemeData miqdarTheme({bool isDark = false}) {
  final c = isDark ? MiqdarTokens.dark : MiqdarTokens.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: isDark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: c.primary,
    onPrimary: c.onPrimary,
    // FilledButton.tonal is the design system's secondary button.
    secondaryContainer: c.surfaceSunken,
    onSecondaryContainer: c.ink,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerHighest: c.surfaceSunken,
    surfaceContainerHigh: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerLow: c.surface,
    outline: c.borderStrong,
    outlineVariant: c.border,
    error: c.danger,
    surfaceTint: Colors.transparent,
  );

  OutlineInputBorder fieldBorder(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border, thickness: 1),
    fontFamilyFallback: const ['SF Arabic', 'Noto Sans Arabic'],
    iconTheme: IconThemeData(color: c.ink, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12),
      titleTextStyle: MiqdarType.titleSection.copyWith(color: c.ink),
    ),
    textTheme: TextTheme(
      headlineSmall: MiqdarType.titleScreen.copyWith(color: c.ink),
      titleLarge: MiqdarType.titleSection.copyWith(color: c.ink),
      titleMedium: MiqdarType.titleCard.copyWith(color: c.ink),
      titleSmall: MiqdarType.bodyStrong.copyWith(color: c.ink),
      bodyLarge: MiqdarType.body.copyWith(color: c.ink),
      bodyMedium: MiqdarType.body.copyWith(color: c.inkMuted),
      bodySmall: MiqdarType.caption.copyWith(color: c.inkMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: MiqdarType.body.copyWith(color: c.inkMuted),
      floatingLabelStyle: MiqdarType.label.copyWith(color: c.ink),
      hintStyle: MiqdarType.body.copyWith(color: c.inkMuted),
      prefixIconColor: c.inkMuted,
      suffixIconColor: c.inkMuted,
      suffixStyle: MiqdarType.label.copyWith(color: c.inkMuted),
      border: fieldBorder(c.borderStrong, 1.5),
      enabledBorder: fieldBorder(c.borderStrong, 1.5),
      disabledBorder: fieldBorder(c.border, 1.5),
      focusedBorder: fieldBorder(c.primary, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle: MiqdarType.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(88, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: MiqdarType.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: MiqdarType.bodyStrong,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      showCheckmark: true,
      checkmarkColor: c.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.surface,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected) ? c.primary : c.borderStrong,
          width: 1.5,
        ),
      ),
      labelStyle: MiqdarType.label.copyWith(
        fontSize: 14,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onPrimary : c.ink,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.onPrimary : c.borderStrong,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.surfaceSunken,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.borderStrong,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primary,
      inactiveTrackColor: c.surfaceSunken,
      thumbColor: c.primary,
      overlayColor: c.primary.withValues(alpha: 0.12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceSunken,
      circularTrackColor: Colors.transparent,
    ),
    badgeTheme: BadgeThemeData(backgroundColor: c.accent, textColor: c.onAccent),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: c.inkMuted,
      collapsedIconColor: c.inkMuted,
      textColor: c.ink,
      collapsedTextColor: c.ink,
    ),
    listTileTheme: ListTileThemeData(textColor: c.ink, iconColor: c.ink),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: MiqdarType.titleSection.copyWith(color: c.ink),
      contentTextStyle: MiqdarType.body.copyWith(color: c.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface,
      contentTextStyle: MiqdarType.body.copyWith(color: c.ink),
      actionTextColor: c.primary,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
    ),
  );
}
