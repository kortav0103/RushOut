import 'package:flutter/material.dart';

class DaylightColors {
  DaylightColors._();

  static const Color canvasBg = Color(0xFFF4EFE6);
  static const Color patternDot = Color(0xFFE6DEC8);

  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceLip = Color(0xFFDCD3C4);

  static const Color lockedSurface = Color(0xFFE7E0D4);
  static const Color lockedLip = Color(0xFFD5CEC0);
  static const Color lockedInk = Color(0xFFA39A8C);

  static const Color brandRed = Color(0xFFFF4D4D);
  static const Color brandRedLip = Color(0xFFC92A2A);

  static const Color frontierFill = Color(0xFFFFF8EB);
  static const Color frontierAmber = Color(0xFFFF9F1C);
  static const Color frontierAmberLip = Color(0xFFE08600);

  static const Color completedMint = Color(0xFF2EC4B6);
  static const Color completedMintLip = Color(0xFF1F9D91);
  static const Color starGold = Color(0xFFFFB703);
  static const Color emptyStar = Color(0xFFE3DDD1);

  static const Color inkPrimary = Color(0xFF1E242B);
  static const Color inkSecondary = Color(0xFF6C757D);
  static const Color asphaltBadge = Color(0xFF2B303A);
}

class DaylightTypography {
  DaylightTypography._();

  static TextStyle rounded({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w800,
    Color color = DaylightColors.inkPrimary,
    double? letterSpacing,
    double? height,
    bool tabular = false,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }
}
