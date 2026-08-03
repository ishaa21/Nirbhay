import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF060E20);
  static const Color surface = Color(0xFF060E20);
  
  // Surface containers (Z-axis stack)
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color surfaceContainerLow = Color(0xFF091328);
  static const Color surfaceContainer = Color(0xFF0F1930);
  static const Color surfaceContainerHigh = Color(0xFF141F38);
  static const Color surfaceContainerHighest = Color(0xFF192540);
  
  static const Color surfaceBright = Color(0xFF1F2B49);
  static const Color surfaceVariant = Color(0xFF192540);

  // Accents & Brand Colors
  static const Color primary = Color(0xFFA7A5FF);
  static const Color primaryDim = Color(0xFF645EFB);
  static const Color secondary = Color(0xFFAC8AFF);
  static const Color secondaryContainer = Color(0xFF5516BE);
  static const Color onSecondaryContainer = Color(0xFFD9C8FF);

  // Text colors
  static const Color onBackground = Color(0xFFDEE5FF);
  static const Color onSurface = Color(0xFFDEE5FF);
  static const Color onSurfaceVariant = Color(0xFFA3AAC4);
  static const Color onPrimaryFixed = Color(0xFF000000);
  static const Color onSecondary = Color(0xFF280067);
  static const Color onSecondaryFixed = Color(0xFF40009B);

  // Borders & Dividers
  static const Color outline = Color(0xFF6D758C);
  static const Color outlineVariant = Color(0xFF40485D);

  // Status & Errors
  static const Color error = Color(0xFFFF6E84);
  static const Color errorContainer = Color(0xFFA70138);
  static const Color onError = Color(0xFF490013);
  static const Color onErrorContainer = Color(0xFFFFB2B9);

  // Ambient Shadow Color
  static const Color shadowColor = Color(0x4D000000); // Soft dark indigo-tinted shadow
}
