import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';

class AppTheme {
  // ─── Dark theme ───────────────────────────────────────────────
  static ThemeData get dark => _build(Brightness.dark, NexColors.dark);

  // ─── Light theme ──────────────────────────────────────────────
  static ThemeData get light => _build(Brightness.light, NexColors.light);

  static ThemeData _build(Brightness brightness, NexColors c) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness:      brightness,
        primary:         NexColors.primary,
        onPrimary:       Colors.white,
        secondary:       NexColors.accent,
        onSecondary:     Colors.white,
        error:           NexColors.error,
        onError:         Colors.white,
        surface:         c.surface,
        onSurface:       c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:        c.background,
        surfaceTintColor:       Colors.transparent,
        elevation:              0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:            Colors.transparent,
          statusBarIconBrightness:   isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:       isDark ? Brightness.dark  : Brightness.light,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: TextStyle(
          color:      c.textPrimary,
          fontSize:   18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardTheme(
        color:     c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 0.5, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NexColors.primary,
          foregroundColor: Colors.white,
          elevation:       0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: NexColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   c.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NexColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.textMuted),
      ),
      textTheme: TextTheme(
        displayLarge:  TextStyle(color: c.textPrimary,   fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium:TextStyle(color: c.textPrimary,   fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge:    TextStyle(color: c.textPrimary,   fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium:   TextStyle(color: c.textPrimary,   fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge:     TextStyle(color: c.textPrimary,   fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium:    TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge:    TextStyle(color: c.textPrimary,   fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        labelSmall:    TextStyle(color: c.textMuted,     fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      ),
    );
  }
}
