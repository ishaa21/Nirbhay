import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    final textTheme = GoogleFonts.manropeTextTheme(baseTheme.textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        error: AppColors.error,
        onError: AppColors.onError,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w500,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontFamily: GoogleFonts.manrope().fontFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      // Configure general input decoration theme to match input styling guidelines
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh.withOpacity(0.4),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontSize: 10,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.outline,
        ),
      ),
      // Configure checkbox style
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDim;
          }
          return null;
        }),
        side: const BorderSide(color: AppColors.outlineVariant, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}
