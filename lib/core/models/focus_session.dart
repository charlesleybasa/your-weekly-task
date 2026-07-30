import 'package:flutter/foundation.dart';

import '../utils/date_x.dart';

/// A finished focus block. Sessions are append-only; every weekly statistic is
/// derived from this log rather than from mutable counters, so recomputing
/// history after an edit is always possible.
@immutable
class FocusSession {
  const FocusSession({
    required this.id,
    required this.taskId,
    required this.boardId,
    required this.taskTitle,
    required this.plannedSeconds,
    required this.actualSeconds,
    required this.startedAt,
    required this.endedAt,
    required this.completed,
  });

  final String id;
  final String taskId;
  final String boardId;

  /// Denormalised so the history still reads correctly after a card is deleted.
  final String taskTitle;

  final int plannedSeconds;
  final int actualSeconds;
  final DateTime startedAt;
  final DateTime endedAt;

  /// True when the timer ran to zero rather than being cancelled early.
  final bool completed;

  Duration get planned => Duration(seconds: plannedSeconds);
  Duration get actual => Duration(seconds: actualSeconds);

  String get dayKey => startedAt.dayKey;
  String get weekKey => startedAt.weekKey;

  /// "Perfect focus": ran the full block without cancelling.
  bool get isPerfect => completed && actualSeconds >= plannedSeconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'boardId': boardId,
        'taskTitle': taskTitle,
        'plannedSeconds': plannedSeconds,
        'actualSeconds': actualSeconds,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return FocusSession(
      id: json['id'] as String,
      taskId: json['taskId'] as String? ?? '',
      boardId: json['boardId'] as String? ?? '',
      taskTitle: json['taskTitle'] as String? ?? '',
      plannedSeconds: json['plannedSeconds'] as int? ?? 0,
      actualSeconds: json['actualSeconds'] as int? ?? 0,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? now,
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ?? now,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Persisted countdown. Only one may exist at a time — the app deliberately
/// refuses overlapping timers.
///
/// The elapsed time is reconstructed from wall-clock timestamps rather than a
/// tick counter, so closing the app mid-session (or the OS suspending it) does
/// not lose or freeze the countdown.
@immutable
class ActiveTimer {
  const ActiveTimer({
    required this.taskId,
    required this.boardId,
    required this.totalSeconds,
    required this.startedAt,
    required this.accumulatedSeconds,
    required this.isPaused,
    required this.lastResumedAt,
  });

  final String taskId;
  final String boardId;

  /// The chosen preset, in seconds.
  final int totalSeconds;

  /// When the very first run of this timer began (used for the session log).
  final DateTime startedAt;

  /// Seconds banked from previous run segments, before the current one.
  final int accumulatedSeconds;

  final bool isPaused;

  /// Start of the current running segment. Ignored while paused.
  final DateTime lastResumedAt;

  factory ActiveTimer.start({
    required String taskId,
    required String boardId,
    required int totalSeconds,
  }) {
    final now = DateTime.now();
    return ActiveTimer(
      taskId: taskId,
      boardId: boardId,
      totalSeconds: totalSeconds,
      startedAt: now,
      accumulatedSeconds: 0,
      isPaused: false,
      lastResumedAt: now,
    );
  }

  /// Elapsed seconds as of [now], clamped to [totalSeconds].
  int elapsedSecondsAt(DateTime now) {
    final live = isPaused
        ? 0
        : now.difference(lastResumedAt).inSeconds.clamp(0, totalSeconds);
    final total = accumulatedSeconds + live;
    return total.clamp(0, totalSeconds);
  }

  int remainingSecondsAt(DateTime now) => totalSeconds - elapsedSecondsAt(now);

  bool isFinishedAt(DateTime now) => remainingSecondsAt(now) <= 0;

  double progressAt(DateTime now) =>
      totalSeconds == 0 ? 0 : elapsedSecondsAt(now) / totalSeconds;

  ActiveTimer pause() {
    if (isPaused) return this;
    return ActiveTimer(
      taskId: taskId,
      boardId: boardId,
      totalSeconds: totalSeconds,
      startedAt: startedAt,
      accumulatedSeconds: elapsedSecondsAt(DateTime.now()),
      isPaused: true,
      lastResumedAt: lastResumedAt,
    );
  }

  ActiveTimer resume() {
    if (!isPaused) return this;
    return ActiveTimer(
      taskId: taskId,
      boardId: boardId,
      totalSeconds: totalSeconds,
      startedAt: startedAt,
      accumulatedSeconds: accumulatedSeconds,
      isPaused: false,
      lastResumedAt: DateTime.now(),
    );
  }

  ActiveTimer addMinutes(int minutes) => ActiveTimer(
        taskId: taskId,
        boardId: boardId,
        totalSeconds: totalSeconds + minutes * 60,
        startedAt: startedAt,
        accumulatedSeconds: accumulatedSeconds,
        isPaused: isPaused,
        lastResumedAt: lastResumedAt,
      );

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'boardId': boardId,
        'totalSeconds': totalSeconds,
        'startedAt': startedAt.toIso8601String(),
        'accumulatedSeconds': accumulatedSeconds,
        'isPaused': isPaused,
        'lastResumedAt': lastResumedAt.toIso8601String(),
      };

  factory ActiveTimer.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ActiveTimer(
      taskId: json['taskId'] as String? ?? '',
      boardId: json['boardId'] as String? ?? '',
      totalSeconds: json['totalSeconds'] as int? ?? 1500,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? now,
      accumulatedSeconds: json['accumulatedSeconds'] as int? ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      lastResumedAt:
          DateTime.tryParse(json['lastResumedAt'] as String? ?? '') ?? now,
    );
  }
}

/// Timer presets offered on the focus screen.
abstract final class TimerPresets {
  static const minutes = <int>[15, 25, 45, 60, 90];
  static const int min = 1;
  static const int max = 240;
}
