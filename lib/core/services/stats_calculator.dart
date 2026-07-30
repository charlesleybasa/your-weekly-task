import '../models/focus_session.dart';
import '../models/task_card.dart';
import '../models/user_stats.dart';
import '../utils/date_x.dart';

/// Derives weekly reports from the raw logs.
///
/// Nothing here is cached at this layer — the provider that calls it memoises
/// per week key, so a rebuild of the dashboard does not re-scan history.
abstract final class StatsCalculator {
  /// Builds the report for the ISO week containing [anchor].
  ///
  /// "Planned" counts cards *scheduled into* the week plus any card completed
  /// during it, so an unplanned task the user knocked out still counts towards
  /// the numerator without inflating the denominator twice.
  static WeeklyReport weekly({
    required DateTime anchor,
    required List<TaskCard> cards,
    required List<FocusSession> sessions,
  }) {
    final start = anchor.weekStart;
    final days = start.weekDays;
    final dayKeys = {for (var i = 0; i < 7; i++) days[i].dayKey: i};

    final perDay = List<int>.filled(7, 0);
    final perBoard = <String, int>{};
    var planned = 0;
    var completed = 0;
    var xpEarned = 0;

    for (final card in cards) {
      final scheduledIndex = dayKeys[card.scheduledDayKey];
      final completedAt = card.completedAt;
      final completedIndex =
          completedAt == null ? null : dayKeys[completedAt.dayKey];

      final belongsToWeek = scheduledIndex != null || completedIndex != null;
      if (!belongsToWeek) continue;

      planned++;

      if (card.isDone && completedIndex != null) {
        completed++;
        perDay[completedIndex]++;
        perBoard.update(card.boardId, (v) => v + 1, ifAbsent: () => 1);
        xpEarned += card.xpAwarded;
      }
    }

    var focusedSeconds = 0;
    var sessionCount = 0;
    for (final session in sessions) {
      if (!dayKeys.containsKey(session.dayKey)) continue;
      focusedSeconds += session.actualSeconds;
      sessionCount++;
    }

    String? topBoardId;
    var topBoardCount = 0;
    perBoard.forEach((id, count) {
      if (count > topBoardCount) {
        topBoardCount = count;
        topBoardId = id;
      }
    });

    var bestIndex = -1;
    for (var i = 0; i < 7; i++) {
      if (perDay[i] > 0 && (bestIndex == -1 || perDay[i] > perDay[bestIndex])) {
        bestIndex = i;
      }
    }

    return WeeklyReport(
      weekStart: start,
      completed: completed,
      planned: planned,
      focusedSeconds: focusedSeconds,
      sessionCount: sessionCount,
      xpEarned: xpEarned,
      perDayCompleted: perDay,
      topBoardId: topBoardId,
      topBoardCount: topBoardCount,
      bestDay: bestIndex == -1 ? null : days[bestIndex],
    );
  }

  /// Total focused seconds logged on [day].
  static int focusedSecondsOn(DateTime day, List<FocusSession> sessions) {
    final key = day.dayKey;
    var total = 0;
    for (final s in sessions) {
      if (s.dayKey == key) total += s.actualSeconds;
    }
    return total;
  }

  /// Advances the daily streak for a completion happening now.
  ///
  /// Same day → unchanged. Yesterday → +1. Anything older (or a first ever
  /// completion) → restart at 1.
  static ({int current, int longest}) advanceStreak(
    UserStats stats,
    DateTime now,
  ) {
    final today = now.dayStart;
    final last = DateX.tryParseDayKey(stats.lastCompletionDayKey);

    if (last == null) return (current: 1, longest: _max(stats.longestStreak, 1));
    if (last.isSameDay(today)) {
      return (
        current: stats.currentStreak == 0 ? 1 : stats.currentStreak,
        longest: _max(stats.longestStreak, _max(stats.currentStreak, 1)),
      );
    }

    final gap = last.daysUntil(today);
    final next = gap == 1 ? stats.currentStreak + 1 : 1;
    return (current: next, longest: _max(stats.longestStreak, next));
  }

  static int _max(int a, int b) => a > b ? a : b;

  /// Cards the user has finished, newest first.
  static List<TaskCard> recentlyCompleted(List<TaskCard> cards, {int take = 5}) {
    final done = cards.where((c) => c.isDone && c.completedAt != null).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return done.length <= take ? done : done.sublist(0, take);
  }

  /// The next things worth doing, ranked by [TaskCard.focusRank].
  static List<TaskCard> upcoming(List<TaskCard> cards, {int take = 5}) {
    final open = cards.where((c) => !c.isDone).toList()
      ..sort((a, b) {
        final rank = b.focusRank.compareTo(a.focusRank);
        return rank != 0 ? rank : a.sortIndex.compareTo(b.sortIndex);
      });
    return open.length <= take ? open : open.sublist(0, take);
  }
}
