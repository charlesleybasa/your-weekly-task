import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/core/models/focus_session.dart';

void main() {
  group('ActiveTimer wall-clock reconstruction', () {
    // These cover the property the whole timer design rests on: elapsed time is
    // derived from timestamps, so killing the app mid-session cannot lose or
    // freeze the countdown.

    test('elapsed tracks real time while running', () {
      final start = DateTime(2026, 7, 30, 9);
      final timer = ActiveTimer(
        taskId: 't',
        boardId: 'b',
        totalSeconds: 1500,
        startedAt: start,
        accumulatedSeconds: 0,
        isPaused: false,
        lastResumedAt: start,
      );

      expect(timer.elapsedSecondsAt(start), 0);
      expect(timer.remainingSecondsAt(start), 1500);
      expect(
        timer.remainingSecondsAt(start.add(const Duration(minutes: 10))),
        900,
      );
    });

    test('elapsed clamps at the total instead of running negative', () {
      final start = DateTime(2026, 7, 30, 9);
      final timer = ActiveTimer(
        taskId: 't',
        boardId: 'b',
        totalSeconds: 600,
        startedAt: start,
        accumulatedSeconds: 0,
        isPaused: false,
        lastResumedAt: start,
      );

      // Simulates the app being closed and reopened hours later.
      final muchLater = start.add(const Duration(hours: 5));
      expect(timer.elapsedSecondsAt(muchLater), 600);
      expect(timer.remainingSecondsAt(muchLater), 0);
      expect(timer.isFinishedAt(muchLater), isTrue);
      expect(timer.progressAt(muchLater), 1.0);
    });

    test('a paused timer does not advance', () {
      final start = DateTime(2026, 7, 30, 9);
      final running = ActiveTimer(
        taskId: 't',
        boardId: 'b',
        totalSeconds: 1500,
        startedAt: start,
        accumulatedSeconds: 300,
        isPaused: true,
        lastResumedAt: start,
      );

      expect(running.elapsedSecondsAt(start), 300);
      expect(
        running.elapsedSecondsAt(start.add(const Duration(hours: 2))),
        300,
        reason: 'time spent paused must not count',
      );
    });

    test('pause banks elapsed time and resume continues from there', () {
      final timer = ActiveTimer.start(
        taskId: 't',
        boardId: 'b',
        totalSeconds: 1500,
      );

      final paused = timer.pause();
      expect(paused.isPaused, isTrue);
      // Banked value equals whatever had elapsed, which is ~0 in a fast test.
      expect(paused.accumulatedSeconds, lessThan(2));

      final resumed = paused.resume();
      expect(resumed.isPaused, isFalse);
      expect(resumed.accumulatedSeconds, paused.accumulatedSeconds);
      expect(
        resumed.startedAt,
        timer.startedAt,
        reason: 'the session start must survive a pause/resume cycle',
      );
    });

    test('pausing twice is a no-op', () {
      final paused = ActiveTimer.start(
        taskId: 't',
        boardId: 'b',
        totalSeconds: 60,
      ).pause();
      expect(identical(paused.pause(), paused), isTrue);
    });

    test('extending adds to the total without disturbing elapsed', () {
      final start = DateTime(2026, 7, 30, 9);
      final timer = ActiveTimer(
        taskId: 't',
        boardId: 'b',
        totalSeconds: 600,
        startedAt: start,
        accumulatedSeconds: 120,
        isPaused: true,
        lastResumedAt: start,
      );

      final extended = timer.addMinutes(5);
      expect(extended.totalSeconds, 900);
      expect(extended.elapsedSecondsAt(start), 120);
      expect(extended.remainingSecondsAt(start), 780);
    });

    test('survives a JSON round-trip', () {
      final original = ActiveTimer(
        taskId: 'task-7',
        boardId: 'board-2',
        totalSeconds: 2700,
        startedAt: DateTime(2026, 7, 30, 9, 15),
        accumulatedSeconds: 431,
        isPaused: true,
        lastResumedAt: DateTime(2026, 7, 30, 9, 20),
      );

      final restored = ActiveTimer.fromJson(original.toJson());
      expect(restored.taskId, original.taskId);
      expect(restored.boardId, original.boardId);
      expect(restored.totalSeconds, original.totalSeconds);
      expect(restored.accumulatedSeconds, original.accumulatedSeconds);
      expect(restored.isPaused, original.isPaused);
      expect(restored.startedAt, original.startedAt);
      expect(restored.lastResumedAt, original.lastResumedAt);
    });
  });
}
