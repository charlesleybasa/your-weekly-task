import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/board.dart';
import 'local_database.dart';

class BoardRepository {
  BoardRepository(this._db);

  final LocalDatabase _db;

  Box<String> get _box => _db.boards;

  /// Synchronous read — the box is already open by the time any screen builds.
  List<Board> loadAll() {
    final boards = decodeBox(_box, Board.fromJson, label: 'board')
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return boards;
  }

  Future<void> upsert(Board board) =>
      _box.put(board.id, jsonEncode(board.toJson()));

  Future<void> upsertAll(Iterable<Board> boards) => _box.putAll({
        for (final b in boards) b.id: jsonEncode(b.toJson()),
      });

  Future<void> delete(String id) => _box.delete(id);

  bool get isEmpty => _box.isEmpty;
}
