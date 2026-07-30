import 'package:flutter/foundation.dart';

import '../utils/date_x.dart';
import 'enums.dart';

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.label,
    this.done = false,
  });

  final String id;
  final String label;
  final bool done;

  ChecklistItem copyWith({String? label, bool? done}) => ChecklistItem(
        id: id,
        label: label ?? this.label,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'done': done};

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        done: json['done'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          other.id == id &&
          other.label == label &&
          other.done == done;

  @override
  int get hashCode => Object.hash(id, label, done);
}

/// A task card. This is the central record of the app: it lives in a board,
/// occupies one of three columns, may be scheduled to a weekday, and carries
/// the focus/XP bookkeeping needed by the gamification layer.
@immutable
class TaskCard {
  const TaskCard({
    required this.id,
    required this.boardId,
    required this.title,
    required this.status,
    required this.priority,
    required this.estimatedMinutes,
    required this.sortIndex,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.notes = '',
    this.scheduledDayKey,
    this.tags = const <String>[],
    this.checklist = const <ChecklistItem>[],
    this.attachments = const <String>[],
    this.focusedSeconds = 0,
    this.completedSessions = 0,
    this.completedAt,
    this.startedAt,
    this.xpAwarded = 0,
  });

  final String id;
  final String boardId;
  final String title;
  final String description;
  final String notes;

  final TaskStatus status;
  final Priority priority;

  /// Planned effort. Drives the XP bucket and pre-fills the timer.
  final int estimatedMinutes;

  /// Position within its column. Rewritten on drag-reorder.
  final int sortIndex;

  /// `yyyy-MM-dd` of the assigned weekday, or null for unscheduled.
  final String? scheduledDayKey;

  final List<String> tags;
  final List<ChecklistItem> checklist;

  /// File paths / URIs. Nothing reads these yet — the field exists so the
  /// storage schema does not need a migration when attachments ship.
  final List<String> attachments;

  /// Total focused time accumulated across every session on this card.
  final int focusedSeconds;
  final int completedSessions;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// XP already granted for this card, so re-completing a re-opened card
  /// cannot farm the same reward twice.
  final int xpAwarded;

  DateTime? get scheduledDay => DateX.tryParseDayKey(scheduledDayKey);

  Duration get estimate => Duration(minutes: estimatedMinutes);
  Duration get focused => Duration(seconds: focusedSeconds);

  TaskSize get size => TaskSize.fromMinutes(estimatedMinutes);

  /// Base reward before streak/focus bonuses.
  int get baseXp => size.baseXp;

  bool get isDone => status.isDone;
  bool get isScheduled => scheduledDayKey != null;

  bool get hasChecklist => checklist.isNotEmpty;

  int get checklistDone => checklist.where((i) => i.done).length;

  double get checklistProgress =>
      checklist.isEmpty ? 0 : checklistDone / checklist.length;

  bool isScheduledOn(DateTime day) => scheduledDayKey == day.dayKey;

  /// Ranking used by "what should I focus on next". Started work outranks
  /// fresh work, then priority, then whatever is scheduled soonest.
  int get focusRank {
    var score = 0;
    if (status == TaskStatus.started) score += 1000;
    score += priority.weight * 100;
    final day = scheduledDay;
    if (day != null) {
      final delta = DateTime.now().dayStart.daysUntil(day);
      // Today is worth the most; overdue is close behind; far future decays.
      score += delta <= 0 ? 60 - delta.abs().clamp(0, 20) : (40 - delta).clamp(0, 40);
    }
    return score;
  }

  TaskCard copyWith({
    String? boardId,
    String? title,
    String? description,
    String? notes,
    TaskStatus? status,
    Priority? priority,
    int? estimatedMinutes,
    int? sortIndex,
    Object? scheduledDayKey = _sentinel,
    List<String>? tags,
    List<ChecklistItem>? checklist,
    List<String>? attachments,
    int? focusedSeconds,
    int? completedSessions,
    DateTime? updatedAt,
    Object? startedAt = _sentinel,
    Object? completedAt = _sentinel,
    int? xpAwarded,
  }) {
    return TaskCard(
      id: id,
      boardId: boardId ?? this.boardId,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      sortIndex: sortIndex ?? this.sortIndex,
      scheduledDayKey: scheduledDayKey == _sentinel
          ? this.scheduledDayKey
          : scheduledDayKey as String?,
      tags: tags ?? this.tags,
      checklist: checklist ?? this.checklist,
      attachments: attachments ?? this.attachments,
      focusedSeconds: focusedSeconds ?? this.focusedSeconds,
      completedSessions: completedSessions ?? this.completedSessions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      startedAt: startedAt == _sentinel ? this.startedAt : startedAt as DateTime?,
      completedAt:
          completedAt == _sentinel ? this.completedAt : completedAt as DateTime?,
      xpAwarded: xpAwarded ?? this.xpAwarded,
    );
  }

  /// Status change with the timestamp bookkeeping the statistics layer relies
  /// on. Kept here so no call site can move a card and forget to stamp it.
  TaskCard withStatus(TaskStatus next) {
    final now = DateTime.now();
    return copyWith(
      status: next,
      updatedAt: now,
      startedAt: next == TaskStatus.started && startedAt == null
          ? now
          : (next == TaskStatus.todo ? null : startedAt),
      completedAt: next.isDone ? now : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'boardId': boardId,
        'title': title,
        'description': description,
        'notes': notes,
        'status': status.name,
        'priority': priority.name,
        'estimatedMinutes': estimatedMinutes,
        'sortIndex': sortIndex,
        'scheduledDayKey': scheduledDayKey,
        'tags': tags,
        'checklist': checklist.map((i) => i.toJson()).toList(),
        'attachments': attachments,
        'focusedSeconds': focusedSeconds,
        'completedSessions': completedSessions,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'xpAwarded': xpAwarded,
      };

  factory TaskCard.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return TaskCard(
      id: json['id'] as String,
      boardId: json['boardId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled task',
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: TaskStatus.fromName(json['status'] as String?),
      priority: Priority.fromName(json['priority'] as String?),
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 25,
      sortIndex: json['sortIndex'] as int? ?? 0,
      scheduledDayKey: json['scheduledDayKey'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      checklist: (json['checklist'] as List?)
              ?.map((e) => ChecklistItem.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          const <ChecklistItem>[],
      attachments:
          (json['attachments'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[],
      focusedSeconds: json['focusedSeconds'] as int? ?? 0,
      completedSessions: json['completedSessions'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      xpAwarded: json['xpAwarded'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCard &&
          other.id == id &&
          other.boardId == boardId &&
          other.title == title &&
          other.description == description &&
          other.notes == notes &&
          other.status == status &&
          other.priority == priority &&
          other.estimatedMinutes == estimatedMinutes &&
          other.sortIndex == sortIndex &&
          other.scheduledDayKey == scheduledDayKey &&
          listEquals(other.tags, tags) &&
          listEquals(other.checklist, checklist) &&
          listEquals(other.attachments, attachments) &&
          other.focusedSeconds == focusedSeconds &&
          other.completedSessions == completedSessions &&
          other.updatedAt == updatedAt &&
          other.startedAt == startedAt &&
          other.completedAt == completedAt &&
          other.xpAwarded == xpAwarded;

  @override
  int get hashCode => Object.hash(
        id,
        boardId,
        title,
        status,
        priority,
        estimatedMinutes,
        sortIndex,
        scheduledDayKey,
        Object.hashAll(tags),
        Object.hashAll(checklist),
        focusedSeconds,
        completedSessions,
        updatedAt,
        completedAt,
        xpAwarded,
      );
}

const Object _sentinel = Object();
