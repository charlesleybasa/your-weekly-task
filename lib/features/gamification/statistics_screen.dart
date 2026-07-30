import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_geometry.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../state/boards_controller.dart';
import '../../state/gamification_controller.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _weekOffset = 0;

  DateTime get _weekStart =>
      DateTime.now().weekStart.add(Duration(days: 7 * _weekOffset));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gutter = context.geometry.gutter;
    final report = ref.watch(weeklyReportProvider(_weekStart.weekKey));
    final stats = ref.watch(statsProvider);
    final topBoard = report.topBoardId == null
        ? null
        : ref.watch(boardProvider(report.topBoardId!));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Statistics'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppGeometry.huge),
        children: [
          StaggerReveal(
            index: 0,
            child: _WeekSwitcher(
              weekStart: _weekStart,
              offset: _weekOffset,
              onChange: (delta) => setState(() {
                // Forward navigation stops at the current week — there are no
                // statistics for a week that has not happened.
                _weekOffset = math.min(0, _weekOffset + delta);
              }),
            ),
          ),
          const SizedBox(height: AppGeometry.section),

          StaggerReveal(
            index: 1,
            child: AppSurface(
              padding: const EdgeInsets.all(AppGeometry.xl),
              child: Row(
                children: [
                  ProgressRing(
                    value: report.completionRate,
                    size: 96,
                    strokeWidth: 10,
                    color: colors.primary,
                    gradientEnd: colors.success,
                    child: AnimatedCounter(
                      value: (report.completionRate * 100).round(),
                      suffix: '%',
                      style: AppTypography.stat(colors.textPrimary, size: 22),
                    ),
                  ),
                  const SizedBox(width: AppGeometry.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Completion', style: context.text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${report.completed} of ${report.planned} planned '
                          'tasks finished',
                          style: context.text.bodySmall,
                        ),
                        if (report.isPerfectWeek) ...[
                          const SizedBox(height: AppGeometry.md),
                          AppChip(
                            label: 'Perfect week',
                            icon: Icons.rocket_launch_rounded,
                            foreground: colors.success,
                            background: colors.successSoft,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppGeometry.section),

          StaggerReveal(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Tasks completed per day'),
                AppSurface(
                  padding: const EdgeInsets.fromLTRB(
                    AppGeometry.lg,
                    AppGeometry.xl,
                    AppGeometry.lg,
                    AppGeometry.md,
                  ),
                  child: _WeekBarChart(
                    values: report.perDayCompleted,
                    weekStart: _weekStart,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.section),

          StaggerReveal(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'This week'),
                _StatGrid(
                  tiles: [
                    _StatTile(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Cards completed',
                      value: '${report.completed}',
                      color: colors.success,
                    ),
                    _StatTile(
                      icon: Icons.timelapse_rounded,
                      label: 'Hours focused',
                      value: report.focused.hoursDecimal.toStringAsFixed(1),
                      color: colors.primary,
                    ),
                    _StatTile(
                      icon: Icons.av_timer_rounded,
                      label: 'Average session',
                      value: report.sessionCount == 0
                          ? '—'
                          : report.averageSession.compact,
                      color: colors.primary,
                    ),
                    _StatTile(
                      icon: Icons.auto_awesome_rounded,
                      label: 'XP earned',
                      value: '${report.xpEarned}',
                      color: colors.xp,
                    ),
                    _StatTile(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Current streak',
                      value: '${stats.displayStreak}d',
                      color: colors.streak,
                    ),
                    _StatTile(
                      icon: Icons.emoji_events_outlined,
                      label: 'Longest streak',
                      value: '${stats.longestStreak}d',
                      color: colors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.section),

          StaggerReveal(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Highlights'),
                AppSurface(
                  child: Column(
                    children: [
                      _HighlightRow(
                        icon: Icons.dashboard_customize_outlined,
                        label: 'Most productive board',
                        value: topBoard?.title ?? 'No data yet',
                        detail: report.topBoardCount > 0
                            ? '${report.topBoardCount} tasks'
                            : null,
                        color: topBoard?.color ?? colors.textTertiary,
                      ),
                      Divider(color: colors.border, height: AppGeometry.xxl),
                      _HighlightRow(
                        icon: Icons.event_available_outlined,
                        label: 'Most productive day',
                        value: report.bestDay?.fullDayName ?? 'No data yet',
                        detail: report.bestDay == null
                            ? null
                            : '${report.perDayCompleted[report.bestDay!.weekday - 1]} tasks',
                        color: colors.primary,
                      ),
                      Divider(color: colors.border, height: AppGeometry.xxl),
                      _HighlightRow(
                        icon: Icons.military_tech_outlined,
                        label: 'Lifetime',
                        value: '${stats.tasksCompleted} tasks · '
                            'level ${stats.level}',
                        detail: '${stats.totalXp} XP total',
                        color: colors.xp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.weekStart,
    required this.offset,
    required this.onChange,
  });

  final DateTime weekStart;
  final int offset;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous week',
          onPressed: () => onChange(-1),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Week ${weekStart.isoWeekNumber}',
                style: context.text.titleLarge,
              ),
              Text(
                offset == 0
                    ? 'This week'
                    : '${weekStart.monthDay} – ${weekStart.weekEnd.monthDay}',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        AppIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next week',
          enabled: offset < 0,
          onPressed: () => onChange(1),
        ),
      ],
    );
  }
}

/// Seven bars that grow into view. Values are labelled directly so the chart
/// does not rely on bar height alone to convey the number.
class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({required this.values, required this.weekStart});

  final List<int> values;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = weekStart.weekDays;
    final max = values.fold<int>(1, (m, v) => v > m ? v : m);

    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${values[i]}',
                      style: context.text.labelSmall?.copyWith(
                        color: values[i] == 0
                            ? colors.textTertiary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: values[i] / max),
                        duration: context.motion.slower,
                        curve: context.motion.decelerate,
                        builder: (context, t, _) => FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: values[i] == 0 ? 0.04 : t.clamp(0.06, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: values[i] == 0
                                    ? [colors.border, colors.border]
                                    : [
                                        colors.primary,
                                        colors.primary.lighten(0.16),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i].shortDayName.substring(0, 1),
                      style: context.text.labelSmall?.copyWith(
                        color: days[i].isToday
                            ? colors.primaryText
                            : colors.textTertiary,
                        fontWeight:
                            days[i].isToday ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final columns = context.screenSize.width >= 700 ? 3 : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppGeometry.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppGeometry.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppGeometry.md),
          Text(
            value,
            style: AppTypography.stat(context.colors.textPrimary, size: 23),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelSmall),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: context.colors.isDark ? 0.18 : 0.12),
            borderRadius: AppGeometry.brSm,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: AppGeometry.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: context.text.labelSmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: context.text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (detail != null)
          Text(detail!, style: context.text.labelSmall),
      ],
    );
  }
}
