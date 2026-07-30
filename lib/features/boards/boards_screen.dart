import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/board.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/context_x.dart';
import '../../routing/app_router.dart';
import '../../state/boards_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';
import 'board_editor_sheet.dart';

class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardsWithStatsProvider);
    final geometry = context.geometry;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: boards.isEmpty
            ? EmptyState(
                art: EmptyArt.boards,
                title: 'No boards yet',
                message:
                    'Boards group your work — Work, Personal, Study, whatever '
                    'fits your week.',
                actionLabel: 'Create your first board',
                onAction: () => showBoardEditorSheet(context),
              )
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      geometry.gutter,
                      AppGeometry.lg,
                      geometry.gutter,
                      AppGeometry.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(
                        title: 'Boards',
                        subtitle:
                            '${boards.length} board${boards.length == 1 ? '' : 's'} '
                            '· long press to reorder',
                        padding: EdgeInsets.zero,
                        trailing: AppIconButton(
                          icon: Icons.add_rounded,
                          tooltip: 'New board',
                          onPressed: () => showBoardEditorSheet(context),
                          color: context.colors.primaryText,
                          background: context.colors.primarySoft,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      geometry.gutter,
                      0,
                      geometry.gutter,
                      // Clear the floating nav bar and FAB.
                      140,
                    ),
                    sliver: _BoardGrid(boards: boards),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Reorderable grid of board tiles.
///
/// [ReorderableListView] would force a single column, so the grid is a
/// [SliverReorderableList] of rows — reordering stays available at every
/// breakpoint without a second code path.
class _BoardGrid extends ConsumerWidget {
  const _BoardGrid({required this.boards});

  final List<BoardWithStats> boards;

  int _columnsFor(BuildContext context) {
    final width = context.screenSize.width;
    if (width >= 1200) return 4;
    if (width >= 840) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = _columnsFor(context);
    final rows = (boards.length / columns).ceil();

    return SliverReorderableList(
      itemCount: rows,
      onReorder: (oldRow, newRow) {
        // Reordering operates on rows; with one column this is exact, and with
        // more it moves the row's first board, which is the intuitive result of
        // dragging a row handle.
        ref.read(boardsProvider.notifier).reorder(
              oldRow * columns,
              newRow * columns,
            );
      },
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeOut.transform(animation.value);
          return Transform.scale(
            scale: 1 + 0.03 * t,
            child: Transform.rotate(angle: 0.012 * t, child: child),
          );
        },
        child: child,
      ),
      itemBuilder: (context, rowIndex) {
        final start = rowIndex * columns;
        final end = (start + columns).clamp(0, boards.length);
        final rowItems = boards.sublist(start, end);

        return Padding(
          key: ValueKey('board-row-${rowItems.first.board.id}'),
          padding: const EdgeInsets.only(bottom: AppGeometry.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: AppGeometry.md),
                Expanded(
                  child: i < rowItems.length
                      ? ReorderableDelayedDragStartListener(
                          index: rowIndex,
                          child: StaggerReveal(
                            index: start + i,
                            child: BoardTile(
                              board: rowItems[i].board,
                              stats: rowItems[i].stats,
                            ),
                          ),
                        )
                      // Keeps the last row aligned with the ones above it.
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A board tile. Tilts towards the pointer, glows in its own colour, and opens
/// the board with a hero transition on its icon.
class BoardTile extends ConsumerWidget {
  const BoardTile({super.key, required this.board, required this.stats});

  final Board board;
  final BoardStats stats;

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppGeometry.md),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppGeometry.brXl,
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit board'),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: context.colors.danger,
                ),
                title: Text(
                  'Delete board',
                  style: TextStyle(color: context.colors.danger),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'edit') {
      await showBoardEditorSheet(context, existing: board);
    } else if (action == 'delete') {
      final confirmed = await confirmAction(
        context: context,
        title: 'Delete "${board.title}"?',
        message: stats.total == 0
            ? 'This board is empty and will be removed.'
            : 'All ${stats.total} cards on this board will be deleted too. '
                'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed) {
        await ref.read(boardsProvider.notifier).delete(board.id);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accent = board.color;

    return TiltSurface(
      glowColor: accent,
      child: Pressable(
        onTap: () => context.go(Routes.board(board.id)),
        onLongPress: () => _openMenu(context, ref),
        borderRadius: AppGeometry.brXl,
        semanticLabel: '${board.title} board, ${stats.total} cards, '
            '${(stats.completion * 100).round()} percent complete',
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(AppGeometry.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppGeometry.brXl,
            border: Border.all(color: colors.border),
            boxShadow: AppGeometry.rest(colors),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'board-icon-${board.id}',
                    child: Container(
                      width: 42,
                      height: 42,
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
                        size: 21,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (stats.isComplete)
                    AppChip(
                      label: 'Clear',
                      icon: Icons.done_all_rounded,
                      dense: true,
                      foreground: colors.success,
                      background: colors.successSoft,
                    )
                  else
                    Text(
                      '${stats.remaining} left',
                      style: context.text.labelSmall,
                    ),
                ],
              ),
              const SizedBox(height: AppGeometry.md),
              Text(
                board.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                board.description.isEmpty
                    ? '${stats.total} card${stats.total == 1 ? '' : 's'}'
                    : board.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppGeometry.lg),
              Row(
                children: [
                  Expanded(
                    child: AppProgressBar(
                      value: stats.completion,
                      color: accent,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: AppGeometry.md),
                  Text(
                    '${(stats.completion * 100).round()}%',
                    style: context.text.labelMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppGeometry.md),
              Row(
                children: [
                  _ColumnCount(
                    label: 'To Do',
                    count: stats.todo,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: AppGeometry.md),
                  _ColumnCount(
                    label: 'Started',
                    count: stats.started,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppGeometry.md),
                  _ColumnCount(
                    label: 'Done',
                    count: stats.done,
                    color: colors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnCount extends StatelessWidget {
  const _ColumnCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$count',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}
