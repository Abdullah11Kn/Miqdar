import 'package:flutter/material.dart';

import 'ui/motion.dart';

export 'miqdar_icons.dart';

/// Every color in the app, for the current light or dark theme. Use `context.mq`.
/// What each one is for is written in docs/DESIGN.md.
@immutable
class MiqdarTokens extends ThemeExtension<MiqdarTokens> {
  const MiqdarTokens({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceFloat,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentSoft,
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
  final Color surfaceFloat;
  final Color border;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentInk;
  final Color onAccent;
  final Color accentSoft;
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

  /// The main action pill: inverted ink, black in light and white in dark.
  Color get action => ink;
  Color get onAction => bg;
  Color get focus => primary;
  Color get nCalories => primary;

  /// The star in the logo: the brand green, a little deeper on white so it holds its own there.
  Color get logoGreen => isDark ? const Color(0xFF3ECB7F) : const Color(0xFF22A862);

  /// Only floating things cast a shadow: the tab bar, Add Meal, the scale bar.
  List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: isDark ? const Color(0x99000000) : const Color(0x1A000000),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static const light = MiqdarTokens(
    isDark: false,
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF3F3F1),
    surfaceSunken: Color(0xFFE6E6E2),
    surfaceFloat: Color(0xDBFFFFFF),
    border: Color(0xFFE6E6E2),
    ink: Color(0xFF111312),
    inkMuted: Color(0xFF5C5F5D),
    primary: Color(0xFF246B4F),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE9783D),
    accentInk: Color(0xFFA9501F),
    onAccent: Color(0xFF2A1606),
    accentSoft: Color(0xFFFCEADB),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE4E1),
    info: Color(0xFF2F64A8),
    infoSoft: Color(0xFFE3ECF7),
    nProtein: Color(0xFF1F8A7E),
    nCarbs: Color(0xFFA86A18),
    nFat: Color(0xFF3D78C2),
    nSugar: Color(0xFFC8507A),
    nFiber: Color(0xFF44882F),
    nSodium: Color(0xFF5F64C4),
    nPotassium: Color(0xFF8A5CB8),
  );

  static const dark = MiqdarTokens(
    isDark: true,
    bg: Color(0xFF000000),
    surface: Color(0xFF1A1A1A),
    surfaceSunken: Color(0xFF2A2A2A),
    surfaceFloat: Color(0xDB202020),
    border: Color(0xFF262626),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFF9D9D9D),
    primary: Color(0xFF3ECB7F),
    onPrimary: Color(0xFF04210F),
    accent: Color(0xFFF3A36B),
    accentInk: Color(0xFFF3A36B),
    onAccent: Color(0xFF2A1606),
    accentSoft: Color(0xFF2E2018),
    danger: Color(0xFFFF8A80),
    dangerSoft: Color(0xFF2E1817),
    info: Color(0xFF8DBEF0),
    infoSoft: Color(0xFF16202C),
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
/// Thmanyah has no 600 or 800, so strong text is 700. Its digits are proportional, so a number
/// that updates live goes through `LockedNumber`.
abstract final class MiqdarType {
  static const sans = 'Thmanyah Sans';
  static const display = 'Thmanyah Serif Display';
  static const serifText = 'Thmanyah Serif Text';

