import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/core/models/enums.dart';
import 'package:momentum/core/models/task_card.dart';
import 'package:momentum/core/utils/date_x.dart';
import 'package:momentum/state/card_index.dart';

TaskCard _card({
  required String id,
  String boardId = 'b1',
  TaskStatus status = TaskStatus.todo,
  int sortIndex = 0,
  String? dayKey,
}) {
  final now = DateTime(2026, 7, 30);
  return TaskCard(
    id: id,
    boardId: boardId,
    title: id,
    status: status,
    priority: Priority.medium,
    estimatedMinutes: 25,
    sortIndex: sortIndex,
    scheduledDayKey: dayKey,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CardSlice equality', () {
    // This is what stops one column's edit from rebuilding every other column:
    // Riverpod compares with `==`, and two Lists with equal contents are not.
    test('slices with identical contents are equal', () {
      final a = _card(id: 'a');
      expect(CardSlice([a]) == CardSlice([a]), isTrue);
    });

    test('slices with different contents are not equal', () {
      expect(
        CardSlice([_card(id: 'a')]) == CardSlice([_card(id: 'b')]),
        isFalse,
      );
    });

    test('an empty slice equals another empty slice', () {
      expect(const CardSlice([]) == CardSlice.empty, isTrue);
    });
  });

  group('CardIndex.build', () {
    test('buckets cards by column and preserves sort order', () {
      final index = CardIndex.build([
        _card(id: 'c', sortIndex: 2),
        _card(id: 'a', sortIndex: 0),
        _card(id: 'b', sortIndex: 1),
        _card(id: 'd', status: TaskStatus.done, sortIndex: 0),
      ]);

      final todo = index.forColumn('b1', TaskStatus.todo);
      expect(todo.items.map((c) => c.id), ['a', 'b', 'c']);
      expect(index.forColumn('b1', TaskStatus.done).length, 1);
      expect(index.forColumn('b1', TaskStatus.started).isEmpty, isTrue);
    });

    test('an unknown column returns an empty slice rather than null', () {
      final index = CardIndex.build([_card(id: 'a')]);
      expect(index.forColumn('nope', TaskStatus.todo), CardSlice.empty);
      expect(index.forBoard('nope').isEmpty, isTrue);
      expect(index.forDay('2026-01-01').isEmpty, isTrue);
    });

    test('board stats count each column', () {
      final index = CardIndex.build([
        _card(id: 'a'),
        _card(id: 'b', status: TaskStatus.started),
        _card(id: 'c', status: TaskStatus.done),
        _card(id: 'd', status: TaskStatus.done),
      ]);

      final stats = index.statsFor('b1');
      expect(stats.total, 4);
      expect(stats.todo, 1);
      expect(stats.started, 1);
      expect(stats.done, 2);
      expect(stats.completion, 0.5);
      expect(stats.remaining, 2);
      expect(stats.isComplete, isFalse);
    });

    test('an empty board reports zero completion, not complete', () {
      final index = CardIndex.build([]);
      final stats = index.statsFor('b1');
      expect(stats.completion, 0);
      expect(stats.isComplete, isFalse);
    });

    test('day buckets lead with unfinished work', () {
      final key = DateTime(2026, 7, 30).dayKey;
      final index = CardIndex.build([
        _card(id: 'done', status: TaskStatus.done, dayKey: key, sortIndex: 0),
        _card(id: 'open', dayKey: key, sortIndex: 1),
      ]);

      expect(index.forDay(key).items.first.id, 'open');
    });

    test('dayTally returns total and done counts', () {
      final key = DateTime(2026, 7, 30).dayKey;
      final index = CardIndex.build([
        _card(id: 'a', dayKey: key),
        _card(id: 'b', dayKey: key, status: TaskStatus.done),
        _card(id: 'c'), // unscheduled — must not be counted
      ]);

      expect(index.dayTally(key), (2, 1));
      expect(index.dayTally('2026-01-01'), (0, 0));
    });

    test('nextSortIndex appends past the last card in a column', () {
      final index = CardIndex.build([
        _card(id: 'a', sortIndex: 0),
        _card(id: 'b', sortIndex: 7),
      ]);

      expect(index.nextSortIndex('b1', TaskStatus.todo), 8);
      expect(index.nextSortIndex('b1', TaskStatus.done), 0);
    });

    test('separates cards belonging to different boards', () {
      final index = CardIndex.build([
        _card(id: 'a', boardId: 'b1'),
        _card(id: 'b', boardId: 'b2'),
      ]);

      expect(index.forBoard('b1').length, 1);
      expect(index.forBoard('b2').length, 1);
      expect(index.boardCount, 2);
      expect(index.openCount, 2);
      expect(index.doneCount, 0);
    });
  });

  group('TaskCard.withStatus', () {
    test('stamps startedAt on first move to Started', () {
      final card = _card(id: 'a').withStatus(TaskStatus.started);
      expect(card.startedAt, isNotNull);
      expect(card.completedAt, isNull);
    });

    test('stamps completedAt on Done and clears it on reopen', () {
      final done = _card(id: 'a').withStatus(TaskStatus.done);
      expect(done.completedAt, isNotNull);
      expect(done.isDone, isTrue);

      final reopened = done.withStatus(TaskStatus.todo);
      expect(reopened.completedAt, isNull);
      expect(reopened.startedAt, isNull);
    });
  });

  group('TaskCard JSON', () {
    test('round-trips every field that matters', () {
      final original = _card(id: 'a', dayKey: '2026-07-30').copyWith(
        tags: ['deep', 'writing'],
        checklist: [const ChecklistItem(id: 'i1', label: 'Outline', done: true)],
        focusedSeconds: 900,
        completedSessions: 2,
        xpAwarded: 75,
      );

      final restored = TaskCard.fromJson(original.toJson());
      expect(restored, original);
    });

    test('tolerates a record missing optional fields', () {
      final restored = TaskCard.fromJson({'id': 'x'});
      expect(restored.id, 'x');
      expect(restored.title, 'Untitled task');
      expect(restored.status, TaskStatus.todo);
      expect(restored.estimatedMinutes, 25);
      expect(restored.checklist, isEmpty);
    });
  });
}
