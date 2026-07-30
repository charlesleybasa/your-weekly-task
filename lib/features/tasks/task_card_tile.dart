import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/board.dart';
import '../../core/models/enums.dart';
import '../../core/models/task_card.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../state/timer_controller.dart';
import '../../widgets/pressable.dart';
import '../../widgets/surfaces.dart';

/// The card. Used in kanban columns, day lists and the dashboard.
///
/// Density is controlled by [compact] rather than by forking the widget, so
/// every surface renders the same card with the same interaction language.
class TaskCardTile extends ConsumerWidget {
  const TaskCardTile({
    super.key,
    required this.card,
    required this.board,
    this.onTap,
    this.onToggleDone,
    this.onStartTimer,
    this.compact = false,
    this.showBoardName = false,
    this.dragging = false,
  });

  final TaskCard card;
  final Board? board;
  final VoidCallback? onTap;
  final VoidCallback? onToggleDone;
  final VoidCallback? onStartTimer;
  final bool compact;
  final bool showBoardName;

  /// Rendered as the drag feedback rather than in place.
  final bool dragging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accent = board?.color ?? colors.primary;
    final isTimerTarget =
        ref.watch(timerProvider.select((s) => s.taskId == card.id));

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onToggleDone != null) ...[
              _CompletionCheck(
                done: card.isDone,
                accent: colors.success,
                onTap: onToggleDone!,
              ),
              const SizedBox(width: AppGeometry.md),
            ] else if (!compact) ...[
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(top: 3, right: 10),
                decoration: BoxDecoration(
                  color: card.priority == Priority.low
                      ? accent.withValues(alpha: 0.5)
                      : card.priority.color(colors),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      // Strikethrough plus a muted colour: completion is never
                      // signalled by colour alone.
                      decoration:
                          card.isDone ? TextDecoration.lineThrough : null,
                      decorationColor: colors.textTertiary,
                      color: card.isDone
                          ? colors.textTertiary
                          : colors.textPrimary,
                    ),
                  ),
                  if (!compact && card.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (isTimerTarget) ...[
              const SizedBox(width: 8),
              _RunningBadge(color: colors.success),
            ] else if (onStartTimer != null && !card.isDone) ...[
              const SizedBox(width: 4),
              AppIconButton(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Start a timer for ${card.title}',
                onPressed: onStartTimer,
                color: colors.primaryText,
                size: 20,
              ),
            ],
          ],
        ),
        if (card.hasChecklist && !compact) ...[
          const SizedBox(height: AppGeometry.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: card.checklistProgress,
                    minHeight: 4,
                    backgroundColor: colors.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${card.checklistDone}/${card.checklist.length}',
                style: context.text.labelSmall,
              ),
            ],
          ),
        ],
        SizedBox(height: compact ? AppGeometry.sm : AppGeometry.md),
        _MetaRow(
          card: card,
          board: board,
          accent: accent,
          showBoardName: showBoardName,
          compact: compact,
        ),
      ],
    );

    final surface = AppSurface(
      padding: EdgeInsets.all(compact ? AppGeometry.md : AppGeometry.lg),
      accent: card.isDone ? null : accent,
      elevated: dragging,
      color: dragging ? colors.surfaceRaised : colors.surface,
      child: content,
    );

    if (dragging || onTap == null) return surface;

    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brLg,
      semanticLabel: '${card.title}, ${card.status.label}, '
          '${card.priority.label} priority',
      hoverLift: 4,
      hoverScale: 1.012,
      enableHoverGlow: true,
      glowColor: accent,
      sfx: null, // the destination screen plays its own cue
      child: surface,
    );
  }
}

/// Metadata strip: day, estimate, priority, tags, XP.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.card,
    required this.board,
    required this.accent,
    required this.showBoardName,
    required this.compact,
  });

  final TaskCard card;
  final Board? board;
  final Color accent;
  final bool showBoardName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final day = card.scheduledDay;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showBoardName && board != null)
          AppChip(
            label: board!.title,
            icon: board!.icon,
            dense: true,
            foreground: accent,
            background: accent.withValues(alpha: colors.isDark ? 0.18 : 0.12),
          ),
        if (day != null)
          AppChip(
            label: day.relativeDayLabel,
            icon: Icons.event_outlined,
            dense: true,
            foreground: day.isToday ? colors.primaryText : colors.textSecondary,
            background: day.isToday ? colors.primarySoft : null,
          ),
        AppChip(
          label: card.estimate.compact,
          icon: Icons.schedule_rounded,
          dense: true,
        ),
        if (card.priority != Priority.low)
          AppChip(
            label: card.priority.label,
            icon: card.priority == Priority.high
                ? Icons.keyboard_double_arrow_up_rounded
                : Icons.drag_handle_rounded,
            dense: true,
            foreground: card.priority.color(colors),
            background: card.priority.softColor(colors),
          ),
        if (!compact)
          for (final tag in card.tags.take(2))
            AppChip(label: '#$tag', dense: true),
        if (card.isDone && card.xpAwarded > 0)
          AppChip(
            label: '+${card.xpAwarded} XP',
            icon: Icons.auto_awesome_rounded,
            dense: true,
            foreground:
                colors.isDark ? colors.xp : const Color(0xFF8A6100),
            background: colors.xp.withValues(alpha: colors.isDark ? 0.16 : 0.2),
          ),
      ],
    );
  }
}

/// Checkbox that fills and draws its tick rather than snapping between states.
class _CompletionCheck extends StatelessWidget {
  const _CompletionCheck({
    required this.done,
    required this.accent,
    required this.onTap,
  });

  final bool done;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;

    return Pressable(
      onTap: onTap,
      sfx: null, // completion plays the success chime instead
      borderRadius: BorderRadius.circular(999),
      minSize: 44,
      semanticLabel: done ? 'Mark as not done' : 'Mark as done',
      child: AnimatedContainer(
        duration: motion.base,
        curve: motion.overshoot,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: done ? accent : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: done ? accent : colors.borderStrong,
            width: 1.8,
          ),
        ),
        child: AnimatedScale(
          scale: done ? 1 : 0,
          duration: motion.base,
          curve: motion.overshoot,
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _RunningBadge extends StatefulWidget {
  const _RunningBadge({required this.color});

  final Color color;

  @override
  State<_RunningBadge> createState() => _RunningBadgeState();
}

class _RunningBadgeState extends State<_RunningBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: widget.color),
          const SizedBox(width: 4),
          Text(
            'Running',
            style: context.text.labelSmall?.copyWith(color: widget.color),
          ),
        ],
      ),
    );

    if (!context.motion.enabled) return badge;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.62, end: 1).animate(_controller),
      child: badge,
    );
  }
}
