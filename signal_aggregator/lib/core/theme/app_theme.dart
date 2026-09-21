import 'package:flutter/material.dart';

class AppColors {
  static const Color primary    = Color(0xFFE31B23); // rich red
  static const Color background = Color(0xFF0A0A0A); // almost black
  static const Color surface    = Color(0xFF1A1A1A); // dark grey
  static const Color accent     = Color(0xFFFF4444); // bright red
  static const Color negative   = Color(0xFFFF6B6B); // soft red
  static const Color border     = Color(0xFF2A2A2A);
  static const Color buy        = Color(0xFF00C853); // green for BUY
  static const Color sell       = Color(0xFFE31B23); // red for SELL
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
}

class AppTheme {
  static const Color primary = AppColors.primary;
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color accent = AppColors.accent;
  static const Color negative = AppColors.negative;
  static const Color border = AppColors.border;
  static const Color buy = AppColors.buy;
  static const Color sell = AppColors.sell;

  static String fmtClock(DateTime? t) => t == null ? '--:--' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      background: AppColors.background,
      error: AppColors.negative,
    ),
    cardColor: AppColors.surface,
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
  );
}
