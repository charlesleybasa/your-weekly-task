import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/board.dart';
import '../../core/models/enums.dart';
import '../../core/models/task_card.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/context_x.dart';
import '../../routing/app_router.dart';
import '../../state/app_providers.dart';
import '../../state/boards_controller.dart';
import '../../state/card_index.dart';
import '../../state/cards_controller.dart';
import '../../state/gamification_controller.dart';
import '../../state/timer_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/particles.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../tasks/quick_add_sheet.dart';
import '../tasks/task_card_tile.dart';
import '../tasks/task_editor_sheet.dart';
import 'board_editor_sheet.dart';

/// The kanban board: exactly three columns, drag and drop between them.
class BoardDetailScreen extends ConsumerWidget {
  const BoardDetailScreen({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(boardId));
    final stats = ref.watch(cardsProvider.select((i) => i.statsFor(boardId)));

    if (board == null) {
      return Scaffold(
        appBar: AppBar(leading: const _BackButton()),
        body: EmptyState(
          art: EmptyArt.boards,
          title: 'Board not found',
          message: 'It may have been deleted.',
          actionLabel: 'Back to boards',
          onAction: () => context.go(Routes.boards),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _BoardHeader(board: board, stats: stats),
            Expanded(child: _KanbanArea(board: board)),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back to boards',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.boards);
        }
      },
    );
  }
}

class _BoardHeader extends ConsumerWidget {
  const _BoardHeader({required this.board, required this.stats});

  final Board board;
  final BoardStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accent = board.color;
    final gutter = context.geometry.gutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter - 8, AppGeometry.sm, gutter - 8, AppGeometry.md),
      child: Column(
        children: [
          Row(
            children: [
              const _BackButton(),
              const SizedBox(width: 4),
              Hero(
                tag: 'board-icon-${board.id}',
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.lighten(0.12), accent],
                    ),
                    borderRadius: AppGeometry.brMd,
                  ),
                  child: Icon(
                    board.icon,
                    color: AppColors.onAccent(accent),
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: AppGeometry.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      board.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall,
                    ),
                    Text(
                      '${stats.done} of ${stats.total} done',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit board',
                onPressed: () => showBoardEditorSheet(context, existing: board),
              ),
              AppIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add card to ${board.title}',
                onPressed: () => showQuickAddSheet(context, boardId: board.id),
                color: colors.primaryText,
                background: colors.primarySoft,
              ),
            ],
          ),
          const SizedBox(height: AppGeometry.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AppProgressBar(
              value: stats.completion,
              color: accent,
              height: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanArea extends ConsumerWidget {
  const _KanbanArea({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = context.screenSize.width;
    final gutter = context.geometry.gutter;

    // On a phone the columns scroll horizontally at ~82% width so the next one
    // is always partly visible — that peek is what tells you it is scrollable.
    final wide = width >= 900;
    final columnWidth = wide
        ? (width - gutter * 2 - AppGeometry.md * 2) / 3
        : (width * 0.82).clamp(240.0, 340.0);

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppGeometry.md),
      physics: wide
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: TaskStatus.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppGeometry.md),
      itemBuilder: (context, index) {
        final status = TaskStatus.values[index];
        return SizedBox(
          width: columnWidth,
          child: StaggerReveal(
            index: index,
            horizontal: true,
            offset: 24,
            child: _KanbanColumn(board: board, status: status),
          ),
        );
      },
    );
  }
}

class _KanbanColumn extends ConsumerStatefulWidget {
  const _KanbanColumn({required this.board, required this.status});

  final Board board;
  final TaskStatus status;

