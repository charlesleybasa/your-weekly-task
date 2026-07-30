import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/board.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../state/boards_controller.dart';
import '../../state/cards_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/pressable.dart';
import '../boards/board_editor_sheet.dart';

/// The fast path for capturing a task: name, board, day, estimate, priority.
///
/// Everything except the name has a sensible default, so the minimum
/// interaction is "type, press return". Anything richer belongs in the full
/// editor, reached by opening the card afterwards.
Future<void> showQuickAddSheet(
  BuildContext context, {
  String? boardId,
  DateTime? day,
  TaskStatus status = TaskStatus.todo,
}) {
  return showAppSheet<void>(
    context: context,
    semanticLabel: 'Quick add task',
    builder: (_) => _QuickAddSheet(
      initialBoardId: boardId,
      initialDay: day,
      status: status,
    ),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({
    this.initialBoardId,
    this.initialDay,
    required this.status,
  });

  final String? initialBoardId;
  final DateTime? initialDay;
  final TaskStatus status;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _boardId;
  DateTime? _day;
  int _minutes = 25;
  Priority _priority = Priority.medium;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boardId = widget.initialBoardId;
    _day = widget.initialDay ?? DateTime.now().dayStart;
    // Open with the keyboard up — this sheet exists to be typed into.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a name');
      _focusNode.requestFocus();
      return;
    }

    final boards = ref.read(boardsProvider);
    var boardId = _boardId ?? (boards.isEmpty ? null : boards.first.id);

    if (boardId == null) {
      // No boards yet — make one rather than blocking capture.
      final created = await ref.read(boardsProvider.notifier).create(
            title: 'My Tasks',
            colorValue: suggestBoardStyle(0).color,
            iconKey: suggestBoardStyle(0).iconKey,
          );
      boardId = created.id;
    }

    setState(() => _submitting = true);

    await ref.read(cardsProvider.notifier).create(
          boardId: boardId,
          title: title,
          priority: _priority,
          estimatedMinutes: _minutes,
          scheduledDay: _day,
          status: widget.status,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final boards = ref.watch(boardsProvider);
    final selectedBoard = boards.where((b) => b.id == _boardId).firstOrNull ??
        (boards.isEmpty ? null : boards.first);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(
            title: 'New task',
            subtitle: 'Name it, place it, done.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: context.text.bodyLarge,
              decoration: InputDecoration(
                hintText: 'What needs doing?',
                errorText: _error,
                prefixIcon: const Icon(Icons.check_circle_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppGeometry.xl),

          _FieldLabel('Board'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
              children: [
                for (final board in boards)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _BoardPill(
                      board: board,
                      selected: selectedBoard?.id == board.id,
                      onTap: () => setState(() => _boardId = board.id),
                    ),
                  ),
                Pressable(
                  onTap: () async {
                    final created = await showBoardEditorSheet(context);
                    if (created != null && mounted) {
                      setState(() => _boardId = created.id);
                    }
                  },
                  borderRadius: AppGeometry.brPill,
                  semanticLabel: 'New board',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: AppGeometry.brPill,
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: colors.textSecondary),
                        const SizedBox(width: 4),
                        Text('Board', style: context.text.labelMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.lg),

          _FieldLabel('Day'),
          SizedBox(
            height: 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
              children: [
                _DayPill(
                  label: 'None',
                  sub: '—',
                  selected: _day == null,
                  onTap: () => setState(() => _day = null),
                ),
                for (final day in DateTime.now().weekDays)
                  _DayPill(
                    label: day.shortDayName,
                    sub: day.dayNumber,
                    selected: _day != null && _day!.isSameDay(day),
                    isToday: day.isToday,
                    onTap: () => setState(() => _day = day),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.lg),

          _FieldLabel('Estimate'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: Wrap(
              spacing: 8,
              children: [
                for (final minutes in const [10, 15, 25, 45, 60, 90])
                  _ChoicePill(
                    label: '${minutes}m',
                    selected: _minutes == minutes,
                    onTap: () => setState(() => _minutes = minutes),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.lg),

          _FieldLabel('Priority'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: Row(
              children: [
                for (final priority in Priority.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ChoicePill(
                      label: priority.label,
                      selected: _priority == priority,
                      accent: priority.color(colors),
                      onTap: () => setState(() => _priority = priority),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppGeometry.xxl),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppGeometry.xl,
              0,
              AppGeometry.xl,
              AppGeometry.xl,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: Text(_submitting ? 'Adding…' : 'Add task'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGeometry.xl,
        0,
        AppGeometry.xl,
        AppGeometry.sm,
      ),
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

class _BoardPill extends StatelessWidget {
  const _BoardPill({
    required this.board,
    required this.selected,
    required this.onTap,
  });

  final Board board;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brPill,
      semanticLabel: 'Board ${board.title}',
      child: AnimatedContainer(
        duration: context.motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? board.color.withValues(alpha: colors.isDark ? 0.22 : 0.14)
              : colors.surfaceSunken,
          borderRadius: AppGeometry.brPill,
          border: Border.all(
            color: selected ? board.color : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(board.icon, size: 15, color: board.color),
            const SizedBox(width: 6),
            Text(
              board.title,
              style: context.text.labelMedium?.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
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
        semanticLabel: '$label $sub',
        minSize: 48,
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
              const SizedBox(height: 1),
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

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
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
      semanticLabel: label,
      minSize: 44,
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
