import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The three kanban columns. Nothing else exists by design — the product bets
/// that a fixed, tiny column set is what keeps weekly planning from sprawling.
enum TaskStatus {
  todo('To Do', Icons.circle_outlined),
  started('Started', Icons.play_circle_outline_rounded),
  done('Done', Icons.check_circle_outline_rounded);

  const TaskStatus(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isDone => this == TaskStatus.done;

  Color color(AppColors c) => switch (this) {
        TaskStatus.todo => c.textTertiary,
        TaskStatus.started => c.primary,
        TaskStatus.done => c.success,
      };

  static TaskStatus fromName(String? name) => TaskStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TaskStatus.todo,
      );
}

enum Priority {
  low('Low', 0),
  medium('Medium', 1),
  high('High', 2);

  const Priority(this.label, this.weight);

  final String label;

  /// Higher sorts first in "what should I do next" suggestions.
  final int weight;

  Color color(AppColors c) => switch (this) {
        Priority.low => c.textTertiary,
        Priority.medium => c.warning,
        Priority.high => c.danger,
      };

  Color softColor(AppColors c) => switch (this) {
        Priority.low => c.surfaceSunken,
        Priority.medium => c.warningSoft,
        Priority.high => c.dangerSoft,
      };

  static Priority fromName(String? name) => Priority.values.firstWhere(
        (p) => p.name == name,
        orElse: () => Priority.medium,
      );
}

/// Effort bucket that determines the base XP reward.
enum TaskSize {
  small('Small', 20),
  medium('Medium', 50),
  large('Large', 100);

  const TaskSize(this.label, this.baseXp);

  final String label;
  final int baseXp;

  /// Derived from the estimate so the user never has to pick a size manually.
  static TaskSize fromMinutes(int minutes) {
    if (minutes <= 20) return TaskSize.small;
    if (minutes <= 60) return TaskSize.medium;
    return TaskSize.large;
  }
}

enum ThemeChoice {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemeChoice(this.label);

  final String label;

  ThemeMode get mode => switch (this) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      };

  static ThemeChoice fromName(String? name) => ThemeChoice.values.firstWhere(
        (t) => t.name == name,
        orElse: () => ThemeChoice.system,
      );
}

/// Board glyphs. A curated vector set — never emoji, which render differently
/// per platform and cannot be tinted by the theme.
abstract final class BoardIcons {
  static const options = <String, IconData>{
    'work': Icons.work_outline_rounded,
    'person': Icons.person_outline_rounded,
    'study': Icons.school_outlined,
    'fitness': Icons.fitness_center_rounded,
    'code': Icons.code_rounded,
    'design': Icons.brush_outlined,
    'money': Icons.payments_outlined,
    'home': Icons.home_outlined,
    'idea': Icons.lightbulb_outline_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'health': Icons.favorite_outline_rounded,
    'music': Icons.headphones_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'rocket': Icons.rocket_launch_outlined,
    'book': Icons.menu_book_outlined,
    'target': Icons.track_changes_rounded,
  };

  static IconData resolve(String key) =>
      options[key] ?? Icons.dashboard_outlined;

  static String get fallbackKey => 'target';
}
