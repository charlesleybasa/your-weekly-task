import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_stats.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../routing/app_router.dart';
import '../../state/boards_controller.dart';
import '../../state/cards_controller.dart';
import '../../state/gamification_controller.dart';
import '../../state/sessions_controller.dart';
import '../../state/timer_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';
import '../calendar/week_strip.dart';
import '../tasks/quick_add_sheet.dart';
import '../tasks/task_card_tile.dart';
import '../tasks/task_editor_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = context.geometry.gutter;
    final boards = ref.watch(boardsProvider);

    if (boards.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            art: EmptyArt.boards,
            title: 'Welcome to Momentum',
            message:
                'Plan a week, focus on one thing at a time, and watch it add up.',
            actionLabel: 'Create your first board',
            onAction: () => context.go(Routes.boards),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, AppGeometry.md, gutter, 140),
              sliver: SliverList.list(
                children: const [
                  _GreetingHeader(),
                  SizedBox(height: AppGeometry.section),
                  _WeekSection(),
                  SizedBox(height: AppGeometry.section),
                  _TodayMission(),
                  SizedBox(height: AppGeometry.section),
                  _WeeklyProgressCard(),
                  SizedBox(height: AppGeometry.section),
                  _UpcomingSection(),
                  SizedBox(height: AppGeometry.section),
                  _RecentSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelProvider);
    final streak = ref.watch(streakProvider);

    return StaggerReveal(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_greeting, style: context.text.bodyMedium),
                    Text(
                      DateTime.now().fullDayName,
                      style: context.text.displaySmall,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: streak.live
                    ? '${streak.current} day streak · best ${streak.longest}'
                    : 'Complete a task today to restart your streak',
                child: StreakFlame(days: streak.current, live: streak.live),
              ),
            ],
          ),
          const SizedBox(height: AppGeometry.lg),
          Pressable(
            onTap: () => context.push(Routes.achievements),
            borderRadius: AppGeometry.brLg,
            semanticLabel: 'Level ${level.level} ${level.title}. View achievements.',
            hoverLift: 3,
            child: AppSurface(
              child: XpProgressBar(
                level: level.level,
                title: level.title,
                progress: level.progress,
                xpIntoLevel: Levels.xpIntoLevel(level.xp),
                xpForLevel: Levels.xpNeededForNextLevel(level.xp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSection extends ConsumerStatefulWidget {
  const _WeekSection();

  @override
  ConsumerState<_WeekSection> createState() => _WeekSectionState();
}

class _WeekSectionState extends ConsumerState<_WeekSection> {
  DateTime _selected = DateTime.now().dayStart;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StaggerReveal(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Week ${now.isoWeekNumber}',
            subtitle:
                '${now.weekStart.monthDay} – ${now.weekEnd.monthDay}',
            trailing: TextButton(
              onPressed: () => context.go(Routes.week),
              child: const Text('Open'),
            ),
          ),
          WeekStrip(
            weekStart: now.weekStart,
            selectedDay: _selected,
            onSelect: (day) {
              setState(() => _selected = day);
              context.go(Routes.week);
            },
          ),
        ],
      ),
    );
  }
}

class _TodayMission extends ConsumerWidget {
  const _TodayMission();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final summary = ref.watch(todaySummaryProvider);
    final timerRunning = ref.watch(hasRunningTimerProvider);
    final focused = ref.watch(todayFocusProvider);

