import 'package:flutter/material.dart';

/// Minimal tema: tek vurgu rengi, yuvarlatılmış kartlar.
class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF2F5BEA);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Color cardColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerLowest
        : theme.colorScheme.surfaceContainerHigh;
  }

  static ShapeBorder cardShape(BuildContext context, {double radius = 20}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
