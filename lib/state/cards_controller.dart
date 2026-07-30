import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/enums.dart';
import '../core/models/task_card.dart';
import '../core/services/haptic_service.dart';
import '../core/services/id_service.dart';
import '../core/services/sound_service.dart';
import '../core/services/stats_calculator.dart';
import '../core/utils/date_x.dart';
import 'app_providers.dart';
import 'card_index.dart';

/// Owns every card in the app.
///
/// State is the pre-computed [CardIndex] rather than a raw list: mutations pay
/// one indexing pass, and every screen then reads its slice in O(1).
class CardsController extends Notifier<CardIndex> {
  @override
  CardIndex build() => CardIndex.build(ref.read(cardRepositoryProvider).loadAll());

  SoundService get _sound => ref.read(soundServiceProvider);
  HapticService get _haptics => ref.read(hapticServiceProvider);

  void _rebuild(List<TaskCard> cards) => state = CardIndex.build(cards);

  List<TaskCard> get _all => state.all;

  Future<TaskCard> create({
    required String boardId,
    required String title,
    String description = '',
    Priority priority = Priority.medium,
    int estimatedMinutes = 25,
    DateTime? scheduledDay,
    TaskStatus status = TaskStatus.todo,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final card = TaskCard(
      id: Ids.next(),
      boardId: boardId,
      title: title.trim().isEmpty ? 'Untitled task' : title.trim(),
      description: description.trim(),
      status: status,
      priority: priority,
      estimatedMinutes: estimatedMinutes.clamp(1, 480),
      sortIndex: state.nextSortIndex(boardId, status),
      scheduledDayKey: scheduledDay?.dayKey,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    _rebuild([..._all, card]);
    await ref.read(cardRepositoryProvider).upsert(card);

    _sound.play(Sfx.taskCreated);
    _haptics.light();
    return card;
  }

  Future<void> update(TaskCard card) async {
    final next = card.copyWith(updatedAt: DateTime.now());
    _rebuild([
      for (final c in _all)
        if (c.id == next.id) next else c,
    ]);
    await ref.read(cardRepositoryProvider).upsert(next);
  }

  Future<void> delete(String cardId) async {
    _rebuild(_all.where((c) => c.id != cardId).toList());
    await ref.read(cardRepositoryProvider).delete(cardId);
    _haptics.light();
  }

  Future<void> deleteForBoard(String boardId) async {
    final doomed = _all.where((c) => c.boardId == boardId).map((c) => c.id);
    if (doomed.isEmpty) return;
    final ids = doomed.toSet();
    _rebuild(_all.where((c) => !ids.contains(c.id)).toList());
    await ref.read(cardRepositoryProvider).deleteAll(ids);
  }

  /// Moves a card between columns and/or to a new position.
  ///
  /// Completion is deliberately *not* handled here — moving to Done runs
  /// through the gamification controller so XP, streaks and achievements can
  /// never be bypassed by a drag.
  Future<void> move({
    required String cardId,
    required TaskStatus toStatus,
    int? toIndex,
    String? toBoardId,
  }) async {
    final card = state.byId[cardId];
    if (card == null) return;

    if (toStatus == TaskStatus.done && card.isDone) return;

    final boardId = toBoardId ?? card.boardId;
    final unchanged = card.status == toStatus &&
        boardId == card.boardId &&
        (toIndex == null || toIndex == card.sortIndex);
    if (unchanged) return;

    // Target column without the moving card, so the insert index is honest.
    final column = state
        .forColumn(boardId, toStatus)
        .items
        .where((c) => c.id != cardId)
        .toList();

    final insertAt = (toIndex ?? column.length).clamp(0, column.length);
    final moved = card
        .copyWith(boardId: boardId)
        .withStatus(toStatus)
        .copyWith(sortIndex: insertAt);
    column.insert(insertAt, moved);

    // Renumber the destination column densely; ties would make future drops
    // land unpredictably.
    final touched = <TaskCard>[];
    for (var i = 0; i < column.length; i++) {
      final c = column[i];
      touched.add(c.sortIndex == i ? c : c.copyWith(sortIndex: i));
    }

    final byId = {for (final c in touched) c.id: c};
    _rebuild([
      for (final c in _all)
        if (byId.containsKey(c.id)) byId[c.id]! else c,
    ]);

    await ref.read(cardRepositoryProvider).upsertAll(touched);

    _haptics.medium();
    if (toStatus == TaskStatus.started && card.status != TaskStatus.started) {
      _sound.play(Sfx.taskStarted);
    } else {
      _sound.play(Sfx.drop);
    }
  }

  /// Reorder within the column a card already occupies.
  Future<void> reorderWithinColumn({
    required String boardId,
    required TaskStatus status,
    required int oldIndex,
    required int newIndex,
  }) async {
    final column = [...state.forColumn(boardId, status).items];
    if (oldIndex < 0 || oldIndex >= column.length) return;

    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, column.length - 1);
    if (target == oldIndex) return;

    final moved = column.removeAt(oldIndex);
    column.insert(target, moved);

    final touched = <TaskCard>[];
    for (var i = 0; i < column.length; i++) {
      final c = column[i];
      if (c.sortIndex != i) touched.add(c.copyWith(sortIndex: i));
    }
    if (touched.isEmpty) return;

    final byId = {for (final c in touched) c.id: c};
    _rebuild([
      for (final c in _all)
        if (byId.containsKey(c.id)) byId[c.id]! else c,
    ]);
    await ref.read(cardRepositoryProvider).upsertAll(touched);
    _haptics.selection();
  }

  Future<void> schedule(String cardId, DateTime? day) async {
    final card = state.byId[cardId];
    if (card == null) return;
    await update(card.copyWith(scheduledDayKey: day?.dayKey));
  }

  Future<void> toggleChecklistItem(String cardId, String itemId) async {
    final card = state.byId[cardId];
    if (card == null) return;
    final next = [
      for (final item in card.checklist)
        if (item.id == itemId) item.copyWith(done: !item.done) else item,
    ];
    _haptics.light();
    _sound.play(Sfx.tap, volume: 0.6);
    await update(card.copyWith(checklist: next));
  }

  /// Adds focused time to a card after a session ends.
  Future<void> logFocus(String cardId, int seconds, {bool completed = false}) async {
    final card = state.byId[cardId];
    if (card == null || seconds <= 0) return;
    await update(
      card.copyWith(
        focusedSeconds: card.focusedSeconds + seconds,
        completedSessions:
            completed ? card.completedSessions + 1 : card.completedSessions,
      ),
    );
  }

  /// Re-opens a finished card. XP already granted is intentionally kept on the
  /// record so completing it again cannot re-award the same reward.
  Future<void> reopen(String cardId) async {
    final card = state.byId[cardId];
    if (card == null || !card.isDone) return;
    await move(cardId: cardId, toStatus: TaskStatus.todo);
  }
}

final cardsProvider =
    NotifierProvider<CardsController, CardIndex>(CardsController.new);

// ---------------------------------------------------------------------------
// Derived views. Each one selects a value-equal slice, so a change in one
// column does not rebuild the others.
// ---------------------------------------------------------------------------

final cardProvider = Provider.family<TaskCard?, String>(
  (ref, id) => ref.watch(cardsProvider.select((index) => index.byId[id])),
);

typedef ColumnRef = ({String boardId, TaskStatus status});

final columnCardsProvider = Provider.family<CardSlice, ColumnRef>(
  (ref, key) => ref.watch(
    cardsProvider.select((index) => index.forColumn(key.boardId, key.status)),
  ),
);

/// Cards scheduled on a given day, keyed by `yyyy-MM-dd`.
final dayCardsProvider = Provider.family<CardSlice, String>(
  (ref, dayKey) =>
      ref.watch(cardsProvider.select((index) => index.forDay(dayKey))),
);

final dayTallyProvider = Provider.family<(int, int), String>(
  (ref, dayKey) => ref.watch(cardsProvider.select((i) => i.dayTally(dayKey))),
);

/// The five most recently finished cards, for the dashboard activity list.
final recentlyCompletedProvider = Provider<CardSlice>(
  (ref) => ref.watch(
    cardsProvider.select(
      (index) => CardSlice(StatsCalculator.recentlyCompleted(index.all)),
    ),
  ),
);

/// Ranked "what's next" list.
final upcomingCardsProvider = Provider<CardSlice>(
  (ref) => ref.watch(
    cardsProvider.select(
      (index) => CardSlice(StatsCalculator.upcoming(index.all)),
    ),
  ),
);

/// The single best next task — powers the focus screen's suggestion.
final suggestedTaskProvider = Provider<TaskCard?>((ref) {
  final upcoming = ref.watch(upcomingCardsProvider);
  return upcoming.isEmpty ? null : upcoming[0];
});

/// Today's open + total counts for the dashboard mission line.
final todaySummaryProvider = Provider<({int open, int total, int done})>((ref) {
  final key = DateTime.now().dayKey;
  final slice = ref.watch(dayCardsProvider(key));
  var done = 0;
  for (final c in slice.items) {
    if (c.isDone) done++;
  }
  return (open: slice.length - done, total: slice.length, done: done);
});
