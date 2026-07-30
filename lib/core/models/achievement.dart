import 'package:flutter/material.dart';

/// A single unlockable. Definitions are static; unlock state lives in
/// [UserStats.unlockedAchievements] keyed by [id].
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.xpBonus,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Badge colour. Deliberately a raw value: badges keep their identity across
  /// light and dark, and each is checked for >= 3:1 against both surfaces.
  final Color tint;

  /// One-off XP granted on unlock.
  final int xpBonus;
}

/// The achievement catalogue.
///
/// Ordered roughly by the sequence a new user will hit them, which is also the
/// order the achievements grid renders in.
abstract final class Achievements {
  static const firstTask = Achievement(
    id: 'first_task',
    title: 'First Task',
    description: 'Complete your very first task',
    icon: Icons.local_fire_department_rounded,
    tint: Color(0xFFFF7A45),
    xpBonus: 25,
  );

  static const tenTasks = Achievement(
    id: 'ten_tasks',
    title: 'Getting Somewhere',
    description: 'Complete 10 tasks',
    icon: Icons.emoji_events_rounded,
    tint: Color(0xFFFFC53D),
    xpBonus: 75,
  );

  static const fiftyTasks = Achievement(
    id: 'fifty_tasks',
    title: 'Productivity Machine',
    description: 'Complete 50 tasks',
    icon: Icons.bolt_rounded,
    tint: Color(0xFF8B5CF6),
    xpBonus: 200,
  );

  static const perfectWeek = Achievement(
    id: 'perfect_week',
    title: 'Finish the Week',
    description: 'Complete every task you planned for a week',
    icon: Icons.rocket_launch_rounded,
    tint: Color(0xFF4F7CFF),
    xpBonus: 250,
  );

  static const perfectFocus = Achievement(
    id: 'perfect_focus',
    title: 'Perfect Focus',
    description: 'Finish a timer without pausing or cancelling',
    icon: Icons.track_changes_rounded,
    tint: Color(0xFF22C55E),
    xpBonus: 60,
  );

  static const nightOwl = Achievement(
    id: 'night_owl',
    title: 'Night Owl',
    description: 'Complete a task after 10pm',
    icon: Icons.nightlight_round,
    tint: Color(0xFF6366F1),
    xpBonus: 40,
  );

  static const earlyBird = Achievement(
    id: 'early_bird',
    title: 'Early Bird',
    description: 'Complete a task before 7am',
    icon: Icons.wb_twilight_rounded,
    tint: Color(0xFFF59E0B),
    xpBonus: 40,
  );

  static const streak7 = Achievement(
    id: 'streak_7',
    title: 'Seven Day Fire',
    description: 'Keep a 7 day streak alive',
    icon: Icons.whatshot_rounded,
    tint: Color(0xFFEF4444),
    xpBonus: 150,
  );

  static const deepWork = Achievement(
    id: 'deep_work',
    title: 'Deep Work',
    description: 'Focus for 2 hours in a single day',
    icon: Icons.self_improvement_rounded,
    tint: Color(0xFF14B8A6),
    xpBonus: 120,
  );

  static const boardMaster = Achievement(
    id: 'board_master',
    title: 'Clean Sweep',
    description: 'Clear every card on a board',
    icon: Icons.done_all_rounded,
    tint: Color(0xFF0EA5E9),
    xpBonus: 100,
  );

  static const level10 = Achievement(
    id: 'level_10',
    title: 'Creator',
    description: 'Reach level 10',
    icon: Icons.auto_awesome_rounded,
    tint: Color(0xFFEC4899),
    xpBonus: 0,
  );

  static const all = <Achievement>[
    firstTask,
    tenTasks,
    perfectFocus,
    earlyBird,
    nightOwl,
    streak7,
    fiftyTasks,
    deepWork,
    boardMaster,
    perfectWeek,
    level10,
  ];

  static final _byId = {for (final a in all) a.id: a};

  static Achievement? byId(String id) => _byId[id];
}
