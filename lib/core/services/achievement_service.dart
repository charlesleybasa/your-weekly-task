import 'package:flutter/foundation.dart';

import '../models/achievement.dart';
import '../models/board.dart';
import '../models/focus_session.dart';
import '../models/task_card.dart';
import '../models/user_stats.dart';
import '../utils/date_x.dart';
import 'stats_calculator.dart';

/// Everything the achievement rules need to evaluate, gathered once.
@immutable
class AchievementContext {
  const AchievementContext({
    required this.stats,
    required this.cards,
    required this.sessions,
    required this.boards,
    required this.now,
    this.justCompletedCard,
    this.justFinishedSession,
    this.perfectFocus = false,
  });

  final UserStats stats;
  final List<TaskCard> cards;
  final List<FocusSession> sessions;
  final List<Board> boards;
  final DateTime now;

  final TaskCard? justCompletedCard;
  final FocusSession? justFinishedSession;
  final bool perfectFocus;
}

/// Evaluates the achievement catalogue against the current state.
///
/// Rules are pure predicates: the caller decides what to do with the unlocks,
/// which keeps celebration UI out of the domain layer and makes each rule
/// trivially testable.
abstract final class AchievementService {
  static final Map<String, bool Function(AchievementContext)> _rules = {
    Achievements.firstTask.id: (c) => c.stats.tasksCompleted >= 1,
    Achievements.tenTasks.id: (c) => c.stats.tasksCompleted >= 10,
    Achievements.fiftyTasks.id: (c) => c.stats.tasksCompleted >= 50,
    Achievements.streak7.id: (c) => c.stats.currentStreak >= 7,
    Achievements.level10.id: (c) => c.stats.level >= 10,

    Achievements.perfectFocus.id: (c) => c.perfectFocus,

    Achievements.earlyBird.id: (c) =>
        c.justCompletedCard != null && c.now.hour < 7,

    Achievements.nightOwl.id: (c) =>
        c.justCompletedCard != null && c.now.hour >= 22,

    Achievements.deepWork.id: (c) =>
        StatsCalculator.focusedSecondsOn(c.now, c.sessions) >= 2 * 60 * 60,

    // Only counts a board the user actually filled — a board with one card
    // cleared should not read as a sweep.
    Achievements.boardMaster.id: (c) {
      final card = c.justCompletedCard;
      if (card == null) return false;
      final siblings = c.cards.where((x) => x.boardId == card.boardId).toList();
      return siblings.length >= 3 && siblings.every((x) => x.isDone);
    },

    Achievements.perfectWeek.id: (c) {
      final report = StatsCalculator.weekly(
        anchor: c.now,
        cards: c.cards,
        sessions: c.sessions,
      );
      return report.planned >= 3 && report.isPerfectWeek;
    },
  };

  /// Returns the achievements that have just become true and were not already
  /// unlocked. Order follows the catalogue so multiple unlocks celebrate in a
  /// predictable sequence.
  static List<Achievement> evaluate(AchievementContext context) {
    final unlocked = <Achievement>[];
    for (final achievement in Achievements.all) {
      if (context.stats.hasAchievement(achievement.id)) continue;
      final rule = _rules[achievement.id];
      if (rule == null) continue;
      if (rule(context)) unlocked.add(achievement);
    }
    return unlocked;
  }

  /// Progress towards a locked achievement, 0.0–1.0, for the badge grid.
  /// Returns null for rules that are momentary rather than cumulative
  /// (Early Bird, Night Owl, Perfect Focus) — a progress bar would be
  /// meaningless for those.
  static double? progress(String id, AchievementContext context) {
    final stats = context.stats;
    return switch (id) {
      'first_task' => (stats.tasksCompleted / 1).clamp(0.0, 1.0),
      'ten_tasks' => (stats.tasksCompleted / 10).clamp(0.0, 1.0),
      'fifty_tasks' => (stats.tasksCompleted / 50).clamp(0.0, 1.0),
      'streak_7' => (stats.currentStreak / 7).clamp(0.0, 1.0),
      'level_10' => (stats.level / 10).clamp(0.0, 1.0),
      'deep_work' => (StatsCalculator.focusedSecondsOn(
            context.now,
            context.sessions,
          ) /
              (2 * 60 * 60))
          .clamp(0.0, 1.0),
      'perfect_week' => StatsCalculator.weekly(
          anchor: context.now,
          cards: context.cards,
          sessions: context.sessions,
        ).completionRate,
      _ => null,
    };
  }

  /// Human label for how far along a locked achievement is.
  static String? progressLabel(String id, AchievementContext context) {
    final stats = context.stats;
    return switch (id) {
      'ten_tasks' => '${stats.tasksCompleted}/10 tasks',
      'fifty_tasks' => '${stats.tasksCompleted}/50 tasks',
      'streak_7' => '${stats.currentStreak}/7 days',
      'level_10' => 'Level ${stats.level}/10',
      'deep_work' =>
        '${Duration(seconds: StatsCalculator.focusedSecondsOn(context.now, context.sessions)).compact} / 2h today',
      _ => null,
    };
  }
}
