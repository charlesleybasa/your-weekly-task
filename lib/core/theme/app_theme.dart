import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_geometry.dart';
import 'app_motion.dart';
import 'app_palette.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light({bool reduceMotion = false}) =>
      _build(AppColors.light, reduceMotion);

  static ThemeData dark({bool reduceMotion = false}) =>
      _build(AppColors.dark, reduceMotion);

  static ThemeData _build(AppColors c, bool reduceMotion) {
    final text = AppTypography.build(c.textPrimary, c.textSecondary);
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primaryText,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surfaceSunken,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      // Page transitions: fade + subtle scale, never an abrupt replace.
      //
      // The same builder on every platform is deliberate — the app has one
      // motion language, and an iOS-style horizontal slide here would fight
      // the fade-and-rise used by the shell and the sheets.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionBuilder(),
          TargetPlatform.macOS: _FadeThroughTransitionBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[
        c,
        reduceMotion ? AppMotion.reduced : AppMotion.full,
        AppGeometry.phone,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle: c.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brLg),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: AppGeometry.iconMd),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brMd),
        minVerticalPadding: 12,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        modalBarrierColor: c.scrim,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brSheet),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brXl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.isDark ? c.surfaceRaised : const Color(0xFF1B2030),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brMd),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        hintStyle: text.bodyMedium?.copyWith(color: c.textTertiary),
        labelStyle: text.labelMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.primaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: AppGeometry.brMd,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppGeometry.brMd,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppGeometry.brMd,
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppGeometry.brMd,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppGeometry.brMd,
          borderSide: BorderSide(color: c.danger, width: 1.6),
        ),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.textTertiary,
          minimumSize: const Size(0, AppGeometry.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: text.labelLarge,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primaryText,
          minimumSize: const Size(0, AppGeometry.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brMd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.borderStrong),
          minimumSize: const Size(0, AppGeometry.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brMd),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppGeometry.brMd),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSunken,
        side: BorderSide(color: c.border),
        labelStyle: text.labelSmall!,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: AppGeometry.brPill),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : c.borderStrong,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceSunken,
        thumbColor: c.primary,
        overlayColor: c.primarySoft,
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceSunken,
        circularTrackColor: c.surfaceSunken,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceRaised : const Color(0xFF1B2030),
          borderRadius: AppGeometry.brSm,
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.brMd,
          side: BorderSide(color: c.border),
        ),
        textStyle: text.bodyMedium?.copyWith(color: c.textPrimary),
      ),
    );
  }
}

/// Fade + gentle scale. Replaces the default platform slide so every route
/// change in the app shares one motion language.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final motion = Theme.of(context).extension<AppMotion>() ?? AppMotion.full;
    final curved = CurvedAnimation(
      parent: animation,
      curve: motion.emphasized,
      reverseCurve: Curves.easeIn,
    );

    if (!motion.enabled) {
      return FadeTransition(opacity: curved, child: child);
    }

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.014),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
