import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/focus_session.dart';
import '../core/models/task_card.dart';
import '../core/services/id_service.dart';
import '../core/services/sound_service.dart';
import 'app_providers.dart';
import 'cards_controller.dart';
import 'sessions_controller.dart';
import 'settings_controller.dart';

/// What the focus UI renders. Derived from [ActiveTimer] once per tick so
/// widgets never do clock arithmetic in `build()`.
@immutable
class TimerSnapshot {
  const TimerSnapshot({
    required this.timer,
    required this.remainingSeconds,
    required this.progress,
    required this.finished,
    required this.wasPaused,
  });

  static const idle = TimerSnapshot(
    timer: null,
    remainingSeconds: 0,
    progress: 0,
    finished: false,
    wasPaused: false,
  );

  final ActiveTimer? timer;
  final int remainingSeconds;

  /// 0.0 → 1.0 elapsed.
  final double progress;

  /// True for the single tick where the countdown reaches zero.
  final bool finished;

  /// Whether this run has ever been paused — decides the Perfect Focus bonus.
  final bool wasPaused;

  bool get isActive => timer != null;
  bool get isRunning => timer != null && !timer!.isPaused;
  bool get isPaused => timer?.isPaused ?? false;
  String? get taskId => timer?.taskId;

  Duration get remaining => Duration(seconds: remainingSeconds);

  /// The last stretch, where the ring glows and the countdown pulses.
  bool get isFinalCountdown => isActive && remainingSeconds <= 10 && remainingSeconds > 0;

  TimerSnapshot copyWith({
    ActiveTimer? timer,
    int? remainingSeconds,
    double? progress,
    bool? finished,
    bool? wasPaused,
  }) =>
      TimerSnapshot(
        timer: timer ?? this.timer,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        progress: progress ?? this.progress,
        finished: finished ?? this.finished,
        wasPaused: wasPaused ?? this.wasPaused,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerSnapshot &&
          other.remainingSeconds == remainingSeconds &&
          other.finished == finished &&
          other.wasPaused == wasPaused &&
          other.timer?.taskId == timer?.taskId &&
          other.timer?.isPaused == timer?.isPaused &&
          other.timer?.totalSeconds == timer?.totalSeconds;

  @override
  int get hashCode => Object.hash(
        remainingSeconds,
        finished,
        wasPaused,
        timer?.taskId,
        timer?.isPaused,
        timer?.totalSeconds,
      );
}

/// The one and only countdown.
///
/// Elapsed time is always recomputed from wall-clock timestamps, never
/// accumulated tick by tick — so a suspended app, a locked screen or a cold
/// restart all resume with the correct remaining time.
class TimerController extends Notifier<TimerSnapshot> {
  Timer? _ticker;

  @override
  TimerSnapshot build() {
    ref.onDispose(() => _ticker?.cancel());

    final restored = ref.read(statsRepositoryProvider).loadActiveTimer();
    if (restored == null) return TimerSnapshot.idle;

    // A timer that expired while the app was closed should present as finished,
    // not silently vanish.
    final snapshot = _snapshotOf(restored, wasPaused: restored.isPaused);
    if (!snapshot.finished && !restored.isPaused) _startTicker();
    return snapshot;
  }

