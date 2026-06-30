import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Medical & Clinical Palette
  static const Color primaryTeal = Color(0xFF0F766E); // Deep medical teal
  static const Color primaryTealLight = Color(0xFF14B8A6); // Bright teal
  static const Color accentIndigo = Color(0xFF6366F1); // Indigo accents
  
  // Status Colors
  static const Color successGreen = Color(0xFF10B981); // Low risk / vaccinated
  static const Color warningAmber = Color(0xFFF59E0B); // Intermediate risk
  static const Color dangerRed = Color(0xFFEF4444); // High risk / active hepatitis
  static const Color infoBlue = Color(0xFF3B82F6); // Neutral / uninfected

  // Dark Mode Slate Colors
  static const Color darkBg = Color(0xFF0F172A); // Slate 900
  static const Color darkCard = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryTeal,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryTeal,
        secondary: AppColors.accentIndigo,
        surface: AppColors.lightCard,
        background: AppColors.lightBg,
        error: AppColors.dangerRed,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      cardTheme: const CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: AppColors.lightTextPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.lightBorder, thickness: 1),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryTealLight,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryTealLight,
        secondary: AppColors.accentIndigo,
        surface: AppColors.darkCard,
        background: AppColors.darkBg,
        error: AppColors.dangerRed,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      cardTheme: const CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.darkBorder, thickness: 1),
    );
  }

  // Premium UI Box Decoration Helpers (e.g. Glassmorphism or sleek cards)
  static BoxDecoration glassBox(BuildContext context, {double blur = 10}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark 
          ? AppColors.darkCard.withOpacity(0.7) 
          : AppColors.lightCard.withOpacity(0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )
      ],
    );
  }
}
