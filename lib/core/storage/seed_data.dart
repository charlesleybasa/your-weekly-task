import '../models/board.dart';
import '../models/enums.dart';
import '../models/task_card.dart';
import '../services/id_service.dart';
import '../utils/date_x.dart';

/// First-run content.
///
/// A brand-new user opening an empty kanban board learns nothing about how the
/// app works. Three small boards with a handful of realistic cards make the
/// weekly rhythm legible immediately — and every one of them is deletable.
abstract final class SeedData {
  static ({List<Board> boards, List<TaskCard> cards}) build() {
    final now = DateTime.now();
    final week = now.weekDays;

    Board board(int i, String title, String desc, int color, String icon) =>
        Board(
          id: Ids.next(),
          title: title,
          description: desc,
          colorValue: color,
          iconKey: icon,
          sortIndex: i,
          createdAt: now,
          updatedAt: now,
        );

    final work = board(0, 'Work', 'Deep work and shipping', 0xFF4F7CFF, 'work');
    final personal =
        board(1, 'Personal', 'Life admin and errands', 0xFF22C55E, 'person');
    final learning =
        board(2, 'Learning', 'Courses and reading', 0xFF8B5CF6, 'study');

    var order = 0;
    TaskCard card(
      Board b,
      String title, {
      required TaskStatus status,
      required Priority priority,
      required int minutes,
      DateTime? day,
      String description = '',
    }) {
      return TaskCard(
        id: Ids.next(),
        boardId: b.id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        estimatedMinutes: minutes,
        sortIndex: order++,
        scheduledDayKey: day?.dayKey,
        createdAt: now,
        updatedAt: now,
        completedAt: status.isDone ? now : null,
        startedAt: status == TaskStatus.todo ? null : now,
      );
    }

    return (
      boards: [work, personal, learning],
      cards: [
        card(
          work,
          'Draft the Q3 roadmap',
          description: 'Pull last quarter\'s numbers first, then outline.',
          status: TaskStatus.started,
          priority: Priority.high,
          minutes: 45,
          day: week[0],
        ),
        card(
          work,
          'Review pull requests',
          status: TaskStatus.todo,
          priority: Priority.medium,
          minutes: 25,
          day: week[0],
        ),
        card(
          work,
          'Prep Thursday demo',
          status: TaskStatus.todo,
          priority: Priority.high,
          minutes: 60,
          day: week[3],
        ),
        card(
          work,
          'Clear the inbox',
          status: TaskStatus.done,
          priority: Priority.low,
          minutes: 15,
          day: week[0],
        ),
        card(
          personal,
          'Weekly grocery run',
          status: TaskStatus.todo,
          priority: Priority.medium,
          minutes: 45,
          day: week[5],
        ),
        card(
          personal,
          'Book the dentist',
          status: TaskStatus.todo,
          priority: Priority.low,
          minutes: 10,
          day: week[1],
        ),
        card(
          learning,
          'Finish chapter 4',
          description: 'Take notes on the exercises at the end.',
          status: TaskStatus.todo,
          priority: Priority.medium,
          minutes: 90,
          day: week[2],
        ),
        card(
          learning,
          'Practice for 25 minutes',
          status: TaskStatus.todo,
          priority: Priority.low,
          minutes: 25,
          day: week[4],
        ),
      ],
    );
  }
}
