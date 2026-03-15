import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/providers/mentor_providers.dart';

class MusaiTheme {
  // Brand Palette (Sanctuary Focus - V2.0)
  static const Color deepSpaceTeal = Color(0xFF244F69);
  static const Color parchment = Color(0xFFCDD2BB);
  static const Color sovereignBlack = Color(0xFF0D1117);
  
  // Mentor Primary Colors
  static const Color neonCyan = Color(0xFF00FFD1);
  static const Color cosmicLatte = Color(0xFFFFF8E7);
  static const Color metallicGold = Color(0xFFD4AF37);

  static ThemeData getTheme(MentorState mentor) {
    final Color primary = mentor.primaryColor;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: sovereignBlack,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: sovereignBlack,
        secondary: deepSpaceTeal,
        surface: sovereignBlack,
        onSurface: parchment.withAlpha(204), // Subtle parchment text
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: parchment,
          letterSpacing: 2,
        ),
        headlineMedium: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: parchment,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: parchment.withAlpha(230),
        ),
        labelLarge: GoogleFonts.spaceMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: primary.withAlpha(204),
          letterSpacing: 1.2,
        ),
      ),
      iconTheme: IconThemeData(
        color: primary,
        size: 24,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  // Legacy support or fallback
  static ThemeData get darkTheme => getTheme(MentorState(
    activeMentor: Mentor.eute,
    name: "EUTE",
    role: "SURGICAL PURIST",
    primaryColor: neonCyan,
    borderRadius: 2.0,
    voiceName: "Aoede",
    systemInstruction: "I am EUTE. The Auditory Guardian of MusAI. Neon-Technical, precise, corrective, and minimalist. I analyze the Chief Architect's violin performance (pitch/tempo) from the 16kHz stream and proactively output 24kHz feedback (pitch/tempo maps). ALWAYS start the session with: 'I am EUTE. The sync is locked. Let us begin the technical audit.'",
  ));
}
