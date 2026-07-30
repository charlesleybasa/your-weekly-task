import 'package:flutter/material.dart';

import '../theme/app_geometry.dart';
import '../theme/app_motion.dart';
import '../theme/app_palette.dart';

/// Ergonomic access to theme tokens. Keeps call sites at
/// `context.colors.textSecondary` instead of a four-part Theme lookup.
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;

  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  AppMotion get motion =>
      Theme.of(this).extension<AppMotion>() ?? AppMotion.full;

  /// Geometry is resolved from the live width rather than the stored extension
  /// so it stays correct across rotation without a theme rebuild.
  AppGeometry get geometry => AppGeometry.forWidth(MediaQuery.sizeOf(this).width);

  MediaQueryData get mq => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get safeArea => MediaQuery.paddingOf(this);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isCompact => MediaQuery.sizeOf(this).width < 600;
  bool get isTablet => MediaQuery.sizeOf(this).width >= 600;
  bool get isWide => MediaQuery.sizeOf(this).width >= 1000;
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// True when the OS has "reduce motion" enabled.
  bool get systemReducesMotion => MediaQuery.disableAnimationsOf(this);

  void showSnack(String message, {IconData? icon, Color? accent}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accent ?? Colors.white),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

extension ColorX on Color {
  /// Blend towards white/black without going through HSL.
  Color lighten([double amount = 0.1]) =>
      Color.lerp(this, Colors.white, amount)!;

  Color darken([double amount = 0.1]) => Color.lerp(this, Colors.black, amount)!;

  /// Accent tint that stays readable on either theme's surface.
  Color onSurfaceSafe(bool isDark) =>
      isDark ? lighten(0.18) : darken(0.16);
}
