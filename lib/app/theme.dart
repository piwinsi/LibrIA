import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF97A18D);
  static const secondary = Color(0xFFA27554);
  static const background = Color(0xFFF6F3EC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2E2B24);
  static const textSecondary = Color(0xFF6E685D);
  static const success = Color(0xFF5C6E4F);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
  );
}
