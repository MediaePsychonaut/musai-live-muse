import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MusaiTheme {
  // Brand Palette (EUTE Focus)
  static const Color obsidianaBlack = Color(0xFF0A0A0A);
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color deepGrey = Color(0xFF1A1A1A);
  static const Color matrixGreen = Color(0xFF00FF41);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianaBlack,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        onPrimary: obsidianaBlack,
        surface: deepGrey,
        onSurface: Colors.white,
        secondary: matrixGreen,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: neonCyan,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: GoogleFonts.robotoMono(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: neonCyan.withAlpha(204), // 0.8 * 255
        ),
      ),
      iconTheme: const IconThemeData(
        color: neonCyan,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianaBlack,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
