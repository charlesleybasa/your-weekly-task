import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/board.dart';
import '../core/models/enums.dart';
import '../core/services/id_service.dart';
import '../core/services/sound_service.dart';
import '../core/theme/app_palette.dart';
import 'app_providers.dart';
import 'cards_controller.dart';

class BoardsController extends Notifier<List<Board>> {
  @override
  List<Board> build() => ref.read(boardRepositoryProvider).loadAll();

  Board? byId(String? id) {
    if (id == null) return null;
    for (final b in state) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<Board> create({
    required String title,
    String description = '',
    required int colorValue,
    required String iconKey,
  }) async {
    final now = DateTime.now();
    final board = Board(
      id: Ids.next(),
      title: title.trim().isEmpty ? 'Untitled board' : title.trim(),
      description: description.trim(),
      colorValue: colorValue,
      iconKey: iconKey,
      sortIndex: state.isEmpty ? 0 : state.last.sortIndex + 1,
      createdAt: now,
      updatedAt: now,
    );

    state = [...state, board];
    await ref.read(boardRepositoryProvider).upsert(board);

    ref.read(soundServiceProvider).play(Sfx.boardCreated);
    return board;
  }

  Future<void> update(Board board) async {
    final next = board.copyWith(updatedAt: DateTime.now());
    state = [
      for (final b in state)
        if (b.id == next.id) next else b,
    ];
    await ref.read(boardRepositoryProvider).upsert(next);
  }

  /// Removes the board and every card on it. Cards are deleted through the
  /// card controller so the index and the database stay in step.
  Future<void> delete(String boardId) async {
    state = state.where((b) => b.id != boardId).toList();
    await ref.read(boardRepositoryProvider).delete(boardId);
    await ref.read(cardsProvider.notifier).deleteForBoard(boardId);
  }

  /// Drag-to-reorder on the boards grid. Rewrites every sort index so the list
  /// cannot drift into ties after repeated moves.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final list = [...state];
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(target.clamp(0, list.length), moved);

    final renumbered = <Board>[
      for (var i = 0; i < list.length; i++)
        if (list[i].sortIndex == i) list[i] else list[i].copyWith(sortIndex: i),
    ];

    state = renumbered;
    await ref.read(boardRepositoryProvider).upsertAll(renumbered);
  }
}

final boardsProvider =
    NotifierProvider<BoardsController, List<Board>>(BoardsController.new);

/// A single board by id. Rebuilds only when that board changes.
final boardProvider = Provider.family<Board?, String>((ref, id) {
  final boards = ref.watch(boardsProvider);
  for (final b in boards) {
    if (b.id == id) return b;
  }
  return null;
});

/// Board plus its live counters — what the boards grid renders.
typedef BoardWithStats = ({Board board, BoardStats stats});

final boardsWithStatsProvider = Provider<List<BoardWithStats>>((ref) {
  final boards = ref.watch(boardsProvider);
  final index = ref.watch(cardsProvider);
  return [
    for (final board in boards)
      (board: board, stats: index.statsFor(board.id)),
  ];
});

/// Default accent/icon for a new board, cycled so consecutive boards do not
/// all come out the same colour.
({int color, String iconKey}) suggestBoardStyle(int existingCount) {
  final colors = Brand.boardAccentValues;
  final icons = BoardIcons.options.keys.toList();
  return (
    color: colors[existingCount % colors.length],
    iconKey: icons[existingCount % icons.length],
  );
}