    return StaggerReveal(
      index: 2,
      child: AppSurface(
        padding: const EdgeInsets.all(AppGeometry.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text("Today's mission", style: context.text.titleLarge),
              ],
            ),
            const SizedBox(height: AppGeometry.lg),
            Row(
              children: [
                Expanded(
                  child: _MissionStat(
                    value: summary.open,
                    label: summary.open == 1 ? 'Task left' : 'Tasks left',
                    color: colors.primary,
                  ),
                ),
                const _Divider(),
                Expanded(
                  child: _MissionStat(
                    value: summary.done,
                    label: 'Completed',
                    color: colors.success,
                  ),
                ),
                const _Divider(),
                Expanded(
                  child: _MissionStat(
                    value: timerRunning ? 1 : 0,
                    label: 'Running timer',
                    color: timerRunning ? colors.warning : colors.textTertiary,
                  ),
                ),
              ],
            ),
            if (focused > Duration.zero) ...[
              const SizedBox(height: AppGeometry.lg),
              Row(
                children: [
                  Icon(Icons.timelapse_rounded,
                      size: 15, color: colors.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    '${focused.compact} focused today',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppGeometry.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showQuickAddSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Quick add'),
                  ),
                ),
                const SizedBox(width: AppGeometry.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go(Routes.focus),
                    icon: Icon(
                      timerRunning
                          ? Icons.timer_outlined
                          : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(timerRunning ? 'Timer' : 'Focus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: context.colors.border,
      );
}

class _MissionStat extends StatelessWidget {
  const _MissionStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedCounter(
          value: value,
          style: AppTypography.stat(color, size: 26),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.text.labelSmall,
        ),
      ],
    );
  }
}

class _WeeklyProgressCard extends ConsumerWidget {
  const _WeeklyProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final report = ref.watch(currentWeekReportProvider);

    return StaggerReveal(
      index: 3,
      child: Pressable(
        onTap: () => context.push(Routes.statistics),
        borderRadius: AppGeometry.brLg,
        semanticLabel:
            'Weekly progress ${(report.completionRate * 100).round()} percent. '
            'View full statistics.',
        hoverLift: 3,
        child: AppSurface(
          padding: const EdgeInsets.all(AppGeometry.xl),
          child: Row(
            children: [
              ProgressRing(
                value: report.completionRate,
                size: 104,
                strokeWidth: 11,
                color: colors.primary,
                gradientEnd: colors.success,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedCounter(
                      value: (report.completionRate * 100).round(),
                      suffix: '%',
                      style: AppTypography.stat(colors.textPrimary, size: 24),
                    ),
                    Text('this week', style: context.text.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: AppGeometry.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Weekly progress', style: context.text.titleMedium),
                    const SizedBox(height: AppGeometry.md),
                    _MiniStat(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Completed',
                      value: '${report.completed}',
                      color: colors.success,
                    ),
                    _MiniStat(
                      icon: Icons.radio_button_unchecked_rounded,
                      label: 'Remaining',
                      value: '${report.remaining}',
                      color: colors.textSecondary,
                    ),
                    _MiniStat(
                      icon: Icons.auto_awesome_rounded,
                      label: 'XP earned',
                      value: '${report.xpEarned}',
                      color: colors.xp,
                    ),
                    _MiniStat(
                      icon: Icons.timelapse_rounded,
                      label: 'Focused',
                      value: report.focused.compact,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(label, style: context.text.bodySmall)),
          Text(
            value,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingCardsProvider);

    return StaggerReveal(
      index: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Up next',
            subtitle: 'Ranked by priority and what you already started',
          ),
          if (upcoming.isEmpty)
            const InlineEmpty(
              message: 'Nothing queued. Enjoy the free time.',
              icon: Icons.beach_access_outlined,
            )
          else
            for (var i = 0; i < upcoming.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppGeometry.sm),
                child: Consumer(
                  builder: (context, ref, _) {
                    final card = upcoming[i];
                    final board = ref.watch(boardProvider(card.boardId));
                    return TaskCardTile(
                      card: card,
                      board: board,
                      compact: true,
                      showBoardName: true,
                      onTap: () => showTaskEditorSheet(context, card.id),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyCompletedProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    return StaggerReveal(
      index: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recently completed'),
          for (final card in recent.items)
            Consumer(
              builder: (context, ref, _) {
                final board = ref.watch(boardProvider(card.boardId));
                final colors = context.colors;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppGeometry.sm),
                  child: Pressable(
                    onTap: () => showTaskEditorSheet(context, card.id),
                    borderRadius: AppGeometry.brMd,
                    sfx: null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: colors.success,
                        ),
                        const SizedBox(width: AppGeometry.md),
                        Expanded(
                          child: Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppGeometry.sm),
                        if (board != null)
                          AppChip(
                            label: board.title,
                            dense: true,
                            foreground: board.color,
                            background: board.color
                                .withValues(alpha: colors.isDark ? 0.18 : 0.12),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          card.completedAt?.relativeDayLabel ?? '',
                          style: context.text.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