  TimerSnapshot _snapshotOf(ActiveTimer timer, {required bool wasPaused}) {
    final now = DateTime.now();
    final remaining = timer.remainingSecondsAt(now);
    return TimerSnapshot(
      timer: timer,
      remainingSeconds: remaining,
      progress: timer.progressAt(now),
      finished: remaining <= 0,
      wasPaused: wasPaused,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    // One tick per second: the ring interpolates between values in the widget
    // layer, so a faster tick would buy nothing but rebuilds.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    final timer = state.timer;
    if (timer == null || timer.isPaused) {
      _stopTicker();
      return;
    }

    final next = _snapshotOf(timer, wasPaused: state.wasPaused);
    final crossedZero = next.finished && !state.finished;
    state = next;

    if (next.isFinalCountdown && ref.read(settingsProvider).tickingEnabled) {
      ref.read(soundServiceProvider).play(Sfx.timerTick, volume: 0.35);
    }

    if (crossedZero) {
      _stopTicker();
      _handleFinish(timer);
    }
  }

  /// Runs the moment the countdown crosses zero.
  ///
  /// The completion *flow* (celebration, "move to Done?") is driven by the
  /// focus screen watching [TimerSnapshot.finished]; this only fires the
  /// side effects that must happen even if no UI is listening.
  void _handleFinish(ActiveTimer timer) {
    ref.read(soundServiceProvider).play(Sfx.timerFinished);
    ref.read(hapticServiceProvider).heavy();

    // The scheduled alert is redundant now that the app has observed the end.
    unawaited(ref.read(notificationServiceProvider).cancelTimerFinish());

    final card = ref.read(cardsProvider).byId[timer.taskId];
    if (card != null) {
      unawaited(
        ref.read(notificationServiceProvider).showTimerFinished(card.title),
      );
    }
  }

  /// Starts a countdown for [card]. Refuses to replace a running timer — the
  /// caller must cancel first, which keeps "only one active timer" true.
  Future<bool> start(TaskCard card, {int? minutes}) async {
    if (state.isActive && !state.finished) return false;

    final duration = (minutes ?? ref.read(settingsProvider).defaultTimerMinutes)
        .clamp(TimerPresets.min, TimerPresets.max);

    final timer = ActiveTimer.start(
      taskId: card.id,
      boardId: card.boardId,
      totalSeconds: duration * 60,
    );

    state = _snapshotOf(timer, wasPaused: false);
    _startTicker();

    await ref.read(statsRepositoryProvider).saveActiveTimer(timer);

    ref.read(soundServiceProvider).play(Sfx.timerStart);
    ref.read(hapticServiceProvider).medium();

    unawaited(
      ref.read(notificationServiceProvider).scheduleTimerFinish(
            card.title,
            Duration(seconds: timer.totalSeconds),
          ),
    );

    return true;
  }

  Future<void> pause() async {
    final timer = state.timer;
    if (timer == null || timer.isPaused) return;

    final paused = timer.pause();
    _stopTicker();
    state = _snapshotOf(paused, wasPaused: true);

    await ref.read(statsRepositoryProvider).saveActiveTimer(paused);
    await ref.read(notificationServiceProvider).cancelTimerFinish();

    ref.read(soundServiceProvider).play(Sfx.timerPause);
    ref.read(hapticServiceProvider).light();
  }

  Future<void> resume() async {
    final timer = state.timer;
    if (timer == null || !timer.isPaused) return;

    final resumed = timer.resume();
    state = _snapshotOf(resumed, wasPaused: state.wasPaused);
    _startTicker();

    await ref.read(statsRepositoryProvider).saveActiveTimer(resumed);

    final card = ref.read(cardsProvider).byId[resumed.taskId];
    if (card != null) {
      unawaited(
        ref.read(notificationServiceProvider).scheduleTimerFinish(
              card.title,
              Duration(seconds: resumed.remainingSecondsAt(DateTime.now())),
            ),
      );
    }

    ref.read(soundServiceProvider).play(Sfx.timerResume);
    ref.read(hapticServiceProvider).light();
  }

  /// Extends a running timer. Marks the run as "paused" for bonus purposes —
  /// buying extra minutes is not perfect focus.
  Future<void> extend(int minutes) async {
    final timer = state.timer;
    if (timer == null) return;
    final extended = timer.addMinutes(minutes);
    state = _snapshotOf(extended, wasPaused: true);
    if (!extended.isPaused) _startTicker();
    await ref.read(statsRepositoryProvider).saveActiveTimer(extended);
    ref.read(hapticServiceProvider).selection();
  }

  /// Ends the session and writes it to the log.
  ///
  /// [completed] distinguishes "ran to zero" from "user cancelled", which is
  /// what the statistics and the Perfect Focus rule key off.
  Future<FocusSession?> stop({required bool completed}) async {
    final timer = state.timer;
    if (timer == null) {
      state = TimerSnapshot.idle;
      return null;
    }

    _stopTicker();
    final now = DateTime.now();
    final elapsed = timer.elapsedSecondsAt(now);

    final session = FocusSession(
      id: Ids.next(),
      taskId: timer.taskId,
      boardId: timer.boardId,
      taskTitle: ref.read(cardsProvider).byId[timer.taskId]?.title ?? 'Task',
      plannedSeconds: timer.totalSeconds,
      actualSeconds: elapsed,
      startedAt: timer.startedAt,
      endedAt: now,
      completed: completed,
    );

    state = TimerSnapshot.idle;

    await ref.read(statsRepositoryProvider).saveActiveTimer(null);
    await ref.read(notificationServiceProvider).cancelTimerFinish();

    // Sessions shorter than a few seconds are noise, not history.
    if (elapsed >= 5) {
      await ref.read(sessionsProvider.notifier).add(session);
      await ref
          .read(cardsProvider.notifier)
          .logFocus(timer.taskId, elapsed, completed: completed);
    }

    return session;
  }

  Future<void> cancel() async {
    if (!state.isActive) return;
    await stop(completed: false);
    ref.read(soundServiceProvider).play(Sfx.timerPause);
    ref.read(hapticServiceProvider).light();
  }

  /// Recomputes from the wall clock — called when the app returns to the
  /// foreground, where the periodic ticker may have been throttled or frozen.
  void syncWithClock() {
    final timer = state.timer;
    if (timer == null || timer.isPaused) return;

    final next = _snapshotOf(timer, wasPaused: state.wasPaused);
    final crossedZero = next.finished && !state.finished;
    state = next;

    if (crossedZero) {
      _stopTicker();
      _handleFinish(timer);
    } else if (!next.finished) {
      _startTicker();
    }
  }
}

final timerProvider =
    NotifierProvider<TimerController, TimerSnapshot>(TimerController.new);

/// The card the timer is attached to, or null when idle.
final activeTimerCardProvider = Provider<TaskCard?>((ref) {
  final taskId = ref.watch(timerProvider.select((s) => s.taskId));
  if (taskId == null) return null;
  return ref.watch(cardsProvider.select((index) => index.byId[taskId]));
});

/// True while any countdown is live — the bottom nav uses it to pulse the
/// Focus tab.
final hasRunningTimerProvider =
    Provider<bool>((ref) => ref.watch(timerProvider.select((s) => s.isRunning)));
