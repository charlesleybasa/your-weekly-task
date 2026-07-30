import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/task_card.dart';
import 'local_database.dart';

class CardRepository {
  CardRepository(this._db);

  final LocalDatabase _db;

  Box<String> get _box => _db.cards;

  List<TaskCard> loadAll() =>
      decodeBox(_box, TaskCard.fromJson, label: 'card');

  Future<void> upsert(TaskCard card) =>
      _box.put(card.id, jsonEncode(card.toJson()));

  /// Batched write for reorder operations, which touch many cards at once.
  Future<void> upsertAll(Iterable<TaskCard> cards) => _box.putAll({
        for (final c in cards) c.id: jsonEncode(c.toJson()),
      });

  Future<void> delete(String id) => _box.delete(id);

  Future<void> deleteAll(Iterable<String> ids) => _box.deleteAll(ids);
}
