import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light + dark themes from the brand palette. Display text (headlines, titles, big numbers)
/// uses Barlow Condensed like the web's `--display`; body text stays on the platform font,
/// like the web's system-ui stack. Radii match the web: 0.6rem controls, 1rem cards.
abstract final class AppTheme {
  static const displayFont = 'Barlow Condensed';
  static const radius = 10.0;
  static const radiusLarge = 16.0;

  static ThemeData get light => _build(
        const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.orange,
          onPrimary: Colors.white,
          secondary: AppColors.navy,
          onSecondary: Colors.white,
          error: AppColors.dangerInk,
          onError: Colors.white,
          errorContainer: AppColors.dangerBg,
          onErrorContainer: AppColors.dangerInk,
          surface: AppColors.paper,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
          surfaceContainerLowest: AppColors.paper,
          surfaceContainerLow: AppColors.paper2,
          surfaceContainer: AppColors.paper2,
          surfaceContainerHigh: AppColors.line,
          outline: AppColors.muted,
          outlineVariant: AppColors.line,
          inverseSurface: AppColors.navy,
          onInverseSurface: AppColors.onDark,
        ),
        headline: AppColors.navy,
      );

  static ThemeData get dark => _build(
        const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.orange,
          onPrimary: Colors.white,
          secondary: AppColors.onDark,
          onSecondary: AppColors.navy,
          error: AppColors.dangerOnDark,
          onError: AppColors.navy,
          errorContainer: AppColors.dangerBgDark,
          onErrorContainer: AppColors.dangerOnDark,
          surface: AppColors.navy,
          onSurface: Colors.white,
          onSurfaceVariant: AppColors.onDarkMuted,
          surfaceContainerLowest: AppColors.navy,
          surfaceContainerLow: AppColors.navy2,
          surfaceContainer: AppColors.navy2,
          surfaceContainerHigh: Color(0xFF1B3260),
          outline: AppColors.onDarkMuted,
          outlineVariant: AppColors.onDarkLine,
          inverseSurface: AppColors.paper,
          onInverseSurface: AppColors.ink,
        ),
        headline: Colors.white,
      );

  static ThemeData _build(ColorScheme scheme, {required Color headline}) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    TextStyle? display(TextStyle? s) =>
        s?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w700, color: headline, height: 1.05);
    final text = base.textTheme;
    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displayLarge: display(text.displayLarge),
        displayMedium: display(text.displayMedium),
        displaySmall: display(text.displaySmall),
        headlineLarge: display(text.headlineLarge),
        headlineMedium: display(text.headlineMedium),
        headlineSmall: display(text.headlineSmall),
        titleLarge: display(text.titleLarge),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: display(text.titleLarge)?.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: controlShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: controlShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.brightness == Brightness.light ? AppColors.orangeInk : AppColors.orangeHover,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