  @override
  ConsumerState<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends ConsumerState<_KanbanColumn> {
  /// Gap index currently under the pointer, or null.
  int? _hoveredGap;

  /// Set briefly after a drop so the landing card can pop.
  String? _justDropped;

  Future<void> _handleDrop(TaskCard card, int index) async {
    setState(() {
      _hoveredGap = null;
      _justDropped = card.id;
    });

    if (widget.status.isDone && !card.isDone) {
      // Dropping into Done is a completion, not just a move — route it through
      // the gamification controller so XP and achievements always fire.
      await ref.read(statsProvider.notifier).completeTask(card.id);
    } else {
      await ref.read(cardsProvider.notifier).move(
            cardId: card.id,
            toStatus: widget.status,
            toIndex: index,
            toBoardId: widget.board.id,
          );
    }

    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted && _justDropped == card.id) {
      setState(() => _justDropped = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cards = ref.watch(
      columnCardsProvider((boardId: widget.board.id, status: widget.status)),
    );

    return DragTarget<TaskCard>(
      // Any card is welcome in any column — dropping across boards moves it.
      onWillAcceptWithDetails: (_) => true,
      // Dropping on the column background (rather than a specific gap) appends.
      onAcceptWithDetails: (details) => _handleDrop(details.data, cards.length),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: context.motion.fast,
          decoration: BoxDecoration(
            color: active
                ? widget.board.color.withValues(alpha: colors.isDark ? 0.09 : 0.06)
                : colors.surfaceSunken.withValues(alpha: colors.isDark ? 0.5 : 0.7),
            borderRadius: AppGeometry.brXl,
            border: Border.all(
              color: active ? widget.board.color : colors.border,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              _ColumnHeader(
                status: widget.status,
                count: cards.length,
                accent: widget.board.color,
                onAdd: () => showQuickAddSheet(
                  context,
                  boardId: widget.board.id,
                  status: widget.status,
                ),
              ),
              Expanded(child: _buildList(cards)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(CardSlice cards) {
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppGeometry.md),
        child: _DropGap(
          index: 0,
          hovered: _hoveredGap == 0,
          expanded: true,
          onHover: (v) => setState(() => _hoveredGap = v ? 0 : null),
          onDrop: (card) => _handleDrop(card, 0),
          child: InlineEmpty(
            message: switch (widget.status) {
              TaskStatus.todo => 'Nothing queued.\nAdd a card to get going.',
              TaskStatus.started => 'Nothing in progress.\nDrag a card here to start.',
              TaskStatus.done => 'No wins yet this week.',
            },
            icon: widget.status.icon,
            onTap: widget.status == TaskStatus.todo
                ? () => showQuickAddSheet(context, boardId: widget.board.id)
                : null,
            actionLabel: widget.status == TaskStatus.todo ? 'Add a card' : null,
          ),
        ),
      );
    }

    // ListView.builder over 2n+1 slots: gap, card, gap, card, … so a drop can
    // target an exact position rather than only the end of the column.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppGeometry.md,
        0,
        AppGeometry.md,
        AppGeometry.huge,
      ),
      itemCount: cards.length * 2 + 1,
      itemBuilder: (context, i) {
        if (i.isEven) {
          final gapIndex = i ~/ 2;
          return _DropGap(
            index: gapIndex,
            hovered: _hoveredGap == gapIndex,
            onHover: (v) => setState(() => _hoveredGap = v ? gapIndex : null),
            onDrop: (card) => _handleDrop(card, gapIndex),
          );
        }

        final card = cards[i ~/ 2];
        return _DraggableCard(
          key: ValueKey(card.id),
          card: card,
          board: widget.board,
          index: i ~/ 2,
          justDropped: _justDropped == card.id,
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.status,
    required this.count,
    required this.accent,
    required this.onAdd,
  });

  final TaskStatus status;
  final int count;
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = status.color(colors);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGeometry.lg,
        AppGeometry.md,
        AppGeometry.sm,
        AppGeometry.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppGeometry.sm),
          Text(status.label, style: context.text.titleMedium),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Text('$count', style: context.text.labelSmall),
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Add to ${status.label}',
            onPressed: onAdd,
            size: 18,
          ),
        ],
      ),
    );
  }
}

/// The insertion slot between two cards.
///
/// Collapsed it is a few pixels of padding; while a card hovers over it, it
/// swells into a pulsing placeholder and the cards below slide down.
class _DropGap extends StatelessWidget {
  const _DropGap({
    required this.index,
    required this.hovered,
    required this.onHover,
    required this.onDrop,
    this.expanded = false,
    this.child,
  });

