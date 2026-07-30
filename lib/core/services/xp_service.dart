import 'package:flutter/foundation.dart';

import '../models/task_card.dart';

/// One line of a reward. Shown individually in the completion modal so the
/// number never feels arbitrary — the user can always see what earned it.
@immutable
class XpLine {
  const XpLine(this.label, this.amount);

  final String label;
  final int amount;
}

@immutable
class XpBreakdown {
  const XpBreakdown(this.lines);

  static const zero = XpBreakdown(<XpLine>[]);

  final List<XpLine> lines;

  int get total => lines.fold(0, (sum, l) => sum + l.amount);
  bool get isEmpty => lines.isEmpty;
}

/// Reward maths.
///
/// Bonuses are deliberately small relative to the base award: the app should
/// reward *finishing tasks*, not gaming the timer.
abstract final class XpService {
  static const int timerBonus = 25;
  static const int perfectFocusBonus = 15;
  static const int firstOfDayBonus = 20;
  static const int weeklyGoalBonus = 250;
  static const int streakBonusPerDay = 5;
  static const int streakBonusCap = 50;

  /// XP for completing [card].
  ///
  /// [viaTimer] — the completion came from a timer running to zero.
  /// [perfectFocus] — that timer was never paused or extended.
  /// [isFirstToday] — no other task has been completed today yet.
  /// [streakDays] — the streak value *after* this completion.
  static XpBreakdown forCompletion(
    TaskCard card, {
    bool viaTimer = false,
    bool perfectFocus = false,
    bool isFirstToday = false,
    int streakDays = 0,
  }) {
    final lines = <XpLine>[
      XpLine('${card.size.label} task', card.baseXp),
    ];

    if (viaTimer) lines.add(const XpLine('Timer finished', timerBonus));
    if (perfectFocus) lines.add(const XpLine('Perfect focus', perfectFocusBonus));
    if (isFirstToday) lines.add(const XpLine('First task today', firstOfDayBonus));

    if (streakDays >= 2) {
      final bonus =
          (streakDays * streakBonusPerDay).clamp(0, streakBonusCap).toInt();
      if (bonus > 0) lines.add(XpLine('$streakDays day streak', bonus));
    }

    return XpBreakdown(lines);
  }

  /// Awarded once when every task planned for the week is finished.
  static const XpBreakdown weeklyGoal =
      XpBreakdown(<XpLine>[XpLine('Week complete', weeklyGoalBonus)]);
}
