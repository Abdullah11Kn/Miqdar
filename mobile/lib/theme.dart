import 'package:flutter/material.dart';

class MiqdarColors {
  static const primary = Color(0xFF0B7A3E);
  static const dark = Color(0xFF17372B);
  static const muted = Color(0xFF486258);
  static const background = Color(0xFFF7FAF8);
  static const softGreen = Color(0xFFE9F7EE);
  static const border = Color(0xFFDDE9E2);
  static const lime = Color(0xFF83C937);
  static const warning = Color(0xFFE99A35);
  static const danger = Color(0xFFD64B45);
}

ThemeData miqdarTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MiqdarColors.primary,
    primary: MiqdarColors.primary,
    surface: Colors.white,
    error: MiqdarColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MiqdarColors.background,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark),
      titleMedium: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark),
      bodyMedium: TextStyle(color: MiqdarColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MiqdarColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MiqdarColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
