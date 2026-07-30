import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/focus_session.dart';
import 'local_database.dart';

class SessionRepository {
  SessionRepository(this._db);

  final LocalDatabase _db;

  Box<String> get _box => _db.sessions;

  /// Newest first — every consumer (history list, weekly report) wants that
  /// order, so sorting once here beats sorting at each call site.
  List<FocusSession> loadAll() {
    final sessions = decodeBox(_box, FocusSession.fromJson, label: 'session')
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<void> add(FocusSession session) =>
      _box.put(session.id, jsonEncode(session.toJson()));

  Future<void> deleteForTask(String taskId, Iterable<FocusSession> known) =>
      _box.deleteAll(
        known.where((s) => s.taskId == taskId).map((s) => s.id),
      );
}
