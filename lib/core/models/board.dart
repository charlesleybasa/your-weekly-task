import 'package:flutter/material.dart';

import 'enums.dart';

/// A kanban board. Boards own no cards directly — cards reference a board by id
/// so that moving a card never rewrites a board record.
@immutable
class Board {
  const Board({
    required this.id,
    required this.title,
    required this.description,
    required this.colorValue,
    required this.iconKey,
    required this.sortIndex,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  final String id;
  final String title;
  final String description;

  /// Stored as an int so the record is trivially JSON-encodable.
  final int colorValue;
  final String iconKey;

  /// Manual ordering from drag-to-reorder on the boards grid.
  final int sortIndex;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;

  Color get color => Color(colorValue);
  IconData get icon => BoardIcons.resolve(iconKey);

  Board copyWith({
    String? title,
    String? description,
    int? colorValue,
    String? iconKey,
    int? sortIndex,
    DateTime? updatedAt,
    bool? archived,
  }) {
    return Board(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'sortIndex': sortIndex,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'archived': archived,
      };

  factory Board.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Board(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF4F7CFF,
      iconKey: json['iconKey'] as String? ?? BoardIcons.fallbackKey,
      sortIndex: json['sortIndex'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      archived: json['archived'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Board &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.colorValue == colorValue &&
          other.iconKey == iconKey &&
          other.sortIndex == sortIndex &&
          other.archived == archived &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        colorValue,
        iconKey,
        sortIndex,
        archived,
        updatedAt,
      );
}

/// Derived counters for a board. Computed once per card-index rebuild rather
/// than per widget build, so a 100-board grid stays cheap.
@immutable
class BoardStats {
  const BoardStats({
    required this.total,
    required this.todo,
    required this.started,
    required this.done,
  });

  static const empty = BoardStats(total: 0, todo: 0, started: 0, done: 0);

  final int total;
  final int todo;
  final int started;
  final int done;

  /// 0.0–1.0. An empty board reports 0 rather than 1 — "100% of nothing" would
  /// read as a finished board on the dashboard.
  double get completion => total == 0 ? 0 : done / total;

  int get remaining => total - done;
  bool get isComplete => total > 0 && done == total;
}
