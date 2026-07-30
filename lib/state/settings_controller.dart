import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_settings.dart';
import '../core/models/enums.dart';
import 'app_providers.dart';

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final settings = ref.read(settingsRepositoryProvider).load();
    _applyToServices(settings);
    return settings;
  }

  void _applyToServices(AppSettings settings) {
    ref.read(soundServiceProvider).enabled = settings.soundEnabled;
    ref.read(hapticServiceProvider).enabled = settings.hapticsEnabled;
  }

  Future<void> _commit(AppSettings next) async {
    if (next == state) return;
    state = next;
    _applyToServices(next);
    await ref.read(settingsRepositoryProvider).save(next);
  }

  Future<void> setTheme(ThemeChoice choice) =>
      _commit(state.copyWith(themeChoice: choice));

  Future<void> setDefaultTimer(int minutes) =>
      _commit(state.copyWith(defaultTimerMinutes: minutes.clamp(1, 240)));

  Future<void> setSound(bool enabled) =>
      _commit(state.copyWith(soundEnabled: enabled));

  Future<void> setHaptics(bool enabled) =>
      _commit(state.copyWith(hapticsEnabled: enabled));

  Future<void> setAnimations(bool enabled) =>
      _commit(state.copyWith(animationsEnabled: enabled));

  Future<void> setTicking(bool enabled) =>
      _commit(state.copyWith(tickingEnabled: enabled));

  Future<void> setAutoSuggestNext(bool enabled) =>
      _commit(state.copyWith(autoSuggestNext: enabled));

  Future<void> completeOnboarding() =>
      _commit(state.copyWith(hasCompletedOnboarding: true));

  /// Notification toggles request OS permission before they can turn on, so a
  /// switch never claims a capability the app does not actually have.
  Future<bool> setNotifications(bool enabled) async {
    if (!enabled) {
      await ref.read(notificationServiceProvider).cancelAll();
      await _commit(
        state.copyWith(
          notificationsEnabled: false,
          dailyReminderEnabled: false,
          weeklyPlanningReminderEnabled: false,
        ),
      );
      return false;
    }

    final granted = await ref.read(notificationServiceProvider).requestPermission();
    await _commit(state.copyWith(notificationsEnabled: granted));
    return granted;
  }

  Future<bool> setDailyReminder(bool enabled, {TimeOfDay? at}) async {
    if (enabled && !state.notificationsEnabled) {
      final granted = await setNotifications(true);
      if (!granted) return false;
    }
    final hour = at?.hour ?? state.dailyReminderHour;
    final minute = at?.minute ?? state.dailyReminderMinute;

    await ref.read(notificationServiceProvider).setDailyReminder(
          enabled: enabled,
          hour: hour,
          minute: minute,
        );
    await _commit(
      state.copyWith(
        dailyReminderEnabled: enabled,
        dailyReminderHour: hour,
        dailyReminderMinute: minute,
      ),
    );
    return enabled;
  }

  Future<bool> setWeeklyPlanningReminder(bool enabled) async {
    if (enabled && !state.notificationsEnabled) {
      final granted = await setNotifications(true);
      if (!granted) return false;
    }
    await ref
        .read(notificationServiceProvider)
        .setWeeklyPlanningReminder(enabled: enabled);
    await _commit(state.copyWith(weeklyPlanningReminderEnabled: enabled));
    return enabled;
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
