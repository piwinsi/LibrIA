import 'package:flutter/material.dart';

import '../models/book.dart';

class AppColors {
  static const primary = Color(0xFF97A18D);
  static const primaryDark = Color(0xFF5C6E4F);
  static const secondary = Color(0xFFA27554);
  static const background = Color(0xFFF6F3EC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2E2B24);
  static const textSecondary = Color(0xFF6E685D);
  static const success = Color(0xFF5C6E4F);
  static const warning = Color(0xFFC08A3E);
  static const danger = Color(0xFFA6473B);
  static const star = Color(0xFFD9A441);

  /// Colores para portadas sin imagen.
  static const coverPalette = [
    Color(0xFF97A18D),
    Color(0xFFA27554),
    Color(0xFF7D8FA3),
    Color(0xFFB98B82),
    Color(0xFF8C7BA0),
    Color(0xFF6F9A93),
    Color(0xFFC3A16B),
  ];
}

/// Presentación visual de cada estado de lectura (RNF-05: consistencia).
extension ReadingStatusStyle on ReadingStatus {
  String get label => switch (this) {
        ReadingStatus.pending => 'Pendiente',
        ReadingStatus.reading => 'En lectura',
        ReadingStatus.paused => 'Pausado',
        ReadingStatus.completed => 'Terminado',
        ReadingStatus.abandoned => 'Abandonado',
      };

  String get pluralLabel => switch (this) {
        ReadingStatus.pending => 'Pendientes',
        ReadingStatus.reading => 'En lectura',
        ReadingStatus.paused => 'Pausados',
        ReadingStatus.completed => 'Terminados',
        ReadingStatus.abandoned => 'Abandonados',
      };

  IconData get icon => switch (this) {
        ReadingStatus.pending => Icons.bookmark_border,
        ReadingStatus.reading => Icons.auto_stories,
        ReadingStatus.paused => Icons.pause_circle_outline,
        ReadingStatus.completed => Icons.check_circle_outline,
        ReadingStatus.abandoned => Icons.do_not_disturb_on_outlined,
      };

  Color get color => switch (this) {
        ReadingStatus.pending => AppColors.textSecondary,
        ReadingStatus.reading => AppColors.secondary,
        ReadingStatus.paused => AppColors.warning,
        ReadingStatus.completed => AppColors.success,
        ReadingStatus.abandoned => AppColors.danger,
      };
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primaryDark,
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: AppColors.surface,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
