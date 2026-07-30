import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/board.dart';
import '../../core/models/focus_session.dart';
import '../../core/models/task_card.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../routing/app_router.dart';
import '../../state/boards_controller.dart';
import '../../state/cards_controller.dart';
import '../../state/sessions_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/timer_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';
import '../tasks/task_card_tile.dart';
import 'timer_complete_sheet.dart';

/// One timer, one task, nothing else on screen.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _handlingCompletion = false;

  Future<void> _onTimerFinished() async {
    if (_handlingCompletion) return;
    _handlingCompletion = true;

    final snapshot = ref.read(timerProvider);
    final taskId = snapshot.taskId;
    final perfectFocus = !snapshot.wasPaused;

    // Close out the session before the sheet so statistics are already correct
    // when the user sees them.
    await ref.read(timerProvider.notifier).stop(completed: true);

    if (!mounted || taskId == null) {
      _handlingCompletion = false;
      return;
    }

    await showTimerCompleteSheet(
      context,
      taskId: taskId,
      perfectFocus: perfectFocus,
    );

    _handlingCompletion = false;
  }

  @override
  Widget build(BuildContext context) {
    // The transition into `finished` is the single trigger for the completion
    // flow, wherever the app happens to be when it fires.
    ref.listen<TimerSnapshot>(timerProvider, (previous, next) {
      final crossed = (previous?.finished ?? false) == false && next.finished;
      if (crossed) _onTimerFinished();
    });

    final snapshot = ref.watch(timerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SoftSwitcher(
          child: snapshot.isActive
              ? _RunningView(key: const ValueKey('running'), snapshot: snapshot)
              : const _IdleView(key: ValueKey('idle')),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Idle
// ---------------------------------------------------------------------------

class _IdleView extends ConsumerWidget {
  const _IdleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = context.geometry.gutter;
    final suggested = ref.watch(suggestedTaskProvider);
    final recent = ref.watch(recentSessionsProvider);

    if (suggested == null) {
      return EmptyState(
        art: EmptyArt.timer,
        title: 'Ready to focus?',
        message: 'Add a task first, then start a timer and give it your full '
            'attention.',
        actionLabel: 'Browse boards',
        onAction: () => context.go(Routes.boards),
      );
    }

    final board = ref.watch(boardProvider(suggested.boardId));

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppGeometry.md, gutter, 140),
      children: [
        StaggerReveal(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Focus', style: context.text.displaySmall),
              Text(
                'One task. One timer. No overlap.',
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppGeometry.section),
        StaggerReveal(
          index: 1,
          child: _SuggestedTaskCard(card: suggested, board: board),
        ),
        const SizedBox(height: AppGeometry.section),
        StaggerReveal(
          index: 2,
          child: _StartPanel(card: suggested),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: AppGeometry.section),
          StaggerReveal(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Recent sessions'),
                for (final session in recent.take(5))
                  _SessionRow(session: session),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SuggestedTaskCard extends StatelessWidget {
  const _SuggestedTaskCard({required this.card, required this.board});

  final TaskCard card;
  final Board? board;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 15, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              'SUGGESTED NEXT',
              style: context.text.labelSmall?.copyWith(
                color: colors.primaryText,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppGeometry.md),
        TaskCardTile(card: card, board: board, showBoardName: true),
      ],
    );
  }
}

/// Preset picker and the start button.
class _StartPanel extends ConsumerStatefulWidget {
  const _StartPanel({required this.card});

  final TaskCard card;

  @override
  ConsumerState<_StartPanel> createState() => _StartPanelState();
}

class _StartPanelState extends ConsumerState<_StartPanel> {
  int? _minutes;

  int get _selected =>
      _minutes ?? ref.read(settingsProvider).defaultTimerMinutes;

  Future<void> _customDuration() async {
    var value = _selected.toDouble();
    final result = await showAppSheet<int>(
      context: context,
      semanticLabel: 'Custom duration',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Custom duration'),
            Text(
              '${value.round()} minutes',
              style: AppTypography.stat(context.colors.textPrimary, size: 34),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
              child: Slider(
                value: value,
                min: 5,
                max: 180,
                divisions: 35,
                label: '${value.round()}m',
                onChanged: (v) => setSheetState(() => value = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppGeometry.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(value.round()),
                  child: const Text('Use this duration'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) setState(() => _minutes = result);
  }

  Future<void> _start() async {
    await ref
        .read(timerProvider.notifier)
        .start(widget.card, minutes: _selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = _selected;

    return AppSurface(
      padding: const EdgeInsets.all(AppGeometry.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How long?', style: context.text.titleLarge),
          const SizedBox(height: AppGeometry.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in TimerPresets.minutes)
                _PresetChip(
                  label: '$preset',
                  selected: selected == preset,
                  onTap: () => setState(() => _minutes = preset),
                ),
              _PresetChip(
                label: 'Custom',
                selected: !TimerPresets.minutes.contains(selected),
                onTap: _customDuration,
                icon: Icons.tune_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppGeometry.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _start,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 56),
                backgroundColor: colors.primary,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text('Focus for ${selected} minutes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brMd,
      minSize: 48,
      semanticLabel: '$label minute timer',
      child: AnimatedContainer(
        duration: context.motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceSunken,
          borderRadius: AppGeometry.brMd,
          border: Border.all(
            color: selected ? colors.primary : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? colors.onPrimary : colors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: context.text.titleMedium?.copyWith(
                color: selected ? colors.onPrimary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGeometry.sm),
      child: Row(
        children: [
          Icon(
            session.completed
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            size: 16,
            color: session.completed ? colors.success : colors.textTertiary,
          ),
          const SizedBox(width: AppGeometry.md),
          Expanded(
            child: Text(
              session.taskTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(session.actual.compact, style: context.text.labelSmall),
          const SizedBox(width: 8),
          Text(
            session.startedAt.relativeDayLabel,
            style: context.text.labelSmall?.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Running
// ---------------------------------------------------------------------------

class _RunningView extends ConsumerWidget {
  const _RunningView({super.key, required this.snapshot});

  final TimerSnapshot snapshot;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context: context,
      title: 'Cancel this session?',
      message: 'Time focused so far is still recorded, but the session will '
          'not count as complete.',
      confirmLabel: 'Cancel session',
      cancelLabel: 'Keep going',
      destructive: true,
    );
    if (confirmed) await ref.read(timerProvider.notifier).cancel();
  }

  Future<void> _completeEarly(BuildContext context, WidgetRef ref) async {
    final taskId = snapshot.taskId;
    final perfectFocus = !snapshot.wasPaused;
    await ref.read(timerProvider.notifier).stop(completed: true);
    if (!context.mounted || taskId == null) return;
    await showTimerCompleteSheet(
      context,
      taskId: taskId,
      perfectFocus: perfectFocus,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final card = ref.watch(activeTimerCardProvider);
    final board = card == null ? null : ref.watch(boardProvider(card.boardId));
    final accent = board?.color ?? colors.primary;
    final finalStretch = snapshot.isFinalCountdown;
    final gutter = context.geometry.gutter;

    return Container(
      // The background dims and tints towards the board colour: the rest of the
      // app recedes so the countdown owns the screen.
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.1,
          colors: [
            (finalStretch ? colors.warning : accent)
                .withValues(alpha: colors.isDark ? 0.13 : 0.07),
            colors.background,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Column(
          children: [
            const SizedBox(height: AppGeometry.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (board != null)
                        Row(
                          children: [
                            Icon(board.icon, size: 14, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              board.title,
                              style: context.text.labelMedium
                                  ?.copyWith(color: accent),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      Text(
                        card?.title ?? 'Focus session',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineSmall,
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel session',
                  onPressed: () => _cancel(context, ref),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _CountdownRing(
                  snapshot: snapshot,
                  accent: finalStretch ? colors.warning : accent,
                  glow: finalStretch,
                ),
              ),
            ),
            _TimerControls(
              snapshot: snapshot,
              accent: accent,
              onPause: () => ref.read(timerProvider.notifier).pause(),
              onResume: () => ref.read(timerProvider.notifier).resume(),
              onExtend: () => ref.read(timerProvider.notifier).extend(5),
              onComplete: () => _completeEarly(context, ref),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}

/// The countdown. The ring interpolates smoothly between one-second state
/// updates, and pulses on each minute boundary.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.snapshot,
    required this.accent,
    required this.glow,
  });

  final TimerSnapshot snapshot;
  final Color accent;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = (context.screenSize.shortestSide * 0.68).clamp(220.0, 320.0);
    final remaining = snapshot.remaining;
    final paused = snapshot.isPaused;

    return RepaintBoundary(
      child: ProgressRing(
        value: snapshot.progress,
        size: size,
        strokeWidth: 14,
        color: accent,
        gradientEnd: glow ? colors.danger : accent.lighten(0.18),
        glow: glow,
        // Matches the tick interval so the arc advances continuously rather
        // than stepping once per second.
        duration: const Duration(milliseconds: 950),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingTime(
              text: remaining.clock,
              pulse: glow,
              color: paused ? colors.textTertiary : colors.textPrimary,
              size: size * 0.2,
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: context.motion.fast,
              child: Text(
                paused
                    ? 'Paused'
                    : glow
                        ? 'Almost there'
                        : 'of ${Duration(seconds: snapshot.timer?.totalSeconds ?? 0).compact}',
                key: ValueKey('$paused$glow'),
                style: context.text.labelMedium?.copyWith(
                  color: paused ? colors.warning : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingTime extends StatefulWidget {
  const _PulsingTime({
    required this.text,
    required this.pulse,
    required this.color,
    required this.size,
  });

  final String text;
  final bool pulse;
  final Color color;
  final double size;

  @override
  State<_PulsingTime> createState() => _PulsingTimeState();
}

class _PulsingTimeState extends State<_PulsingTime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void didUpdateWidget(_PulsingTime old) {
    super.didUpdateWidget(old);
    // A beat on every second of the final countdown; otherwise only when the
    // minute rolls over, so the pulse stays meaningful.
    final minuteRolled = old.text.endsWith(':00') != widget.text.endsWith(':00') &&
        widget.text.endsWith(':00');
    if (widget.text != old.text && (widget.pulse || minuteRolled)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.text,
      style: AppTypography.timerDigits(widget.color, size: widget.size),
    );

    if (!context.motion.enabled) return label;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        // Quick swell that settles back — a scale that only grows would leave
        // the digits permanently offset.
        final scale = 1 + 0.06 * (t < 0.4 ? t / 0.4 : (1 - t) / 0.6);
        return Transform.scale(scale: scale, child: child);
      },
      child: label,
    );
  }
}

class _TimerControls extends StatelessWidget {
  const _TimerControls({
    required this.snapshot,
    required this.accent,
    required this.onPause,
    required this.onResume,
    required this.onExtend,
    required this.onComplete,
  });

  final TimerSnapshot snapshot;
  final Color accent;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onExtend;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final paused = snapshot.isPaused;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleControl(
              icon: Icons.add_rounded,
              label: '+5 min',
              onTap: onExtend,
              color: colors.textSecondary,
              background: colors.surfaceSunken,
            ),
            const SizedBox(width: AppGeometry.xl),
            _CircleControl(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: paused ? 'Resume' : 'Pause',
              onTap: paused ? onResume : onPause,
              color: colors.onPrimary,
              background: accent,
              large: true,
            ),
            const SizedBox(width: AppGeometry.xl),
            _CircleControl(
              icon: Icons.check_rounded,
              label: 'Finish',
              onTap: onComplete,
              color: colors.success,
              background: colors.successSoft,
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.background,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 72.0 : 56.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          semanticLabel: label,
          hoverScale: 1.06,
          enableHoverGlow: large,
          glowColor: background,
          minSize: 48,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: large
                  ? [
                      BoxShadow(
                        color: background.withValues(alpha: 0.4),
                        blurRadius: 22,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: color, size: large ? 32 : 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}
