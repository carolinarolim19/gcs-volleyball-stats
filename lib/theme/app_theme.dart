import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF0F5C99);
  static const Color darkBlue = Color(0xFF093E6A);
  static const Color lightBlue = Color(0xFFEAF4FC);
  static const Color gold = Color(0xFFF5C542);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
      ),

      scaffoldBackgroundColor: Colors.white,

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(double.infinity, 70),
        ),
      ),
    );
  }
}