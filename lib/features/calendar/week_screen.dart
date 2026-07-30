import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/task_card.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../routing/app_router.dart';
import '../../state/boards_controller.dart';
import '../../state/cards_controller.dart';
import '../../state/gamification_controller.dart';
import '../../state/timer_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';
import '../tasks/quick_add_sheet.dart';
import '../tasks/task_card_tile.dart';
import '../tasks/task_editor_sheet.dart';
import 'week_strip.dart';

/// Weekly planner. Swipe horizontally to change week; tap a day to filter.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  /// Weeks are addressed by offset from the current one, with a large initial
  /// page so the user can page backwards as far as they like.
  static const _initialPage = 5000;

  late final PageController _pages = PageController(initialPage: _initialPage);
  int _weekOffset = 0;
  DateTime _selected = DateTime.now().dayStart;

  DateTime get _weekStart =>
      DateTime.now().weekStart.add(Duration(days: 7 * _weekOffset));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final offset = page - _initialPage;
    setState(() {
      _weekOffset = offset;
      // Landing on a new week selects today if it is in view, otherwise Monday
      // — never a day from the week you just left.
      final start = DateTime.now().weekStart.add(Duration(days: 7 * offset));
      final today = DateTime.now().dayStart;
      _selected = offset == 0 ? today : start;
    });
  }

  void _jumpToToday() {
    _pages.animateToPage(
      _initialPage,
      duration: context.motion.slow,
      curve: context.motion.emphasized,
    );
    setState(() => _selected = DateTime.now().dayStart);
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.geometry.gutter;
    final start = _weekStart;
    final report = ref.watch(weeklyReportProvider(start.weekKey));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppGeometry.md, gutter, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Week ${start.isoWeekNumber}',
                          style: context.text.displaySmall,
                        ),
                        Text(
                          '${start.monthDay} – ${start.weekEnd.monthDay}'
                          '${_weekOffset == 0 ? ' · this week' : ''}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (_weekOffset != 0)
                    TextButton.icon(
                      onPressed: _jumpToToday,
                      icon: const Icon(Icons.today_rounded, size: 18),
                      label: const Text('Today'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Row(
                children: [
                  Expanded(
                    child: AppProgressBar(
                      value: report.completionRate,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: AppGeometry.md),
                  Text(
                    '${report.completed}/${report.planned}',
                    style: context.text.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppGeometry.lg),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, page) {
                  final weekStart = DateTime.now()
                      .weekStart
                      .add(Duration(days: 7 * (page - _initialPage)));
                  return _WeekPage(
                    weekStart: weekStart,
                    selected: _selected,
                    onSelectDay: (day) => setState(() => _selected = day),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekPage extends ConsumerWidget {
  const _WeekPage({
    required this.weekStart,
    required this.selected,
    required this.onSelectDay,
  });

  final DateTime weekStart;
  final DateTime selected;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = context.geometry.gutter;
    final cards = ref.watch(dayCardsProvider(selected.dayKey));

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: WeekStrip(
            weekStart: weekStart,
            selectedDay: selected,
            onSelect: onSelectDay,
          ),
        ),
        const SizedBox(height: AppGeometry.lg),
        Expanded(
          child: cards.isEmpty
              ? EmptyState(
                  art: EmptyArt.tasks,
                  compact: true,
                  title: selected.isToday
                      ? 'Nothing scheduled today'
                      : 'Nothing on ${selected.fullDayName}',
                  message: 'Enjoy the free time — or plan something in.',
                  actionLabel: 'Add a task',
                  onAction: () => showQuickAddSheet(context, day: selected),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 140),
                  itemCount: cards.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppGeometry.md),
                        child: SectionHeader(
                          title: selected.relativeDayLabel,
                          subtitle: '${cards.length} task'
                              '${cards.length == 1 ? '' : 's'} scheduled',
                          padding: EdgeInsets.zero,
                          trailing: AppIconButton(
                            icon: Icons.add_rounded,
                            tooltip: 'Add task to ${selected.fullDayName}',
                            onPressed: () =>
                                showQuickAddSheet(context, day: selected),
                            color: context.colors.primaryText,
                            background: context.colors.primarySoft,
                          ),
                        ),
                      );
                    }

                    final card = cards[i - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppGeometry.sm),
                      child: StaggerReveal(
                        index: i,
                        child: _SwipeableTask(card: card),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A day-list row with swipe actions.
///
/// Swipe lives here rather than on the kanban board: a column already owns the
/// drag gesture, and stacking a horizontal swipe on top of it would make both
/// unreliable.
class _SwipeableTask extends ConsumerWidget {
  const _SwipeableTask({required this.card});

  final TaskCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final board = ref.watch(boardProvider(card.boardId));

    return Dismissible(
      key: ValueKey('swipe-${card.id}'),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: colors.success,
        icon: card.isDone ? Icons.undo_rounded : Icons.check_rounded,
        label: card.isDone ? 'Reopen' : 'Complete',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: colors.danger,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (card.isDone) {
            await ref.read(cardsProvider.notifier).reopen(card.id);
          } else {
            await ref.read(statsProvider.notifier).completeTask(card.id);
          }
          // Never actually dismiss: the row stays, restyled to its new state.
          return false;
        }

        return confirmAction(
          context: context,
          title: 'Delete task?',
          message: '"${card.title}" will be removed.',
          confirmLabel: 'Delete',
          destructive: true,
        );
      },
      onDismissed: (_) => ref.read(cardsProvider.notifier).delete(card.id),
      child: TaskCardTile(
        card: card,
        board: board,
        showBoardName: true,
        onTap: () => showTaskEditorSheet(context, card.id),
        onToggleDone: () async {
          if (card.isDone) {
            await ref.read(cardsProvider.notifier).reopen(card.id);
          } else {
            await ref.read(statsProvider.notifier).completeTask(card.id);
          }
        },
        onStartTimer: card.isDone
            ? null
            : () async {
                final timer = ref.read(timerProvider);
                if (timer.isActive && timer.taskId != card.id) {
                  final replace = await confirmAction(
                    context: context,
                    title: 'A timer is already running',
                    message: 'Stop it and focus on "${card.title}" instead?',
                    confirmLabel: 'Switch',
                  );
                  if (!replace || !context.mounted) return;
                  await ref.read(timerProvider.notifier).stop(completed: false);
                }
                await ref
                    .read(timerProvider.notifier)
                    .start(card, minutes: card.estimatedMinutes);
                if (context.mounted) context.go(Routes.focus);
              },
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppGeometry.brLg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
