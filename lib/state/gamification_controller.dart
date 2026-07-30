import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/achievement.dart';
import '../core/models/enums.dart';
import '../core/models/user_stats.dart';
import '../core/services/achievement_service.dart';
import '../core/services/haptic_service.dart';
import '../core/services/sound_service.dart';
import '../core/services/stats_calculator.dart';
import '../core/services/xp_service.dart';
import '../core/utils/date_x.dart';
import 'app_providers.dart';
import 'boards_controller.dart';
import 'cards_controller.dart';
import 'celebration_controller.dart';
import 'sessions_controller.dart';

/// Owns progression: XP, levels, streaks and achievements.
///
/// Task completion funnels through [completeTask] rather than through the card
/// controller, so there is exactly one place where a reward can be granted.
class GamificationController extends Notifier<UserStats> {
  @override
  UserStats build() => ref.read(statsRepositoryProvider).loadStats();

  SoundService get _sound => ref.read(soundServiceProvider);
  HapticService get _haptics => ref.read(hapticServiceProvider);

  Future<void> _persist(UserStats next) async {
    state = next;
    await ref.read(statsRepositoryProvider).saveStats(next);
  }

  /// Marks a card done and awards everything that follows from it.
  ///
  /// Returns the XP breakdown so the caller can show it inline; the same
  /// information is also pushed onto the celebration queue.
  Future<XpBreakdown> completeTask(
    String cardId, {
    bool viaTimer = false,
    bool perfectFocus = false,
  }) async {
    final cards = ref.read(cardsProvider.notifier);
    final card = ref.read(cardsProvider).byId[cardId];
    if (card == null || card.isDone) return XpBreakdown.zero;

    final now = DateTime.now();
    final isFirstToday = state.lastCompletionDayKey != now.dayKey;
    final streak = StatsCalculator.advanceStreak(state, now);

    // Guard against a partially-initialized or stale card snapshot during
    // rapid UI interactions. Completing an already-closed task should be a no-op.
    if (card.status == TaskStatus.done || card.isDone) return XpBreakdown.zero;

    final breakdown = XpService.forCompletion(
      card,
      viaTimer: viaTimer,
      perfectFocus: perfectFocus,
      isFirstToday: isFirstToday,
      streakDays: streak.current,
    );

    // Move the card first so achievement rules see the completed state.
    await cards.move(cardId: cardId, toStatus: TaskStatus.done);
    final completed = ref.read(cardsProvider).byId[cardId];
    if (completed != null) {
      await cards.update(completed.copyWith(xpAwarded: breakdown.total));
    }

    final levelBefore = state.level;
    var next = state.copyWith(
      totalXp: state.totalXp + breakdown.total,
      tasksCompleted: state.tasksCompleted + 1,
      currentStreak: streak.current,
      longestStreak: streak.longest,
      lastCompletionDayKey: now.dayKey,
      timersCompleted:
          viaTimer ? state.timersCompleted + 1 : state.timersCompleted,
    );

    final celebrations = <Celebration>[
      XpAwarded(
        breakdown: breakdown,
        taskTitle: card.title,
        totalXpAfter: next.totalXp,
      ),
    ];

    if (next.level > levelBefore) {
      celebrations.add(LevelUp(level: next.level, title: next.levelTitle));
    }

    // Achievements are evaluated against post-completion state.
    final unlockContext = AchievementContext(
      stats: next,
      cards: ref.read(cardsProvider).all,
      sessions: ref.read(sessionsProvider),
      boards: ref.read(boardsProvider),
      now: now,
      justCompletedCard: completed ?? card,
      perfectFocus: perfectFocus,
    );

    final unlocked = AchievementService.evaluate(unlockContext);
    if (unlocked.isNotEmpty) {
      final map = Map<String, DateTime>.from(next.unlockedAchievements);
      var bonusXp = 0;
      for (final achievement in unlocked) {
        map[achievement.id] = now;
        bonusXp += achievement.xpBonus;
        celebrations.add(AchievementUnlocked(achievement));
      }
      next = next.copyWith(
        unlockedAchievements: map,
        totalXp: next.totalXp + bonusXp,
      );

      // A bonus can itself push the player over a level boundary.
      if (next.level > levelBefore &&
          !celebrations.any((c) => c is LevelUp)) {
        celebrations.add(LevelUp(level: next.level, title: next.levelTitle));
      }
    }

    // Weekly goal — awarded once per ISO week.
    final report = StatsCalculator.weekly(
      anchor: now,
      cards: ref.read(cardsProvider).all,
      sessions: ref.read(sessionsProvider),
    );
    if (report.isPerfectWeek &&
        report.planned >= 3 &&
        next.lastCelebratedWeekKey != now.weekKey) {
      next = next.copyWith(
        totalXp: next.totalXp + XpService.weeklyGoalBonus,
        weeklyStreak: next.weeklyStreak + 1,
        lastCelebratedWeekKey: now.weekKey,
      );
      celebrations.add(WeekCompleted(report.completed));
    }

    await _persist(next);

    _sound.play(Sfx.taskCompleted);
    _haptics.medium();
    ref.read(celebrationProvider.notifier).pushAll(celebrations);

    return breakdown;
  }

