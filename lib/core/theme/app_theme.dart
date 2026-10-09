import 'package:flutter/material.dart';

/// Seriolab design system — "Midnight Indigo & Violet".
///
/// A cinematic, modern dark theme built around deep midnight indigo,
/// electric iris/violet accents, vibrant cyan progress indicators,
/// and refined slate typography.
abstract final class AppColors {
  // Midnight Indigo & Violet Palette
  static const Color background = Color(0xFF0D0F17); // Deep midnight indigo
  static const Color surface = Color(0xFF171B26); // Cards and container surface
  static const Color surfaceHigh = Color(0xFF1E2333); // Elevated cards, search inputs
  static const Color outline = Color(0xFF232938); // Subtle borders and dividers

  // Primary Accent: Electric Iris / Violet
  static const Color primary = Color(0xFF7C5CFC);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary Accent: Vibrant Cyan for progress & watched states
  static const Color secondary = Color(0xFF38BDF8);
  static const Color onSecondary = Color(0xFF0D0F17);

  // Convenience aliases for existing widgets
  static const Color accent = Color(0xFF7C5CFC); // Replaces former TV Time yellow
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color violet = Color(0xFF7C5CFC);

  // Typography
  static const Color textPrimary = Color(0xFFF8FAFC); // Clean off-white
  static const Color textSecondary = Color(0xFF94A3B8); // Soft slate gray
  static const Color textMuted = Color(0xFF64748B); // Dim slate

  // Navigation bar
  static const Color navInactive = Color(0xFF64748B);

  // Functional semantic states
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color danger = Color(0xFFEF4444); // Crimson
  static const Color info = Color(0xFF38BDF8); // Cyan
  static const Color warning = Color(0xFFF59E0B); // Amber
}

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.outline,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.navInactive,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.navInactive,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline, width: 0.8),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.outline, width: 0.8),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 0.8,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
        linearTrackColor: AppColors.outline,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
