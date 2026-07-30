import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../utils/date_x.dart';

/// A level tier with its title. Levels between named tiers inherit the title of
/// the highest tier they have passed.
@immutable
class LevelTier {
  const LevelTier(this.level, this.title);

  final int level;
  final String title;
}

/// XP → level mapping.
///
/// The curve is quadratic (`120n + 30n²`) so early levels arrive quickly enough
/// to teach the mechanic, while later ones need genuine weekly consistency.
abstract final class Levels {
  static const tiers = <LevelTier>[
    LevelTier(1, 'Beginner'),
    LevelTier(5, 'Builder'),
    LevelTier(10, 'Creator'),
    LevelTier(20, 'Master'),
    LevelTier(30, 'Legend'),
  ];

  static const int maxLevel = 99;

  /// Cumulative XP required to *reach* [level]. Level 1 starts at 0.
  static int xpToReach(int level) {
    if (level <= 1) return 0;
    final n = level - 1;
    return 120 * n + 30 * n * n;
  }

  static int levelForXp(int xp) {
    if (xp <= 0) return 1;
    var level = 1;
    while (level < maxLevel && xp >= xpToReach(level + 1)) {
      level++;
    }
    return level;
  }

  static String titleForLevel(int level) {
    var title = tiers.first.title;
    for (final tier in tiers) {
      if (level >= tier.level) title = tier.title;
    }
    return title;
  }

  /// Progress through the current level, 0.0–1.0.
  static double progressWithinLevel(int xp) {
    final level = levelForXp(xp);
    if (level >= maxLevel) return 1;
    final floor = xpToReach(level);
    final ceiling = xpToReach(level + 1);
    if (ceiling <= floor) return 1;
    return ((xp - floor) / (ceiling - floor)).clamp(0.0, 1.0);
  }

  static int xpIntoLevel(int xp) => xp - xpToReach(levelForXp(xp));

  static int xpNeededForNextLevel(int xp) {
    final level = levelForXp(xp);
    if (level >= maxLevel) return 0;
    return xpToReach(level + 1) - xpToReach(level);
  }

  static int xpRemainingToNextLevel(int xp) =>
      math.max(0, xpToReach(levelForXp(xp) + 1) - xp);
}

/// Persistent player state.
///
/// Only values that cannot be recomputed from the card/session logs live here.
/// Anything derivable (hours focused, completion %, most productive board) is
/// calculated on demand so an edit to history stays consistent.
@immutable
class UserStats {
  const UserStats({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.weeklyStreak = 0,
    this.lastCompletionDayKey,
    this.lastCelebratedWeekKey,
    this.unlockedAchievements = const <String, DateTime>{},
    this.tasksCompleted = 0,
    this.timersCompleted = 0,
  });

  final int totalXp;

  /// Consecutive days with at least one completed task.
  final int currentStreak;
  final int longestStreak;

  /// Consecutive ISO weeks in which every scheduled task was finished.
  final int weeklyStreak;

  final String? lastCompletionDayKey;

  /// Guards the "finished the whole week" celebration from firing twice.
  final String? lastCelebratedWeekKey;

  /// Achievement id → unlock time.
  final Map<String, DateTime> unlockedAchievements;

  final int tasksCompleted;
  final int timersCompleted;

  static const empty = UserStats();

  int get level => Levels.levelForXp(totalXp);
  String get levelTitle => Levels.titleForLevel(level);
  double get levelProgress => Levels.progressWithinLevel(totalXp);
  int get xpIntoLevel => Levels.xpIntoLevel(totalXp);
  int get xpForThisLevel => Levels.xpNeededForNextLevel(totalXp);

  bool hasAchievement(String id) => unlockedAchievements.containsKey(id);

  /// True when the streak is still alive today (completed today, or completed
  /// yesterday and today is not over yet).
  bool get streakIsLive {
    final last = DateX.tryParseDayKey(lastCompletionDayKey);
    if (last == null) return false;
    final delta = last.daysUntil(DateTime.now().dayStart);
    return delta <= 1;
  }

  /// The streak as it should be *displayed* — a streak that already lapsed
  /// shows 0 rather than a stale number until the next completion resets it.
  int get displayStreak => streakIsLive ? currentStreak : 0;

  UserStats copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    int? weeklyStreak,
    Object? lastCompletionDayKey = _sentinel,
    Object? lastCelebratedWeekKey = _sentinel,
    Map<String, DateTime>? unlockedAchievements,
    int? tasksCompleted,
    int? timersCompleted,
  }) {
    return UserStats(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      lastCompletionDayKey: lastCompletionDayKey == _sentinel
          ? this.lastCompletionDayKey
          : lastCompletionDayKey as String?,
      lastCelebratedWeekKey: lastCelebratedWeekKey == _sentinel
          ? this.lastCelebratedWeekKey
          : lastCelebratedWeekKey as String?,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      timersCompleted: timersCompleted ?? this.timersCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'weeklyStreak': weeklyStreak,
        'lastCompletionDayKey': lastCompletionDayKey,
        'lastCelebratedWeekKey': lastCelebratedWeekKey,
        'unlockedAchievements': unlockedAchievements
            .map((k, v) => MapEntry(k, v.toIso8601String())),
        'tasksCompleted': tasksCompleted,
        'timersCompleted': timersCompleted,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final raw = (json['unlockedAchievements'] as Map?) ?? const {};
    return UserStats(
      totalXp: json['totalXp'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      weeklyStreak: json['weeklyStreak'] as int? ?? 0,
      lastCompletionDayKey: json['lastCompletionDayKey'] as String?,
      lastCelebratedWeekKey: json['lastCelebratedWeekKey'] as String?,
      unlockedAchievements: {
        for (final entry in raw.entries)
          entry.key.toString():
              DateTime.tryParse(entry.value.toString()) ?? DateTime.now(),
      },
      tasksCompleted: json['tasksCompleted'] as int? ?? 0,
      timersCompleted: json['timersCompleted'] as int? ?? 0,
    );
  }
}

/// Aggregated numbers for one ISO week, recomputed from the logs.
@immutable
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.completed,
    required this.planned,
    required this.focusedSeconds,
    required this.sessionCount,
    required this.xpEarned,
    required this.perDayCompleted,
    required this.topBoardId,
    required this.topBoardCount,
    required this.bestDay,
  });

  final DateTime weekStart;
  final int completed;

  /// Cards scheduled into this week (the denominator for weekly progress).
  final int planned;

  final int focusedSeconds;
  final int sessionCount;
  final int xpEarned;

  /// Seven entries, Monday first.
  final List<int> perDayCompleted;

  final String? topBoardId;
  final int topBoardCount;
  final DateTime? bestDay;

  static WeeklyReport emptyFor(DateTime weekStart) => WeeklyReport(
        weekStart: weekStart,
        completed: 0,
        planned: 0,
        focusedSeconds: 0,
        sessionCount: 0,
        xpEarned: 0,
        perDayCompleted: const [0, 0, 0, 0, 0, 0, 0],
        topBoardId: null,
        topBoardCount: 0,
        bestDay: null,
      );

  double get completionRate => planned == 0 ? 0 : (completed / planned).clamp(0.0, 1.0);
  int get remaining => math.max(0, planned - completed);
  Duration get focused => Duration(seconds: focusedSeconds);

  Duration get averageSession => sessionCount == 0
      ? Duration.zero
      : Duration(seconds: focusedSeconds ~/ sessionCount);

  bool get isPerfectWeek => planned > 0 && completed >= planned;
}

const Object _sentinel = Object();
