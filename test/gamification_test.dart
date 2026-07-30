import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/core/models/enums.dart';
import 'package:momentum/core/models/task_card.dart';
import 'package:momentum/core/models/user_stats.dart';
import 'package:momentum/core/services/stats_calculator.dart';
import 'package:momentum/core/services/xp_service.dart';
import 'package:momentum/core/utils/date_x.dart';

TaskCard _card({
  String id = 'c1',
  int minutes = 25,
  TaskStatus status = TaskStatus.todo,
}) {
  final now = DateTime(2026, 7, 30, 10);
  return TaskCard(
    id: id,
    boardId: 'b1',
    title: 'Test task',
    status: status,
    priority: Priority.medium,
    estimatedMinutes: minutes,
    sortIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Levels', () {
    test('level 1 starts at zero XP', () {
      expect(Levels.levelForXp(0), 1);
      expect(Levels.xpToReach(1), 0);
    });

    test('the curve is strictly increasing', () {
      for (var level = 1; level < 40; level++) {
        expect(
          Levels.xpToReach(level + 1),
          greaterThan(Levels.xpToReach(level)),
          reason: 'level $level threshold must be below level ${level + 1}',
        );
      }
    });

    test('levelForXp is the inverse of xpToReach at every boundary', () {
      for (var level = 1; level < 40; level++) {
        final threshold = Levels.xpToReach(level);
        expect(Levels.levelForXp(threshold), level);
        // One XP short of the threshold must still be the previous level.
        if (level > 1) {
          expect(Levels.levelForXp(threshold - 1), level - 1);
        }
      }
    });

    test('progress within a level stays in range and resets at boundaries', () {
      expect(Levels.progressWithinLevel(0), 0);
      final level3 = Levels.xpToReach(3);
      expect(Levels.progressWithinLevel(level3), 0);
      final midway = level3 + Levels.xpNeededForNextLevel(level3) ~/ 2;
      expect(Levels.progressWithinLevel(midway), closeTo(0.5, 0.02));
    });

    test('titles come from the highest tier reached', () {
      expect(Levels.titleForLevel(1), 'Beginner');
      expect(Levels.titleForLevel(4), 'Beginner');
      expect(Levels.titleForLevel(5), 'Builder');
      expect(Levels.titleForLevel(12), 'Creator');
      expect(Levels.titleForLevel(30), 'Legend');
      expect(Levels.titleForLevel(99), 'Legend');
    });
  });

  group('XpService', () {
    test('base reward follows the estimate bucket', () {
      expect(XpService.forCompletion(_card(minutes: 15)).total, 20);
      expect(XpService.forCompletion(_card(minutes: 45)).total, 50);
      expect(XpService.forCompletion(_card(minutes: 90)).total, 100);
    });

    test('bonuses are additive and itemised', () {
      final breakdown = XpService.forCompletion(
        _card(minutes: 45),
        viaTimer: true,
        perfectFocus: true,
        isFirstToday: true,
      );
      expect(
        breakdown.total,
        50 +
            XpService.timerBonus +
            XpService.perfectFocusBonus +
            XpService.firstOfDayBonus,
      );
      // Every component is shown to the user, not just the sum.
      expect(breakdown.lines, hasLength(4));
    });

    test('streak bonus starts at two days and is capped', () {
      expect(XpService.forCompletion(_card(), streakDays: 1).lines, hasLength(1));

      final long = XpService.forCompletion(_card(), streakDays: 100);
      final streakLine = long.lines.last;
      expect(streakLine.amount, XpService.streakBonusCap);
    });
  });

  group('StatsCalculator.advanceStreak', () {
    final now = DateTime(2026, 7, 30, 9);

    test('a first ever completion starts the streak at one', () {
      final result = StatsCalculator.advanceStreak(UserStats.empty, now);
      expect(result.current, 1);
      expect(result.longest, 1);
    });

    test('a second completion on the same day does not increment', () {
      final stats = UserStats(
        currentStreak: 3,
        longestStreak: 5,
        lastCompletionDayKey: now.dayKey,
      );
      final result = StatsCalculator.advanceStreak(stats, now);
      expect(result.current, 3);
      expect(result.longest, 5);
    });

    test('a completion the next day increments', () {
      final stats = UserStats(
        currentStreak: 3,
        longestStreak: 3,
        lastCompletionDayKey:
            now.subtract(const Duration(days: 1)).dayKey,
      );
      final result = StatsCalculator.advanceStreak(stats, now);
      expect(result.current, 4);
      expect(result.longest, 4);
    });

    test('a gap resets to one but preserves the record', () {
      final stats = UserStats(
        currentStreak: 9,
        longestStreak: 9,
        lastCompletionDayKey:
            now.subtract(const Duration(days: 3)).dayKey,
      );
      final result = StatsCalculator.advanceStreak(stats, now);
      expect(result.current, 1);
      expect(result.longest, 9);
    });
  });

  group('UserStats.displayStreak', () {
    test('shows zero once the streak has lapsed', () {
      final lapsed = UserStats(
        currentStreak: 6,
        lastCompletionDayKey:
            DateTime.now().subtract(const Duration(days: 4)).dayKey,
      );
      expect(lapsed.currentStreak, 6);
      expect(lapsed.displayStreak, 0, reason: 'a dead streak must not look alive');
    });

    test('stays alive on the day after the last completion', () {
      final alive = UserStats(
        currentStreak: 6,
        lastCompletionDayKey:
            DateTime.now().subtract(const Duration(days: 1)).dayKey,
      );
      expect(alive.displayStreak, 6);
    });
  });

  group('WeeklyReport', () {
    test('an empty week reports zero completion, not one', () {
      final report = StatsCalculator.weekly(
        anchor: DateTime(2026, 7, 30),
        cards: const [],
        sessions: const [],
      );
      expect(report.completionRate, 0);
      expect(report.isPerfectWeek, isFalse);
    });

    test('counts only cards that belong to the anchored week', () {
      final thisWeek = DateTime(2026, 7, 30);
      final lastWeek = thisWeek.subtract(const Duration(days: 7));

      final cards = [
        _card(id: 'a').copyWith(scheduledDayKey: thisWeek.dayKey),
        _card(id: 'b').copyWith(scheduledDayKey: lastWeek.dayKey),
      ];

      final report = StatsCalculator.weekly(
        anchor: thisWeek,
        cards: cards,
        sessions: const [],
      );
      expect(report.planned, 1);
    });
  });
}