  /// Grants XP outside the task flow (currently unused by the UI, kept for
  /// future one-off rewards such as an import bonus).
  Future<void> grantXp(XpBreakdown breakdown, {String reason = ''}) async {
    if (breakdown.isEmpty) return;
    final levelBefore = state.level;
    final next = state.copyWith(totalXp: state.totalXp + breakdown.total);
    await _persist(next);
    if (next.level > levelBefore) {
      ref
          .read(celebrationProvider.notifier)
          .push(LevelUp(level: next.level, title: next.levelTitle));
    }
  }

  /// Re-evaluates the catalogue after a non-completion event (e.g. finishing a
  /// long focus session that crosses the Deep Work threshold).
  Future<void> checkAchievements({bool perfectFocus = false}) async {
    final context = AchievementContext(
      stats: state,
      cards: ref.read(cardsProvider).all,
      sessions: ref.read(sessionsProvider),
      boards: ref.read(boardsProvider),
      now: DateTime.now(),
      perfectFocus: perfectFocus,
    );

    final unlocked = AchievementService.evaluate(context);
    if (unlocked.isEmpty) return;

    final map = Map<String, DateTime>.from(state.unlockedAchievements);
    var bonus = 0;
    for (final a in unlocked) {
      map[a.id] = context.now;
      bonus += a.xpBonus;
    }

    await _persist(
      state.copyWith(
        unlockedAchievements: map,
        totalXp: state.totalXp + bonus,
      ),
    );

    ref
        .read(celebrationProvider.notifier)
        .pushAll(unlocked.map(AchievementUnlocked.new));
  }

  Future<void> resetStatistics() async {
    await _persist(UserStats.empty);
    await ref.read(sessionsProvider.notifier).clear();
  }
}

final statsProvider =
    NotifierProvider<GamificationController, UserStats>(
  GamificationController.new,
);

/// Level snapshot for the header badge — rebuilds only when the level or its
/// progress changes, not on every XP tick.
typedef LevelSnapshot = ({int level, String title, double progress, int xp});

final levelProvider = Provider<LevelSnapshot>(
  (ref) => ref.watch(
    statsProvider.select(
      (s) => (
        level: s.level,
        title: s.levelTitle,
        progress: s.levelProgress,
        xp: s.totalXp,
      ),
    ),
  ),
);

final streakProvider = Provider<({int current, int longest, bool live})>(
  (ref) => ref.watch(
    statsProvider.select(
      (s) => (
        current: s.displayStreak,
        longest: s.longestStreak,
        live: s.streakIsLive,
      ),
    ),
  ),
);

/// The achievement grid: every definition paired with its unlock state.
typedef AchievementView = ({
  Achievement achievement,
  DateTime? unlockedAt,
  double? progress,
  String? progressLabel,
});

final achievementsProvider = Provider<List<AchievementView>>((ref) {
  final stats = ref.watch(statsProvider);
  final context = AchievementContext(
    stats: stats,
    cards: ref.watch(cardsProvider).all,
    sessions: ref.watch(sessionsProvider),
    boards: ref.watch(boardsProvider),
    now: DateTime.now(),
  );

  return [
    for (final achievement in Achievements.all)
      (
        achievement: achievement,
        unlockedAt: stats.unlockedAchievements[achievement.id],
        progress: stats.hasAchievement(achievement.id)
            ? 1.0
            : AchievementService.progress(achievement.id, context),
        progressLabel: stats.hasAchievement(achievement.id)
            ? null
            : AchievementService.progressLabel(achievement.id, context),
      ),
  ];
});

/// Weekly report for an arbitrary week, keyed by the Monday's day key so the
/// calendar can page through history without recomputing the current week.
final weeklyReportProvider = Provider.family<WeeklyReport, String>((ref, weekKey) {
  final anchor = DateX.tryParseDayKey(weekKey) ?? DateTime.now();
  return StatsCalculator.weekly(
    anchor: anchor,
    cards: ref.watch(cardsProvider).all,
    sessions: ref.watch(sessionsProvider),
  );
});

final currentWeekReportProvider = Provider<WeeklyReport>(
  (ref) => ref.watch(weeklyReportProvider(DateTime.now().weekKey)),
);
