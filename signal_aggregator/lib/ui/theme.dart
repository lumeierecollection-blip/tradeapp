import 'package:flutter/material.dart';

import '../models/validated_signal.dart';

class AppTheme {
  // ---------------------------------------------------------------------
  // Palette — red & black. Every colour used by the UI lives here; widgets
  // should reference these constants (or Theme.of(context)) rather than
  // hard-coding literals.
  // ---------------------------------------------------------------------

  // Surfaces, darkest to lightest.
  static const Color bg = Color(0xFF0A0A0A);
  static const Color surfaceDeep = Color(0xFF101010);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceAlt = Color(0xFF1A1A1A);
  static const Color surfaceRaised = Color(0xFF202020);
  static const Color line = Color(0xFF2A2A2A);

  /// Neutral fill behind progress bars and gauges.
  static const Color track = Color(0xFF262626);

  // Text, brightest to dimmest.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textBody = Color(0xFFD5D5D5);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDim = Color(0xFF8A8A8A);
  static const Color textMuted = Color(0xFF6E6E6E);

  /// Brand red. Used as a *fill* (buttons, badges) with [onAccent] on top.
  /// Too dark to read as text on black, so never use it for type or icons.
  static const Color brandRed = Color(0xFFE31B23);

  /// Bright red. The interactive accent for text, icons and active states —
  /// contrast 5.8:1 on [bg], so it passes WCAG AA at body sizes.
  static const Color accent = Color(0xFFFF4444);

  /// Deep red for pressed/hover states and subtle washes.
  static const Color accentSoft = Color(0xFFC41017);

  /// Light red, the far end of [accentGradient].
  static const Color accent2 = Color(0xFFFF7A6B);

  /// Foreground for anything sitting on [brandRed] or [accentSoft].
  static const Color onAccent = Color(0xFFFFFFFF);

  // Direction / P&L semantics. Loss and SELL take the theme red; profit and
  // BUY keep green, because separating them by red-on-red alone is not
  // readable — and colour-blind users lose the distinction entirely.
  static const Color buy = Color(0xFF00C853);
  static const Color sell = Color(0xFFFF4444);
  static const Color warn = Color(0xFFFFB020);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandRed, accent2],
  );

  /// Backing for the headline balance panel — black with a red ember.
  static const LinearGradient balanceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF23090B), Color(0xFF120C0D)],
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandRed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      onSurface: textPrimary,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent2,
      error: sell,
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
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: line, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: textPrimary),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDeep,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brandRed.withValues(alpha: 0.22),
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
            (states) => states.contains(WidgetState.selected) ? onAccent : textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? brandRed : null,
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
        linearTrackColor: track,
        circularTrackColor: track,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandRed.withValues(alpha: 0.18),
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: brandRed,
          foregroundColor: onAccent,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onAccent : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brandRed : track,
        ),
        trackOutlineColor: WidgetStateProperty.all(line),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brandRed : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(onAccent),
        side: const BorderSide(color: line, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : textMuted,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: track,
        thumbColor: accent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: brandRed,
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceAlt,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: accent,
        textColor: textPrimary,
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
