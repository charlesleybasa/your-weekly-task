import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/task_card.dart';
import '../../core/services/xp_service.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../routing/app_router.dart';
import '../../state/boards_controller.dart';
import '../../state/cards_controller.dart';
import '../../state/gamification_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/timer_controller.dart';
import '../../widgets/particles.dart';
import '../../widgets/surfaces.dart';
import '../tasks/task_card_tile.dart';

/// The end-of-session flow: celebrate, offer to complete the task, then offer
/// the next one.
///
/// Non-dismissible by tap-away — this is the one moment where a decision
/// ("done or not?") genuinely needs an answer, and losing it to a stray tap
/// would silently drop the XP.
Future<void> showTimerCompleteSheet(
  BuildContext context, {
  required String taskId,
  required bool perfectFocus,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.scrim,
    builder: (_) => _TimerCompleteSheet(
      taskId: taskId,
      perfectFocus: perfectFocus,
    ),
  );
}

class _TimerCompleteSheet extends ConsumerStatefulWidget {
  const _TimerCompleteSheet({
    required this.taskId,
    required this.perfectFocus,
  });

  final String taskId;
  final bool perfectFocus;

  @override
  ConsumerState<_TimerCompleteSheet> createState() =>
      _TimerCompleteSheetState();
}

class _TimerCompleteSheetState extends ConsumerState<_TimerCompleteSheet> {
  /// null → still asking; true → task marked done; false → left open.
  bool? _decision;

  bool _busy = false;

  Future<void> _markDone() async {
    setState(() => _busy = true);
    await ref.read(statsProvider.notifier).completeTask(
          widget.taskId,
          viaTimer: true,
          perfectFocus: widget.perfectFocus,
        );
    if (mounted) setState(() => _decision = true);
  }

  Future<void> _keepOpen() async {
    // Even without completing, a finished timer is worth checking achievements
    // for — Deep Work is about hours focused, not tasks closed.
    await ref
        .read(statsProvider.notifier)
        .checkAchievements(perfectFocus: widget.perfectFocus);
    if (mounted) setState(() => _decision = false);
  }

  Future<void> _startNext(TaskCard next) async {
    Navigator.of(context).pop();
    await ref
        .read(timerProvider.notifier)
        .start(next, minutes: next.estimatedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = ref.watch(cardProvider(widget.taskId));
    final autoSuggest = ref.watch(settingsProvider).autoSuggestNext;

    final projected = card == null
        ? XpBreakdown.zero
        : XpService.forCompletion(
            card,
            viaTimer: true,
            perfectFocus: widget.perfectFocus,
            isFirstToday:
                ref.watch(statsProvider).lastCompletionDayKey != DateTime.now().dayKey,
            streakDays: ref.watch(statsProvider).currentStreak + 1,
          );

    return Stack(
      children: [
        if (_decision == null)
          const Positioned.fill(
            child: IgnorePointer(
              child: ParticleBurst(
                count: 52,
                origin: Alignment(0, 0.45),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxWidth: AppGeometry.contentMaxWidth,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppGeometry.brSheet,
              border: Border.all(color: colors.border),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppGeometry.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 34,
                        color: colors.success,
                      ),
                    ),
                    const SizedBox(height: AppGeometry.lg),
                    Text(
                      'Mission complete',
                      style: context.text.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card?.title ?? 'Session finished',
                      style: context.text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),

                    if (widget.perfectFocus) ...[
                      const SizedBox(height: AppGeometry.md),
                      AppChip(
                        label: 'Perfect focus — never paused',
                        icon: Icons.track_changes_rounded,
                        foreground: colors.success,
                        background: colors.successSoft,
                      ),
                    ],

                    const SizedBox(height: AppGeometry.xl),

                    if (_decision == null) ...[
                      _XpBreakdownPanel(breakdown: projected),
                      const SizedBox(height: AppGeometry.xl),
                      Text(
                        'Move this task to Done?',
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(height: AppGeometry.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _keepOpen,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                              ),
                              child: const Text('Later'),
                            ),
                          ),
                          const SizedBox(width: AppGeometry.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _markDone,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                backgroundColor: colors.success,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Yes, done'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      _NextUpPanel(
                        completedTaskId: widget.taskId,
                        autoSuggest: autoSuggest,
                        onStart: _startNext,
                        onDismiss: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _XpBreakdownPanel extends StatelessWidget {
  const _XpBreakdownPanel({required this.breakdown});

  final XpBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (breakdown.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppGeometry.lg),
      decoration: BoxDecoration(
        color: colors.xp.withValues(alpha: colors.isDark ? 0.1 : 0.14),
        borderRadius: AppGeometry.brLg,
        border: Border.all(color: colors.xp.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          for (final line in breakdown.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(line.label, style: context.text.bodySmall),
                  ),
                  Text(
                    '+${line.amount}',
                    style: context.text.labelMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: colors.xp.withValues(alpha: 0.3), height: AppGeometry.lg),
          Row(
            children: [
              Expanded(
                child: Text('Total', style: context.text.titleMedium),
              ),
              Text(
                '+${breakdown.total} XP',
                style: context.text.titleLarge?.copyWith(
                  color: colors.isDark ? colors.xp : const Color(0xFF8A6100),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "What would you like to focus on next?"
class _NextUpPanel extends ConsumerWidget {
  const _NextUpPanel({
    required this.completedTaskId,
    required this.autoSuggest,
    required this.onStart,
    required this.onDismiss,
  });

  final String completedTaskId;
  final bool autoSuggest;
  final ValueChanged<TaskCard> onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingCardsProvider);
    // Exclude the task just finished — offering it back would be nonsense if
    // the user chose "Later".
    final candidates =
        upcoming.items.where((c) => c.id != completedTaskId).toList();

    if (!autoSuggest || candidates.isEmpty) {
      return Column(
        children: [
          Text(
            candidates.isEmpty
                ? 'That was the last one. Take the win.'
                : 'Session saved.',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppGeometry.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDismiss,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: const Text('Done'),
            ),
          ),
        ],
      );
    }

    final next = candidates.first;
    final board = ref.watch(boardProvider(next.boardId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What would you like to focus on next?',
          style: context.text.titleMedium,
        ),
        const SizedBox(height: AppGeometry.md),
        TaskCardTile(card: next, board: board, showBoardName: true, compact: true),
        const SizedBox(height: AppGeometry.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                child: const Text('Not now'),
              ),
            ),
            const SizedBox(width: AppGeometry.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onStart(next),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppGeometry.sm),
        Center(
          child: TextButton(
            onPressed: () {
              onDismiss();
              context.go(Routes.boards);
            },
            child: const Text('Choose another task'),
          ),
        ),
      ],
    );
  }
}
