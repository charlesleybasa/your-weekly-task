import 'package:flutter/foundation.dart';

import 'enums.dart';

/// User preferences. Small, flat, and stored in SharedPreferences so the very
/// first frame can be themed without waiting on the database to open.
@immutable
class AppSettings {
  const AppSettings({
    this.themeChoice = ThemeChoice.system,
    this.defaultTimerMinutes = 25,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.animationsEnabled = true,
    this.tickingEnabled = false,
    this.notificationsEnabled = true,
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 9,
    this.dailyReminderMinute = 0,
    this.weeklyPlanningReminderEnabled = false,
    this.autoSuggestNext = true,
    this.hasCompletedOnboarding = false,
  });

  final ThemeChoice themeChoice;

  /// Pre-selected preset on the focus screen.
  final int defaultTimerMinutes;

  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Independent from the OS "reduce motion" flag — either one turns motion
  /// down, so a user can opt out in-app without changing a system setting.
  final bool animationsEnabled;

  /// Optional tick during the final countdown.
  final bool tickingEnabled;

  final bool notificationsEnabled;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;

  /// Monday-morning nudge to plan the week.
  final bool weeklyPlanningReminderEnabled;

  /// Offer the next task automatically when a timer finishes.
  final bool autoSuggestNext;

  final bool hasCompletedOnboarding;

  static const initial = AppSettings();

  AppSettings copyWith({
    ThemeChoice? themeChoice,
    int? defaultTimerMinutes,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? animationsEnabled,
    bool? tickingEnabled,
    bool? notificationsEnabled,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? weeklyPlanningReminderEnabled,
    bool? autoSuggestNext,
    bool? hasCompletedOnboarding,
  }) {
    return AppSettings(
      themeChoice: themeChoice ?? this.themeChoice,
      defaultTimerMinutes: defaultTimerMinutes ?? this.defaultTimerMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      tickingEnabled: tickingEnabled ?? this.tickingEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      weeklyPlanningReminderEnabled:
          weeklyPlanningReminderEnabled ?? this.weeklyPlanningReminderEnabled,
      autoSuggestNext: autoSuggestNext ?? this.autoSuggestNext,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeChoice': themeChoice.name,
        'defaultTimerMinutes': defaultTimerMinutes,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'animationsEnabled': animationsEnabled,
        'tickingEnabled': tickingEnabled,
        'notificationsEnabled': notificationsEnabled,
        'dailyReminderEnabled': dailyReminderEnabled,
        'dailyReminderHour': dailyReminderHour,
        'dailyReminderMinute': dailyReminderMinute,
        'weeklyPlanningReminderEnabled': weeklyPlanningReminderEnabled,
        'autoSuggestNext': autoSuggestNext,
        'hasCompletedOnboarding': hasCompletedOnboarding,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeChoice: ThemeChoice.fromName(json['themeChoice'] as String?),
        defaultTimerMinutes: json['defaultTimerMinutes'] as int? ?? 25,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        animationsEnabled: json['animationsEnabled'] as bool? ?? true,
        tickingEnabled: json['tickingEnabled'] as bool? ?? false,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
        dailyReminderHour: json['dailyReminderHour'] as int? ?? 9,
        dailyReminderMinute: json['dailyReminderMinute'] as int? ?? 0,
        weeklyPlanningReminderEnabled:
            json['weeklyPlanningReminderEnabled'] as bool? ?? false,
        autoSuggestNext: json['autoSuggestNext'] as bool? ?? true,
        hasCompletedOnboarding:
            json['hasCompletedOnboarding'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.themeChoice == themeChoice &&
          other.defaultTimerMinutes == defaultTimerMinutes &&
          other.soundEnabled == soundEnabled &&
          other.hapticsEnabled == hapticsEnabled &&
          other.animationsEnabled == animationsEnabled &&
          other.tickingEnabled == tickingEnabled &&
          other.notificationsEnabled == notificationsEnabled &&
          other.dailyReminderEnabled == dailyReminderEnabled &&
          other.dailyReminderHour == dailyReminderHour &&
          other.dailyReminderMinute == dailyReminderMinute &&
          other.weeklyPlanningReminderEnabled ==
              weeklyPlanningReminderEnabled &&
          other.autoSuggestNext == autoSuggestNext &&
          other.hasCompletedOnboarding == hasCompletedOnboarding;

  @override
  int get hashCode => Object.hash(
        themeChoice,
        defaultTimerMinutes,
        soundEnabled,
        hapticsEnabled,
        animationsEnabled,
        tickingEnabled,
        notificationsEnabled,
        dailyReminderEnabled,
        dailyReminderHour,
        dailyReminderMinute,
        weeklyPlanningReminderEnabled,
        autoSuggestNext,
        hasCompletedOnboarding,
      );
}
