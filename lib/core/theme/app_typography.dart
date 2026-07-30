import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale.
///
/// Two families: Plus Jakarta Sans carries display/headline weight (it has more
/// personality in the large sizes), Inter handles everything at UI scale where
/// legibility beats character.
abstract final class AppTypography {
  /// Numerals that do not jitter as they count — used by the timer, XP counter
  /// and every animated statistic.
  static const tabular = [FontFeature.tabularFigures()];

  static TextTheme build(Color primary, Color secondary) {
    final display = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.interTextTheme();

    return TextTheme(
      displayLarge: display.displayLarge!.copyWith(
        fontSize: 44,
        height: 1.08,
        letterSpacing: -1.4,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      displayMedium: display.displayMedium!.copyWith(
        fontSize: 34,
        height: 1.12,
        letterSpacing: -1.0,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      displaySmall: display.displaySmall!.copyWith(
        fontSize: 28,
        height: 1.16,
        letterSpacing: -0.7,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: display.headlineMedium!.copyWith(
        fontSize: 24,
        height: 1.2,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineSmall: display.headlineSmall!.copyWith(
        fontSize: 20,
        height: 1.25,
        letterSpacing: -0.35,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: body.titleLarge!.copyWith(
        fontSize: 17,
        height: 1.3,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: body.titleMedium!.copyWith(
        fontSize: 15,
        height: 1.35,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: body.titleSmall!.copyWith(
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // 16px base body with 1.5 line-height.
      bodyLarge: body.bodyLarge!.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: body.bodyMedium!.copyWith(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: body.bodySmall!.copyWith(
        fontSize: 12.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: body.labelLarge!.copyWith(
        fontSize: 14.5,
        height: 1.2,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: body.labelMedium!.copyWith(
        fontSize: 12.5,
        height: 1.2,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: body.labelSmall!.copyWith(
        fontSize: 11.5,
        height: 1.2,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
    );
  }

  /// The countdown readout. Huge, tight, tabular so digits hold their column.
  static TextStyle timerDigits(Color color, {double size = 64}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: 1.0,
        letterSpacing: -2.5,
        fontWeight: FontWeight.w800,
        fontFeatures: tabular,
        color: color,
      );

  /// Large animated statistic (XP totals, percentages, streak counts).
  static TextStyle stat(Color color, {double size = 26}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: 1.05,
        letterSpacing: -0.9,
        fontWeight: FontWeight.w800,
        fontFeatures: tabular,
        color: color,
      );
}
