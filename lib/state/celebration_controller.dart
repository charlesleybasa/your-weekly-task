import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/achievement.dart';
import '../core/services/xp_service.dart';

/// Something worth celebrating. The domain layer emits these; the UI layer
/// decides how they look, which keeps confetti out of the business logic.
@immutable
sealed class Celebration {
  const Celebration();
}

class XpAwarded extends Celebration {
  const XpAwarded({
    required this.breakdown,
    required this.taskTitle,
    required this.totalXpAfter,
  });

  final XpBreakdown breakdown;
  final String taskTitle;
  final int totalXpAfter;
}

class LevelUp extends Celebration {
  const LevelUp({required this.level, required this.title});

  final int level;
  final String title;
}

class AchievementUnlocked extends Celebration {
  const AchievementUnlocked(this.achievement);

  final Achievement achievement;
}

class WeekCompleted extends Celebration {
  const WeekCompleted(this.tasksFinished);

  final int tasksFinished;
}

/// A FIFO queue so simultaneous events (task done → level up → achievement)
/// play one after another instead of stacking three modals on top of each
/// other.
class CelebrationController extends Notifier<List<Celebration>> {
  @override
  List<Celebration> build() => const [];

  void push(Celebration celebration) => state = [...state, celebration];

  void pushAll(Iterable<Celebration> celebrations) {
    if (celebrations.isEmpty) return;
    state = [...state, ...celebrations];
  }

  /// Consumes the front of the queue once its animation has finished.
  void consume() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }

  void clear() => state = const [];
}

final celebrationProvider =
    NotifierProvider<CelebrationController, List<Celebration>>(
  CelebrationController.new,
);

/// The event currently on screen, or null when the queue is empty.
final currentCelebrationProvider = Provider<Celebration?>((ref) {
  final queue = ref.watch(celebrationProvider);
  return queue.isEmpty ? null : queue.first;
});
