import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic intensity tiers, mapped to the moments that earn them.
enum HapticLevel {
  /// Button taps, chip selection, toggles.
  light,

  /// Drag start, card moved between columns, sheet snap.
  medium,

  /// Timer finished, level up, achievement unlocked.
  heavy,

  /// Discrete step feedback — slider notches, preset scrubbing.
  selection,
}

/// Thin wrapper over [HapticFeedback] that respects the user's setting and
/// silently no-ops on platforms without a vibrator.
class HapticService {
  HapticService();

  bool enabled = true;

  /// Desktop and web have no haptics; calling into the channel there is a
  /// wasted platform round-trip on every tap.
  static final bool _supported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void fire(HapticLevel level) {
    if (!enabled || !_supported) return;
    switch (level) {
      case HapticLevel.light:
        HapticFeedback.lightImpact();
      case HapticLevel.medium:
        HapticFeedback.mediumImpact();
      case HapticLevel.heavy:
        HapticFeedback.heavyImpact();
      case HapticLevel.selection:
        HapticFeedback.selectionClick();
    }
  }

  void light() => fire(HapticLevel.light);
  void medium() => fire(HapticLevel.medium);
  void heavy() => fire(HapticLevel.heavy);
  void selection() => fire(HapticLevel.selection);

  /// Celebration pattern for level-ups: two beats, not a long buzz.
  Future<void> celebrate() async {
    if (!enabled || !_supported) return;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    HapticFeedback.mediumImpact();
  }
}
