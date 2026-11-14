import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Supported ReadZen application themes complying with WCAG AA contrast.
enum AppThemeMode {
  paperLight('Paper Light', 'paper_light'),
  warmSepia('Warm Sepia', 'warm_sepia'),
  midnightDark('Midnight Dark', 'midnight_dark');

  const AppThemeMode(this.label, this.storageKey);

  final String label;
  final String storageKey;

  static AppThemeMode fromStorageKey(String? key) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.storageKey == key,
      orElse: () => AppThemeMode.paperLight,
    );
  }
}

/// Builds Material 3 themes for Paper Light, Warm Sepia, and Midnight Dark.
class AppTheme {
  const AppTheme._();

  static ThemeData fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.paperLight:
        const scheme = ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF2D5A4C),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFD5EBE3),
          onPrimaryContainer: Color(0xFF102A21),
          secondary: Color(0xFF53635B),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFE7EFEA),
          onSecondaryContainer: Color(0xFF153229),
          tertiary: Color(0xFF8B4A2B),
          onTertiary: Color(0xFFFFFFFF),
          error: Color(0xFFB3261E),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFAF8F5),
          onSurface: Color(0xFF1E1D1B),
          surfaceContainerHighest: Color(0xFFECE8E0),
          onSurfaceVariant: Color(0xFF49453E),
          outline: Color(0xFF7A756D),
        );
        return _buildTheme(scheme, const Color(0xFFF3EFE8));

      case AppThemeMode.warmSepia:
        const scheme = ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF8A4B24),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFEAD3BE),
          onPrimaryContainer: Color(0xFF331807),
          secondary: Color(0xFF6B5742),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFE7D8BC),
          onSecondaryContainer: Color(0xFF2C1B0E),
          tertiary: Color(0xFF4C6355),
          onTertiary: Color(0xFFFFFFFF),
          error: Color(0xFFB3261E),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFF4ECD8),
          onSurface: Color(0xFF33261A),
          surfaceContainerHighest: Color(0xFFE5D9BE),
          onSurfaceVariant: Color(0xFF564433),
          outline: Color(0xFF836F5A),
        );
        return _buildTheme(scheme, const Color(0xFFEDE2C9));

      case AppThemeMode.midnightDark:
        const scheme = ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF7BB69E),
          onPrimary: Color(0xFF0E1D17),
          primaryContainer: Color(0xFF1E4436),
          onPrimaryContainer: Color(0xFFD5EDE3),
          secondary: Color(0xFFA7BEB3),
          onSecondary: Color(0xFF17261F),
          secondaryContainer: Color(0xFF212B27),
          onSecondaryContainer: Color(0xFFD5EDE3),
          tertiary: Color(0xFFE0A97B),
          onTertiary: Color(0xFF361D0A),
          error: Color(0xFFF2B8B5),
          onError: Color(0xFF601410),
          surface: Color(0xFF121417),
          onSurface: Color(0xFFE8EAED),
          surfaceContainerHighest: Color(0xFF22262B),
          onSurfaceVariant: Color(0xFFB8BEC6),
          outline: Color(0xFF6F7680),
        );
        return _buildTheme(scheme, const Color(0xFF1A1D21));
    }
  }

  static ThemeData _buildTheme(ColorScheme scheme, Color cardBackground) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: scheme.secondaryContainer,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
    );
  }

  /// Computes the WCAG 2.1 contrast ratio between [foreground] and [background].
  static double contrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color color) {
    double linearize(double channel) {
      if (channel <= 0.03928) {
        return channel / 12.92;
      }
      return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize(color.r);
    final g = linearize(color.g);
    final b = linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
}
