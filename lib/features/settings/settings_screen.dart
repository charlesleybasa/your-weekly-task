import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/focus_session.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../routing/app_router.dart';
import '../../state/app_providers.dart';
import '../../state/gamification_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final gutter = context.geometry.gutter;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final level = ref.watch(levelProvider);
    final stats = ref.watch(statsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppGeometry.md, gutter, 140),
          children: [
            StaggerReveal(
              index: 0,
              child: Text('Settings', style: context.text.displaySmall),
            ),
            const SizedBox(height: AppGeometry.section),

            StaggerReveal(
              index: 1,
              child: Pressable(
                onTap: () => context.push(Routes.achievements),
                borderRadius: AppGeometry.brLg,
                hoverLift: 3,
                semanticLabel: 'View progress and achievements',
                child: AppSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: XpProgressBar(
                          level: level.level,
                          title: level.title,
                          progress: level.progress,
                          xpIntoLevel: stats.xpIntoLevel,
                          xpForLevel: stats.xpForThisLevel,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: AppGeometry.md),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppGeometry.section),

            // ---- Appearance ----
            StaggerReveal(
              index: 2,
              child: _Group(
                title: 'Appearance',
                children: [
                  _SettingRow(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'Light, dark, or follow the system',
                    trailing: SegmentedButton<ThemeChoice>(
                      segments: [
                        for (final choice in ThemeChoice.values)
                          ButtonSegment(
                            value: choice,
                            label: Text(choice.label),
                          ),
                      ],
                      selected: {settings.themeChoice},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => controller.setTheme(s.first),
                    ),
                    stacked: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.section),

            // ---- Focus ----
            StaggerReveal(
              index: 3,
              child: _Group(
                title: 'Focus',
                children: [
                  _SettingRow(
                    icon: Icons.timer_outlined,
                    title: 'Default timer',
                    subtitle: 'Pre-selected when you start a session',
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        for (final minutes in TimerPresets.minutes)
                          _MiniChoice(
                            label: '$minutes',
                            selected: settings.defaultTimerMinutes == minutes,
                            onTap: () => controller.setDefaultTimer(minutes),
                          ),
                      ],
                    ),
                    stacked: true,
                  ),
                  _SwitchRow(
                    icon: Icons.skip_next_outlined,
                    title: 'Suggest the next task',
                    subtitle: 'Offer another task when a timer finishes',
                    value: settings.autoSuggestNext,
                    onChanged: controller.setAutoSuggestNext,
                  ),
                  _SwitchRow(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Tick in the last 10 seconds',
                    subtitle: 'A quiet pulse as the countdown closes',
                    value: settings.tickingEnabled,
                    onChanged: controller.setTicking,
                    enabled: settings.soundEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.section),

            // ---- Feedback ----
            StaggerReveal(
              index: 4,
              child: _Group(
                title: 'Feedback',
                subtitle:
                    'Sound, motion and haptics are independent — turn off '
                    'whichever you like.',
                children: [
                  _SwitchRow(
                    icon: Icons.volume_up_outlined,
                    title: 'Sound effects',
                    subtitle: 'Soft cues for taps, drops and completions',
                    value: settings.soundEnabled,
                    onChanged: (value) {
                      controller.setSound(value);
                      if (value) {
                        ref.read(soundServiceProvider).play(Sfx.taskCompleted);
                      }
                    },
                  ),
                  _SwitchRow(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic feedback',
                    subtitle: 'Subtle taps on supported devices',
                    value: settings.hapticsEnabled,
                    onChanged: (value) {
                      controller.setHaptics(value);
                      if (value) ref.read(hapticServiceProvider).medium();
                    },
                  ),
                  _SwitchRow(
                    icon: Icons.animation_rounded,
                    title: 'Animations',
                    subtitle: context.systemReducesMotion
                        ? 'Your system already requests reduced motion'
                        : 'Transitions, particles and parallax',
                    value: settings.animationsEnabled &&
                        !context.systemReducesMotion,
                    enabled: !context.systemReducesMotion,
                    onChanged: controller.setAnimations,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.section),

            // ---- Notifications ----
            StaggerReveal(
              index: 5,
              child: _Group(
                title: 'Notifications',
                children: [
                  _SwitchRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Allow notifications',
                    subtitle: 'Local only — nothing leaves your device',
                    value: settings.notificationsEnabled,
                    onChanged: (value) async {
                      final granted = await controller.setNotifications(value);
                      if (value && !granted && context.mounted) {
                        context.showSnack(
                          'Notification permission was declined',
                          icon: Icons.info_outline_rounded,
                        );
                      }
                    },
                  ),
                  _SwitchRow(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Daily reminder',
                    subtitle: 'A nudge to pick today\'s first task',
                    value: settings.dailyReminderEnabled,
                    enabled: settings.notificationsEnabled,
                    onChanged: (value) => controller.setDailyReminder(value),
                  ),
                  _SwitchRow(
                    icon: Icons.event_note_outlined,
                    title: 'Weekly planning reminder',
                    subtitle: 'Once a week, to lay out the days ahead',
                    value: settings.weeklyPlanningReminderEnabled,
                    enabled: settings.notificationsEnabled,
                    onChanged: controller.setWeeklyPlanningReminder,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.section),

            // ---- Data ----
            StaggerReveal(
              index: 6,
              child: _Group(
                title: 'Data',
                subtitle: 'Everything is stored on this device. No account, '
                    'no sync, no upload.',
                children: [
                  _SettingRow(
                    icon: Icons.insights_outlined,
                    title: 'Statistics',
                    subtitle: 'Weekly breakdown and highlights',
                    onTap: () => context.push(Routes.statistics),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textTertiary,
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.ios_share_rounded,
                    title: 'Export data',
                    subtitle: 'Coming in a future update',
                    enabled: false,
                  ),
                  _SettingRow(
                    icon: Icons.download_outlined,
                    title: 'Import data',
                    subtitle: 'Coming in a future update',
                    enabled: false,
                  ),
                  _SettingRow(
                    icon: Icons.restart_alt_rounded,
                    title: 'Reset statistics',
                    subtitle: 'Clears XP, level, streaks and session history. '
                        'Boards and tasks are kept.',
                    danger: true,
                    onTap: () async {
                      final confirmed = await confirmAction(
                        context: context,
                        title: 'Reset statistics?',
                        message:
                            'Your XP, level, streaks, achievements and focus '
                            'history will be erased. Boards and tasks stay '
                            'exactly as they are.',
                        confirmLabel: 'Reset',
                        destructive: true,
                      );
                      if (!confirmed) return;
                      await ref
                          .read(statsProvider.notifier)
                          .resetStatistics();
                      if (context.mounted) {
                        context.showSnack(
                          'Statistics reset',
                          icon: Icons.check_circle_outline_rounded,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.section),

            Center(
              child: Column(
                children: [
                  Text(
                    'Momentum',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  Text(
                    'Version 1.0.0 · offline first',
                    style: context.text.labelSmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppGeometry.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  letterSpacing: 0.9,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: context.text.bodySmall),
              ],
            ],
          ),
        ),
        AppSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    color: colors.border,
                    height: 1,
                    indent: AppGeometry.huge + 4,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.danger = false,
    this.stacked = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool danger;

  /// Puts [trailing] on its own line — for controls too wide to sit inline.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = danger
        ? colors.danger
        : enabled
            ? colors.textSecondary
            : colors.textTertiary.withValues(alpha: 0.6);

    final body = Padding(
      padding: const EdgeInsets.all(AppGeometry.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(width: AppGeometry.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.text.titleMedium?.copyWith(
                        color: danger
                            ? colors.danger
                            : enabled
                                ? colors.textPrimary
                                : colors.textTertiary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null && !stacked) ...[
                const SizedBox(width: AppGeometry.md),
                trailing!,
              ],
            ],
          ),
          if (trailing != null && stacked) ...[
            const SizedBox(height: AppGeometry.lg),
            SizedBox(width: double.infinity, child: trailing!),
          ],
        ],
      ),
    );

    if (onTap == null || !enabled) {
      return Semantics(enabled: enabled, child: body);
    }

    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brMd,
      semanticLabel: '$title. ${subtitle ?? ''}',
      child: body,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      onTap: enabled ? () => onChanged(!value) : null,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _MiniChoice extends StatelessWidget {
  const _MiniChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brSm,
      minSize: 44,
      semanticLabel: '$label minute default timer',
      child: AnimatedContainer(
        duration: context.motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceSunken,
          borderRadius: AppGeometry.brSm,
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: selected ? colors.onPrimary : colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