  final int index;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final ValueChanged<TaskCard> onDrop;
  final bool expanded;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;

    return DragTarget<TaskCard>(
      onWillAcceptWithDetails: (_) {
        onHover(true);
        return true;
      },
      onLeave: (_) => onHover(false),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: motion.fast,
          curve: motion.decelerate,
          height: child != null ? null : (active ? 74 : 8),
          margin: EdgeInsets.symmetric(vertical: active ? 6 : 0),
          decoration: active
              ? BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: AppGeometry.brLg,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                )
              : null,
          child: child ??
              (active
                  ? Center(
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    )
                  : null),
        );
      },
    );
  }
}

/// A card you can pick up.
///
/// Long-press starts the drag on touch; on desktop the delay is shortened so a
/// mouse drag feels immediate without stealing the click.
class _DraggableCard extends ConsumerStatefulWidget {
  const _DraggableCard({
    super.key,
    required this.card,
    required this.board,
    required this.index,
    required this.justDropped,
  });

  final TaskCard card;
  final Board board;
  final int index;
  final bool justDropped;

  @override
  ConsumerState<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends ConsumerState<_DraggableCard> {
  bool _dragging = false;

  static bool get _isPointerFirst =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> _toggleDone() async {
    if (widget.card.isDone) {
      await ref.read(cardsProvider.notifier).reopen(widget.card.id);
    } else {
      await ref.read(statsProvider.notifier).completeTask(widget.card.id);
    }
  }

  Future<void> _startTimer() async {
    final timer = ref.read(timerProvider);
    if (timer.isActive && timer.taskId != widget.card.id) {
      final replace = await confirmAction(
        context: context,
        title: 'A timer is already running',
        message: 'Stop it and focus on "${widget.card.title}" instead?',
        confirmLabel: 'Switch',
      );
      if (!replace || !mounted) return;
      await ref.read(timerProvider.notifier).stop(completed: false);
    }

    await ref
        .read(timerProvider.notifier)
        .start(widget.card, minutes: widget.card.estimatedMinutes);
    if (mounted) context.go(Routes.focus);
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;

    final tile = TaskCardTile(
      card: widget.card,
      board: widget.board,
      onTap: () => showTaskEditorSheet(context, widget.card.id),
      onToggleDone: _toggleDone,
      onStartTimer: widget.card.isDone ? null : _startTimer,
    );

    final feedback = Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: motion.dragTilt,
        child: Transform.scale(
          scale: motion.dragScale,
          child: SizedBox(
            width: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppGeometry.brLg,
                boxShadow:
                    AppGeometry.dragging(context.colors, widget.board.color),
              ),
              child: TaskCardTile(
                card: widget.card,
                board: widget.board,
                dragging: true,
              ),
            ),
          ),
        ),
      ),
    );

    // The vacated slot: a dashed-feel ghost that keeps the layout from
    // collapsing while the card is in the air.
    final placeholder = Opacity(
      opacity: 0.35,
      child: IgnorePointer(
        child: TaskCardTile(
          card: widget.card,
          board: widget.board,
          dragging: true,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LongPressDraggable<TaskCard>(
        data: widget.card,
        delay: _isPointerFirst
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 220),
        feedback: feedback,
        childWhenDragging: placeholder,
        onDragStarted: () {
          setState(() => _dragging = true);
          ref.read(soundServiceProvider).play(Sfx.pickUp, volume: 0.8);
        },
        onDragEnd: (_) => setState(() => _dragging = false),
        onDraggableCanceled: (_, __) => setState(() => _dragging = false),
        child: Stack(
          children: [
            AnimatedScale(
              scale: _dragging ? 0.98 : 1,
              duration: motion.fast,
              child: StaggerReveal(index: widget.index, child: tile),
            ),
            // A small burst confirms the landing without stealing attention.
            if (widget.justDropped && motion.enabled)
              Positioned.fill(
                child: IgnorePointer(
                  child: ParticleBurst(
                    style: BurstStyle.ring,
                    count: 14,
                    origin: Alignment.center,
                    duration: const Duration(milliseconds: 620),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
