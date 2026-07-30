import 'package:flutter/foundation.dart';

import '../core/models/board.dart';
import '../core/models/enums.dart';
import '../core/models/task_card.dart';

/// A list of cards with value equality.
///
/// Riverpod decides whether to rebuild by comparing with `==`, and two `List`s
/// with identical contents are not equal. Wrapping slices in this type means a
/// mutation somewhere else in the app does not rebuild every kanban column —
/// only the columns whose contents actually changed.
@immutable
class CardSlice {
  const CardSlice(this.items);

  static const empty = CardSlice(<TaskCard>[]);

  final List<TaskCard> items;

  int get length => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  TaskCard operator [](int i) => items[i];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardSlice && listEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(items);
}

/// Pre-computed views over the full card set.
///
/// Built once per mutation instead of being recomputed inside `build()`. With
/// a few thousand cards, one indexing pass per edit is far cheaper than every
/// column, day cell and board tile filtering the whole list on every frame.
@immutable
class CardIndex {
  CardIndex._({
    required this.all,
    required this.byId,
    required Map<String, List<TaskCard>> byBoard,
    required Map<String, List<TaskCard>> byColumn,
    required Map<String, List<TaskCard>> byDay,
    required this.boardStats,
    required this.openCount,
    required this.doneCount,
  })  : _byBoard = byBoard,
        _byColumn = byColumn,
        _byDay = byDay;

  factory CardIndex.empty() => CardIndex._(
        all: const [],
        byId: const {},
        byBoard: const {},
        byColumn: const {},
        byDay: const {},
        boardStats: const {},
        openCount: 0,
        doneCount: 0,
      );

  /// Every card, ordered by board then column position.
  final List<TaskCard> all;
  final Map<String, TaskCard> byId;

  final Map<String, List<TaskCard>> _byBoard;

  /// Keyed by `boardId|status` — the kanban columns.
  final Map<String, List<TaskCard>> _byColumn;

  /// Keyed by `yyyy-MM-dd`.
  final Map<String, List<TaskCard>> _byDay;

  final Map<String, BoardStats> boardStats;
  final int openCount;
  final int doneCount;

  static String columnKey(String boardId, TaskStatus status) =>
      '$boardId|${status.name}';

  factory CardIndex.build(List<TaskCard> cards) {
    final byId = <String, TaskCard>{};
    final byBoard = <String, List<TaskCard>>{};
    final byColumn = <String, List<TaskCard>>{};
    final byDay = <String, List<TaskCard>>{};
    final counts = <String, List<int>>{}; // boardId -> [todo, started, done]

    var open = 0;
    var done = 0;

    for (final card in cards) {
      byId[card.id] = card;
      (byBoard[card.boardId] ??= <TaskCard>[]).add(card);
      (byColumn[columnKey(card.boardId, card.status)] ??= <TaskCard>[])
          .add(card);

      final dayKey = card.scheduledDayKey;
      if (dayKey != null) (byDay[dayKey] ??= <TaskCard>[]).add(card);

      final tally = counts[card.boardId] ??= [0, 0, 0];
      tally[card.status.index]++;

      if (card.isDone) {
        done++;
      } else {
        open++;
      }
    }

    // One sort pass per bucket. Cards inside a column are user-ordered;
    // day buckets lead with unfinished, highest-priority work.
    for (final list in byColumn.values) {
      list.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    }
    for (final list in byBoard.values) {
      list.sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        return byStatus != 0 ? byStatus : a.sortIndex.compareTo(b.sortIndex);
      });
    }
    for (final list in byDay.values) {
      list.sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        final byPriority = b.priority.weight.compareTo(a.priority.weight);
        return byPriority != 0 ? byPriority : a.sortIndex.compareTo(b.sortIndex);
      });
    }

    final stats = <String, BoardStats>{
      for (final entry in counts.entries)
        entry.key: BoardStats(
          total: entry.value[0] + entry.value[1] + entry.value[2],
          todo: entry.value[0],
          started: entry.value[1],
          done: entry.value[2],
        ),
    };

    final ordered = <TaskCard>[];
    for (final list in byBoard.values) {
      ordered.addAll(list);
    }

    return CardIndex._(
      all: ordered,
      byId: byId,
      byBoard: byBoard,
      byColumn: byColumn,
      byDay: byDay,
      boardStats: stats,
      openCount: open,
      doneCount: done,
    );
  }

  TaskCard? card(String? id) => id == null ? null : byId[id];

  CardSlice forBoard(String boardId) =>
      CardSlice(_byBoard[boardId] ?? const <TaskCard>[]);

  CardSlice forColumn(String boardId, TaskStatus status) =>
      CardSlice(_byColumn[columnKey(boardId, status)] ?? const <TaskCard>[]);

  CardSlice forDay(String dayKey) =>
      CardSlice(_byDay[dayKey] ?? const <TaskCard>[]);

  BoardStats statsFor(String boardId) =>
      boardStats[boardId] ?? BoardStats.empty;

  /// Counts used by the weekly strip. Returns (total, done) for a day.
  (int, int) dayTally(String dayKey) {
    final list = _byDay[dayKey];
    if (list == null || list.isEmpty) return (0, 0);
    var done = 0;
    for (final c in list) {
      if (c.isDone) done++;
    }
    return (list.length, done);
  }

  /// Next free sort position at the end of a column.
  int nextSortIndex(String boardId, TaskStatus status) {
    final list = _byColumn[columnKey(boardId, status)];
    if (list == null || list.isEmpty) return 0;
    return list.last.sortIndex + 1;
  }

  int get boardCount => _byBoard.length;
  bool get isEmpty => byId.isEmpty;
}
