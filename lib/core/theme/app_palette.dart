import 'package:flutter/material.dart';

/// Raw brand colours. Nothing outside `core/theme` should read these directly —
/// widgets consume semantic tokens from [AppColors] via `context.colors`.
abstract final class Brand {
  // Shared accents (identical hue family across themes, tuned per mode below).
  static const primaryLight = Color(0xFF4F7CFF);
  static const primaryDark = Color(0xFF6D93FF);

  static const successLight = Color(0xFF22C55E);
  static const successDark = Color(0xFF34D399);

  static const warningLight = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFFBBF24);

  static const dangerLight = Color(0xFFEF4444);
  static const dangerDark = Color(0xFFF87171);

  static const xpLight = Color(0xFFFFD54A);
  static const xpDark = Color(0xFFFFDD6B);

  static const streakLight = Color(0xFFFF7A45);
  static const streakDark = Color(0xFFFF9366);

  /// Board accent choices offered in the board editor.
  ///
  /// Stored as ARGB ints because that is what [Board] persists — keeping the
  /// canonical form here avoids a lossy Color→int conversion at every call
  /// site (and the API for that conversion has churned across Flutter
  /// versions).
  static const boardAccentValues = <int>[
    0xFF4F7CFF, // blue
    0xFF8B5CF6, // violet
    0xFFEC4899, // pink
    0xFFEF4444, // red
    0xFFF59E0B, // amber
    0xFF22C55E, // green
    0xFF14B8A6, // teal
    0xFF0EA5E9, // sky
    0xFF64748B, // slate
  ];

  static const boardAccents = <Color>[
    Color(0xFF4F7CFF),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF14B8A6),
    Color(0xFF0EA5E9),
    Color(0xFF64748B),
  ];
}

/// Semantic colour tokens. Every surface, text and state colour in the app
/// resolves through one of these fields so light/dark stay in lockstep.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.primaryText,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.xp,
    required this.streak,
    required this.scrim,
    required this.shadow,
  });

  final Brightness brightness;

  /// App canvas, behind every scrollable.
  final Color background;

  /// Default card / sheet fill.
  final Color surface;

  /// Recessed areas — kanban column beds, input fills.
  final Color surfaceSunken;

  /// Elevated above [surface] — dragged cards, menus.
  final Color surfaceRaised;

  /// Glass / blur overlays (already carries alpha).
  final Color surfaceOverlay;

  final Color border;
  final Color borderStrong;

  /// >= 4.5:1 on [background] and [surface].
  final Color textPrimary;

  /// >= 4.5:1 on [background] — safe for body copy.
  final Color textSecondary;

  /// >= 3:1 — labels and non-essential metadata only.
  final Color textTertiary;

  final Color primary;
  final Color onPrimary;

  /// Contrast-safe primary for small text on [surface].
  final Color primaryText;

  /// Tinted primary fill for chips and selected states.
  final Color primarySoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  final Color xp;
  final Color streak;

  /// Modal barrier — 40–60% black so foreground stays legible.
  final Color scrim;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEFF1F5),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xE6FFFFFF),
    border: Color(0xFFE4E7EC),
    borderStrong: Color(0xFFCFD4DC),
    textPrimary: Color(0xFF12161F),
    textSecondary: Color(0xFF64707F),
    textTertiary: Color(0xFF8A94A3),
    primary: Brand.primaryLight,
    onPrimary: Color(0xFFFFFFFF),
    primaryText: Color(0xFF3A63E0),
    primarySoft: Color(0x1A4F7CFF),
    success: Brand.successLight,
    successSoft: Color(0x1A22C55E),
    warning: Brand.warningLight,
    warningSoft: Color(0x1FF59E0B),
    danger: Brand.dangerLight,
    dangerSoft: Color(0x1AEF4444),
    xp: Brand.xpLight,
    streak: Brand.streakLight,
    scrim: Color(0x8A0B0D12),
    shadow: Color(0x14101828),
  );

  /// Not an inversion of [light]: the dark canvas is a cool near-black, surfaces
  /// step up in luminance rather than down, and accents are lifted so they keep
  /// their contrast ratio against a dark bed.
  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF0E1014),
    surface: Color(0xFF181C23),
    surfaceSunken: Color(0xFF14171D),
    surfaceRaised: Color(0xFF1F242D),
    surfaceOverlay: Color(0xE61A1F27),
    border: Color(0xFF262B34),
    borderStrong: Color(0xFF39404C),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFFA0A7B4),
    textTertiary: Color(0xFF79808D),
    primary: Brand.primaryDark,
    onPrimary: Color(0xFF07132E),
    primaryText: Brand.primaryDark,
    primarySoft: Color(0x246D93FF),
    success: Brand.successDark,
    successSoft: Color(0x2434D399),
    warning: Brand.warningDark,
    warningSoft: Color(0x24FBBF24),
    danger: Brand.dangerDark,
    dangerSoft: Color(0x24F87171),
    xp: Brand.xpDark,
    streak: Brand.streakDark,
    scrim: Color(0xA605070B),
    shadow: Color(0x66000000),
  );

  /// Readable foreground for an arbitrary board accent colour.
  static Color onAccent(Color accent) =>
      accent.computeLuminance() > 0.55 ? const Color(0xFF12161F) : Colors.white;

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceSunken,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? onPrimary,
    Color? primaryText,
    Color? primarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? xp,
    Color? streak,
    Color? scrim,
    Color? shadow,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryText: primaryText ?? this.primaryText,
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceOverlay: c(surfaceOverlay, other.surfaceOverlay),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryText: c(primaryText, other.primaryText),
      primarySoft: c(primarySoft, other.primarySoft),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      xp: c(xp, other.xp),
      streak: c(streak, other.streak),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
    );
  }
}
