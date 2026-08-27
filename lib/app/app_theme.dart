import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: isDark ? const Color(0xFF111827) : AppColors.card,
          error: AppColors.danger,
        ).copyWith(
          onSurface: isDark ? const Color(0xFFF8FAFC) : AppColors.foreground,
          outlineVariant: isDark ? const Color(0xFF334155) : AppColors.border,
          surfaceContainerLowest: isDark
              ? const Color(0xFF0F172A)
              : AppColors.background,
          surfaceContainer: isDark ? const Color(0xFF1E293B) : AppColors.muted,
          onSurfaceVariant: isDark
              ? const Color(0xFFCBD5E1)
              : AppColors.mutedForeground,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
