import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/task_card.dart';
import '../../core/services/id_service.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../state/boards_controller.dart';
import '../../state/cards_controller.dart';
import '../../state/gamification_controller.dart';
import '../../state/timer_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/pressable.dart';
import '../../widgets/surfaces.dart';

/// Full card editor. Opened by tapping a card anywhere in the app.
///
/// Saves on change rather than behind a "Save" button — the app is offline and
/// single-user, so there is nothing to reconcile and an explicit save step
/// would only be a way to lose work.
Future<void> showTaskEditorSheet(BuildContext context, String cardId) {
  return showAppSheet<void>(
    context: context,
    semanticLabel: 'Edit task',
    builder: (_) => _TaskEditorSheet(cardId: cardId),
  );
}

class _TaskEditorSheet extends ConsumerStatefulWidget {
  const _TaskEditorSheet({required this.cardId});

  final String cardId;

  @override
  ConsumerState<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<_TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  final _newChecklistItem = TextEditingController();

  @override
  void initState() {
    super.initState();
    final card = ref.read(cardsProvider).byId[widget.cardId];
    _title = TextEditingController(text: card?.title ?? '');
    _description = TextEditingController(text: card?.description ?? '');
    _notes = TextEditingController(text: card?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _notes.dispose();
    _newChecklistItem.dispose();
    super.dispose();
  }

  TaskCard? get _card => ref.read(cardsProvider).byId[widget.cardId];

  void _patch(TaskCard Function(TaskCard) transform) {
    final card = _card;
    if (card == null) return;
    ref.read(cardsProvider.notifier).update(transform(card));
  }

  Future<void> _delete() async {
    final card = _card;
    if (card == null) return;

    final confirmed = await confirmAction(
      context: context,
      title: 'Delete task?',
      message: '"${card.title}" will be removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await ref.read(cardsProvider.notifier).delete(card.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _startTimer() async {
    final card = _card;
    if (card == null) return;

    final timer = ref.read(timerProvider);
    if (timer.isActive && timer.taskId != card.id) {
      final replace = await confirmAction(
        context: context,
        title: 'A timer is already running',
        message: 'Only one timer can run at a time. Stop the current one and '
            'start this task instead?',
        confirmLabel: 'Switch',
      );
      if (!replace || !mounted) return;
      await ref.read(timerProvider.notifier).stop(completed: false);
    }

    await ref
        .read(timerProvider.notifier)
        .start(card, minutes: card.estimatedMinutes);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _complete() async {
    final card = _card;
    if (card == null) return;
    Navigator.of(context).pop();
    await ref.read(statsProvider.notifier).completeTask(card.id);
  }

  void _addChecklistItem() {
    final label = _newChecklistItem.text.trim();
    if (label.isEmpty) return;
    _patch(
      (card) => card.copyWith(
        checklist: [
          ...card.checklist,
          ChecklistItem(id: Ids.next(), label: label),
        ],
      ),
    );
    _newChecklistItem.clear();
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(cardProvider(widget.cardId));
    if (card == null) {
      // The card was deleted from under us (e.g. its board was removed).
      return const SizedBox(
        height: 220,
        child: Center(child: Text('This task no longer exists.')),
      );
    }

    final colors = context.colors;
    final board = ref.watch(boardProvider(card.boardId));
    final accent = board?.color ?? colors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: 'Task',
          subtitle: board?.title,
          trailing: AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete task',
            color: colors.danger,
            onPressed: _delete,
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppGeometry.xl,
              0,
              AppGeometry.xl,
              AppGeometry.xl,
            ),
            children: [
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: context.text.titleLarge,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (value) => _patch(
                  (card) => card.copyWith(
                    title: value.trim().isEmpty ? 'Untitled task' : value.trim(),
                  ),
                ),
              ),
              const SizedBox(height: AppGeometry.md),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What does done look like?',
                ),
                onChanged: (value) =>
                    _patch((card) => card.copyWith(description: value)),
              ),
              const SizedBox(height: AppGeometry.xl),

              _EditorLabel('Status'),
              SegmentedButton<TaskStatus>(
                segments: [
                  for (final status in TaskStatus.values)
                    ButtonSegment(
                      value: status,
                      label: Text(status.label),
                      icon: Icon(status.icon, size: 16),
                    ),
                ],
                selected: {card.status},
                showSelectedIcon: false,
                onSelectionChanged: (selection) async {
                  final next = selection.first;
                  if (next == card.status) return;
                  if (next.isDone) {
                    await _complete();
                  } else {
                    await ref
                        .read(cardsProvider.notifier)
                        .move(cardId: card.id, toStatus: next);
                  }
                },
              ),
              const SizedBox(height: AppGeometry.xl),

              _EditorLabel('Priority'),
              Row(
                children: [
                  for (final priority in Priority.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Toggle(
                        label: priority.label,
                        selected: card.priority == priority,
                        accent: priority.color(colors),
                        onTap: () =>
                            _patch((c) => c.copyWith(priority: priority)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppGeometry.xl),

              _EditorLabel('Scheduled day'),
              SizedBox(
                height: 62,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _DayChip(
                      label: 'None',
                      sub: '—',
                      selected: !card.isScheduled,
                      onTap: () =>
                          ref.read(cardsProvider.notifier).schedule(card.id, null),
                    ),
                    for (final day in DateTime.now().weekDays)
                      _DayChip(
                        label: day.shortDayName,
                        sub: day.dayNumber,
                        selected: card.isScheduledOn(day),
                        isToday: day.isToday,
                        onTap: () => ref
                            .read(cardsProvider.notifier)
                            .schedule(card.id, day),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppGeometry.xl),

              _EditorLabel('Estimate — ${card.estimate.compact} · '
                  '${card.size.label} · ${card.baseXp} XP'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in const [10, 15, 25, 45, 60, 90, 120])
                    _Toggle(
                      label: '${minutes}m',
                      selected: card.estimatedMinutes == minutes,
                      onTap: () => _patch(
                        (c) => c.copyWith(estimatedMinutes: minutes),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppGeometry.xl),

              _EditorLabel('Checklist'),
              for (final item in card.checklist)
                _ChecklistRow(
                  item: item,
                  onToggle: () => ref
                      .read(cardsProvider.notifier)
                      .toggleChecklistItem(card.id, item.id),
                  onDelete: () => _patch(
                    (c) => c.copyWith(
                      checklist:
                          c.checklist.where((i) => i.id != item.id).toList(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppGeometry.sm),
                child: TextField(
                  controller: _newChecklistItem,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addChecklistItem(),
                  decoration: InputDecoration(
                    hintText: 'Add a step…',
                    prefixIcon: const Icon(Icons.add_rounded, size: 20),
                    suffixIcon: AppIconButton(
                      icon: Icons.keyboard_return_rounded,
                      tooltip: 'Add checklist item',
                      onPressed: _addChecklistItem,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppGeometry.xl),

              _EditorLabel('Notes'),
              TextField(
                controller: _notes,
                maxLines: 5,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Anything you want to remember.',
                ),
                onChanged: (value) => _patch((c) => c.copyWith(notes: value)),
              ),
              const SizedBox(height: AppGeometry.xl),

              if (card.focusedSeconds > 0)
                AppSurface(
                  color: colors.surfaceSunken,
                  showBorder: false,
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 18, color: colors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${card.focused.compact} focused across '
                          '${card.completedSessions} session'
                          '${card.completedSessions == 1 ? '' : 's'}',
                          style: context.text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppGeometry.xl),
              Row(
                children: [
                  if (!card.isDone) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Focus'),
                      ),
                    ),
                    const SizedBox(width: AppGeometry.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _complete,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.success,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Complete'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(cardsProvider.notifier)
                              .reopen(card.id);
                        },
                        icon: const Icon(Icons.undo_rounded, size: 20),
                        label: const Text('Reopen task'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppGeometry.md),
              Center(
                child: Text(
                  'Created ${card.createdAt.monthDay} · '
                  'Updated ${card.updatedAt.relativeDayLabel}',
                  style: context.text.labelSmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGeometry.sm),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = accent ?? colors.primary;
    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brPill,
      minSize: 44,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: context.motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: colors.isDark ? 0.22 : 0.14)
              : colors.surfaceSunken,
          borderRadius: AppGeometry.brPill,
          border: Border.all(
            color: selected ? tint : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: selected ? colors.textPrimary : colors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.isToday = false,
  });

  final String label;
  final String sub;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        borderRadius: AppGeometry.brMd,
        minSize: 48,
        semanticLabel: '$label $sub',
        child: AnimatedContainer(
          duration: context.motion.fast,
          width: 54,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceSunken,
            borderRadius: AppGeometry.brMd,
            border: Border.all(
              color: selected
                  ? colors.primary
                  : isToday
                      ? colors.primary.withValues(alpha: 0.45)
                      : colors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? colors.onPrimary : colors.textTertiary,
                ),
              ),
              Text(
                sub,
                style: context.text.titleSmall?.copyWith(
                  color: selected ? colors.onPrimary : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Pressable(
          onTap: onToggle,
          sfx: null,
          minSize: 44,
          borderRadius: BorderRadius.circular(8),
          semanticLabel: item.done
              ? 'Mark "${item.label}" incomplete'
              : 'Mark "${item.label}" complete',
          child: AnimatedContainer(
            duration: context.motion.fast,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: item.done ? colors.success : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: item.done ? colors.success : colors.borderStrong,
                width: 1.7,
              ),
            ),
            child: item.done
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            item.label,
            style: context.text.bodyMedium?.copyWith(
              color: item.done ? colors.textTertiary : colors.textPrimary,
              decoration: item.done ? TextDecoration.lineThrough : null,
              decorationColor: colors.textTertiary,
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Remove "${item.label}"',
          onPressed: onDelete,
          size: 16,
        ),
      ],
    );
  }
}