  static const weightLive = TextStyle(
    fontFamily: sans,
    fontSize: 84,
    height: 88 / 84,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const numberXl = TextStyle(
    fontFamily: sans,
    fontSize: 48,
    height: 52 / 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const numberLg = TextStyle(
    fontFamily: sans,
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const titleScreen = TextStyle(
    fontFamily: display,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const titleSection = TextStyle(
    fontFamily: display,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const titleCard = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const bodyStrong = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const button = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const label = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Long explanatory text only: Privacy & Data, Welcome.
  static const reading = TextStyle(
    fontFamily: serifText,
    fontSize: 17,
    height: 28 / 17,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// A field's filled ground, with a ring only when focused. A label stays inside the ground.
class MiqdarFieldBorder extends InputBorder {
  const MiqdarFieldBorder({super.borderSide = BorderSide.none, this.radius = 16});

  final double radius;

  @override
  bool get isOutline => false;

  RRect _shape(Rect rect) => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  InputBorder copyWith({BorderSide? borderSide}) =>
      MiqdarFieldBorder(borderSide: borderSide ?? this.borderSide, radius: radius);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_shape(rect).deflate(borderSide.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_shape(rect));

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none) return;
    canvas.drawRRect(_shape(rect).deflate(borderSide.width / 2), borderSide.toPaint());
  }

  @override
  ShapeBorder scale(double t) => MiqdarFieldBorder(borderSide: borderSide.scale(t), radius: radius * t);
}

/// Anything nested in a card sits on `surfaceSunken`, so it does not vanish into the card.
/// Elsewhere, `colorScheme.secondaryContainer` is the ground for a filled control at that level.
ThemeData miqdarCardTheme(ThemeData theme, MiqdarTokens c) => theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(secondaryContainer: c.surfaceSunken),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(fillColor: c.surfaceSunken),
      chipTheme: theme.chipTheme.copyWith(
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primary : c.surfaceSunken,
        ),
      ),
    );

ThemeData miqdarTheme({bool isDark = false}) {
  final c = isDark ? MiqdarTokens.dark : MiqdarTokens.light;
  final brightness = isDark ? Brightness.dark : Brightness.light;

  // Material's `primary` drives FilledButton, so it is the ink action, not the green.
  final scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: brightness).copyWith(
    primary: c.action,
    onPrimary: c.onAction,
    // FilledButton.tonal is the design system's secondary button.
    secondaryContainer: c.surface,
    onSecondaryContainer: c.ink,
    surface: c.bg,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerHighest: c.surfaceSunken,
    surfaceContainerHigh: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerLow: c.surface,
    outline: c.inkMuted,
    outlineVariant: c.border,
    error: c.danger,
    surfaceTint: Colors.transparent,
  );

  MiqdarFieldBorder fieldBorder([BorderSide side = BorderSide.none]) => MiqdarFieldBorder(borderSide: side);

  final baseText = (isDark ? Typography.material2021().white : Typography.material2021().black)
      .apply(fontFamily: MiqdarType.sans, bodyColor: c.ink, displayColor: c.ink);

  final textTheme = baseText.merge(
    TextTheme(
      headlineSmall: MiqdarType.titleScreen.copyWith(color: c.ink),
      titleLarge: MiqdarType.titleSection.copyWith(color: c.ink),
      titleMedium: MiqdarType.titleCard.copyWith(color: c.ink),
      titleSmall: MiqdarType.bodyStrong.copyWith(color: c.ink),
      bodyLarge: MiqdarType.body.copyWith(color: c.ink),
      bodyMedium: MiqdarType.body.copyWith(color: c.inkMuted),
      bodySmall: MiqdarType.caption.copyWith(color: c.inkMuted),
      labelLarge: MiqdarType.button,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: MiqdarPageTransitionsBuilder(),
        TargetPlatform.macOS: MiqdarPageTransitionsBuilder(),
        // Android's own back gesture and button take a screen back there.
        TargetPlatform.android: MiqdarPageTransitionsBuilder(backSwipe: false),
      },
    ),
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: c.ink, size: 24),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionHandleColor: c.primary,
      selectionColor: c.primary.withValues(alpha: 0.25),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12),
      titleTextStyle: MiqdarType.titleSection.copyWith(color: c.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: MiqdarType.body.copyWith(color: c.inkMuted),
      floatingLabelStyle: MiqdarType.label.copyWith(color: c.inkMuted),
      hintStyle: MiqdarType.body.copyWith(fontSize: 16, color: c.inkMuted),
      prefixIconColor: c.inkMuted,
      suffixIconColor: c.inkMuted,
      suffixStyle: MiqdarType.label.copyWith(fontSize: 14, color: c.inkMuted),
      helperStyle: MiqdarType.caption.copyWith(color: c.inkMuted),
      errorStyle: MiqdarType.caption.copyWith(color: c.danger),
      border: fieldBorder(),
      enabledBorder: fieldBorder(),
      disabledBorder: fieldBorder(),
      focusedBorder: fieldBorder(BorderSide(color: c.focus, width: 2)),
      errorBorder: fieldBorder(BorderSide(color: c.danger, width: 2)),
      focusedErrorBorder: fieldBorder(BorderSide(color: c.danger, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: const StadiumBorder(),
        elevation: 0,
        textStyle: MiqdarType.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: c.inkMuted, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: MiqdarType.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const StadiumBorder(),
        textStyle: MiqdarType.bodyStrong,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: c.ink, disabledForegroundColor: c.border),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      showCheckmark: false,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.surface,
      ),
      labelStyle: MiqdarType.bodyStrong.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onPrimary : c.ink,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.onPrimary : c.inkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.surfaceSunken,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(c.primary)),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.onPrimary),
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
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      titleTextStyle: MiqdarType.titleSection.copyWith(color: c.ink),
      contentTextStyle: MiqdarType.body.copyWith(color: c.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: c.surfaceSunken,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.action,
      contentTextStyle: MiqdarType.body.copyWith(color: c.onAction),
      actionTextColor: c.onAction,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
