import 'package:flutter/material.dart';

const kPrimary = Color(0xFF1E88E5);
const kPrimaryDark = Color(0xFF0D47A1);
const kAccent = Color(0xFFFFB300);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    primary: kPrimary,
    secondary: kAccent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F8FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}