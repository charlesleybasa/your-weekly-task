import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Every animated widget in the app reads its duration and curve from here so
/// that a single "reduce motion" switch can collapse the whole system to fast
/// cross-fades without touching call sites.
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    required this.enabled,
    required this.instant,
    required this.fast,
    required this.base,
    required this.slow,
    required this.slower,
    required this.celebration,
    required this.standard,
    required this.emphasized,
    required this.decelerate,
    required this.overshoot,
    required this.staggerStep,
  });

  /// When false, animations are collapsed to a near-instant fade.
  final bool enabled;

  final Duration instant;
  final Duration fast;
  final Duration base;
  final Duration slow;
  final Duration slower;
  final Duration celebration;

  /// General purpose in/out easing.
  final Curve standard;

  /// Material 3 "emphasized decelerate" — the default for anything entering.
  final Curve emphasized;

  final Curve decelerate;

  /// Slight overshoot for pops and drops. Falls back to [decelerate] when
  /// motion is reduced.
  final Curve overshoot;

  /// Delay between consecutive items in a staggered list reveal.
  final Duration staggerStep;

  /// Full motion, tuned for a 120 Hz-capable device but safe at 60.
  static const full = AppMotion(
    enabled: true,
    instant: Duration(milliseconds: 90),
    fast: Duration(milliseconds: 160),
    base: Duration(milliseconds: 240),
    slow: Duration(milliseconds: 360),
    slower: Duration(milliseconds: 520),
    celebration: Duration(milliseconds: 1400),
    standard: Curves.easeInOutCubic,
    emphasized: Cubic(0.2, 0.0, 0.0, 1.0),
    decelerate: Curves.easeOutCubic,
    overshoot: Cubic(0.34, 1.4, 0.42, 1.0),
    staggerStep: Duration(milliseconds: 40),
  );

  /// Honours `MediaQuery.disableAnimations` / the in-app animation toggle.
  /// Durations stay non-zero but short — an instant swap reads as a glitch,
  /// while a 70 ms fade still reads as a transition.
  static const reduced = AppMotion(
    enabled: false,
    instant: Duration(milliseconds: 1),
    fast: Duration(milliseconds: 70),
    base: Duration(milliseconds: 70),
    slow: Duration(milliseconds: 90),
    slower: Duration(milliseconds: 90),
    celebration: Duration(milliseconds: 200),
    standard: Curves.linear,
    emphasized: Curves.linear,
    decelerate: Curves.linear,
    overshoot: Curves.linear,
    staggerStep: Duration.zero,
  );

  /// Spring used by drag-release and card-drop animations.
  SpringDescription get dropSpring => enabled
      ? const SpringDescription(mass: 1, stiffness: 520, damping: 26)
      : const SpringDescription(mass: 1, stiffness: 2000, damping: 90);

  /// Scale a widget should reach while pressed. 1.0 when motion is reduced so
  /// pressing never shifts layout for users who asked for less movement.
  double get pressScale => enabled ? 0.96 : 1.0;

  /// Hover lift for pointer devices.
  double get hoverScale => enabled ? 1.03 : 1.0;
  double get hoverLift => enabled ? 6.0 : 0.0;

  /// Rotation (radians) applied to a card while it is being dragged.
  double get dragTilt => enabled ? 0.045 : 0.0;
  double get dragScale => enabled ? 1.05 : 1.0;

  /// Delay for the [index]-th item of a staggered reveal, capped so long lists
  /// do not make the last item wait seconds to appear.
  Duration stagger(int index, {int cap = 12}) =>
      staggerStep * (index > cap ? cap : index);

  @override
  AppMotion copyWith({
    bool? enabled,
    Duration? instant,
    Duration? fast,
    Duration? base,
    Duration? slow,
    Duration? slower,
    Duration? celebration,
    Curve? standard,
    Curve? emphasized,
    Curve? decelerate,
    Curve? overshoot,
    Duration? staggerStep,
  }) {
    return AppMotion(
      enabled: enabled ?? this.enabled,
      instant: instant ?? this.instant,
      fast: fast ?? this.fast,
      base: base ?? this.base,
      slow: slow ?? this.slow,
      slower: slower ?? this.slower,
      celebration: celebration ?? this.celebration,
      standard: standard ?? this.standard,
      emphasized: emphasized ?? this.emphasized,
      decelerate: decelerate ?? this.decelerate,
      overshoot: overshoot ?? this.overshoot,
      staggerStep: staggerStep ?? this.staggerStep,
    );
  }

  /// Motion tokens are switched, not interpolated — lerping between the full
  /// and reduced sets would produce durations that belong to neither.
  @override
  AppMotion lerp(covariant AppMotion? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
