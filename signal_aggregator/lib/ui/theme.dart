import 'package:flutter/material.dart';

import '../models/validated_signal.dart';

class AppTheme {
  // Palette — warm dark, low noise.
  static const Color bg = Color(0xFF0A0D12);
  static const Color surface = Color(0xFF12161E);
  static const Color surfaceAlt = Color(0xFF171D27);
  static const Color line = Color(0xFF222A36);

  static const Color textPrimary = Color(0xFFEDF1F7);
  static const Color textSecondary = Color(0xFF97A1B3);
  static const Color textMuted = Color(0xFF5F6878);

  static const Color accent = Color(0xFF5EEAD4);
  static const Color accentSoft = Color(0xFF2DD4BF);
  static const Color accent2 = Color(0xFF38BDF8);
  static const Color buy = Color(0xFF34D399);
  static const Color sell = Color(0xFFFB7185);
  static const Color warn = Color(0xFFFBBF24);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      onSurface: textPrimary,
      primary: accent,
      secondary: accent,
      outline: line,
      surfaceContainerHighest: surfaceAlt,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      brightness: Brightness.dark,
      fontFamilyFallback: const ['Roboto', 'SF Pro Text'],
      dividerColor: line,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        bodyMedium: const TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
        bodyLarge: const TextStyle(color: textPrimary, fontSize: 16, height: 1.5),
        titleLarge: const TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        labelLarge: const TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceAlt,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceAlt,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0E1219),
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? accent : textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? accent : textMuted,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? bg : textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? accentSoft : null,
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          side: WidgetStateProperty.all(const BorderSide(color: line)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: line,
        circularTrackColor: line,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentSoft.withValues(alpha: 0.16),
          foregroundColor: accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: line),
          foregroundColor: textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: accent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      ),
    );
  }

  static Color directionColor(Direction d) => switch (d) {
        Direction.buy => buy,
        Direction.sell => sell,
        Direction.wait => warn,
      };

  static String fmtPrice(double v) =>
      v >= 1000 ? v.toStringAsFixed(0) : v >= 1 ? v.toStringAsFixed(4) : v.toStringAsExponential(2);

  /// "14:32" — exact clock time, local.
  static String fmtClock(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// "Today · 14:32" or "Aug 6 · 14:32".
  static String fmtFullTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final day = local.day == now.day && local.month == now.month && local.year == now.year
        ? 'Today'
        : '${_months[local.month - 1]} ${local.day}';
    return '$day · ${fmtClock(local)}';
  }

  /// "2h 33m"
  static String fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h <= 0) return '${m}m';
    if (m <= 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// "in 2h 33m" or "now" when the moment has arrived.
  static String fmtUntil(DateTime until, {DateTime? from}) {
    final d = until.difference(from ?? DateTime.now());
    if (d.isNegative || d.inMinutes < 1) return 'now';
    return 'in ${fmtDuration(d)}';
  }

  static String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// A large clock time styled with tabular figures.
  static TextStyle clockStyle({double size = 44, Color color = textPrimary}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 1.5,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
