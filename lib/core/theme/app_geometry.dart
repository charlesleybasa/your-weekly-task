import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Spacing, radius and elevation tokens.
///
/// Spacing follows a 4/8 rhythm; section spacing steps 16 → 24 → 32 → 48 so
/// hierarchy is legible without eyeballing arbitrary values.
@immutable
class AppGeometry extends ThemeExtension<AppGeometry> {
  const AppGeometry({
    required this.gutter,
    required this.density,
  });

  /// Horizontal page inset. Widens on tablets/landscape via [forWidth].
  final double gutter;

  /// 1.0 on phones, slightly larger on big screens to open the layout up.
  final double density;

  static const phone = AppGeometry(gutter: 20, density: 1.0);
  static const tablet = AppGeometry(gutter: 32, density: 1.08);
  static const desktop = AppGeometry(gutter: 48, density: 1.12);

  /// Adaptive gutters by breakpoint — required so content does not run
  /// edge-to-edge on a tablet.
  static AppGeometry forWidth(double width) {
    if (width >= 1000) return desktop;
    if (width >= 600) return tablet;
    return phone;
  }

  // ---- Spacing scale (4/8 rhythm) ----
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  // ---- Section rhythm ----
  static const double sectionTight = 16;
  static const double section = 24;
  static const double sectionLoose = 32;

  // ---- Corner radii ----
  static const Radius rSm = Radius.circular(12);
  static const Radius rMd = Radius.circular(16);
  static const Radius rLg = Radius.circular(20);
  static const Radius rXl = Radius.circular(24);
  static const Radius rSheet = Radius.circular(28);

  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(999));
  static const BorderRadius brSheet =
      BorderRadius.vertical(top: rSheet);

  // ---- Icon size tokens ----
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 26;

  /// Minimum interactive area. 48 satisfies both the iOS 44pt and the
  /// Android 48dp floor.
  static const double minTapTarget = 48;

  /// The maximum comfortable measure for long-form text.
  static const double readableMaxWidth = 640;

  /// Content column cap so cards do not stretch absurdly wide on desktop.
  static const double contentMaxWidth = 900;

  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: gutter);

  // ---- Shadows ----
  /// Resting card shadow. Deliberately soft and low-contrast; depth comes from
  /// the border in light mode and from surface luminance in dark mode.
  static List<BoxShadow> rest(AppColors c) => [
        BoxShadow(
          color: c.shadow,
          blurRadius: c.isDark ? 18 : 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> raised(AppColors c) => [
        BoxShadow(
          color: c.shadow,
          blurRadius: c.isDark ? 30 : 22,
          spreadRadius: -2,
          offset: const Offset(0, 10),
        ),
      ];

  /// Deep shadow for an actively dragged element.
  static List<BoxShadow> dragging(AppColors c, Color accent) => [
        BoxShadow(
          color: c.isDark ? const Color(0xAA000000) : const Color(0x33101828),
          blurRadius: 34,
          spreadRadius: -4,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.28),
          blurRadius: 26,
          spreadRadius: -8,
          offset: const Offset(0, 6),
        ),
      ];

  @override
  AppGeometry copyWith({double? gutter, double? density}) => AppGeometry(
        gutter: gutter ?? this.gutter,
        density: density ?? this.density,
      );

  @override
  AppGeometry lerp(covariant AppGeometry? other, double t) {
    if (other == null) return this;
    return AppGeometry(
      gutter: lerpDouble(gutter, other.gutter, t),
      density: lerpDouble(density, other.density, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
