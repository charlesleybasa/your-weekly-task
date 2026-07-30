import 'dart:convert';

import '../models/focus_session.dart';
import '../models/user_stats.dart';
import 'local_database.dart';

/// Persists the two singletons that must survive a cold start: the player's
/// progression and any timer that was running when the app closed.
class StatsRepository {
  StatsRepository(this._db);

  final LocalDatabase _db;

  UserStats loadStats() {
    final json = decodeMeta(_db.meta, MetaKeys.stats);
    return json == null ? UserStats.empty : UserStats.fromJson(json);
  }

  Future<void> saveStats(UserStats stats) =>
      _db.meta.put(MetaKeys.stats, jsonEncode(stats.toJson()));

  ActiveTimer? loadActiveTimer() {
    final json = decodeMeta(_db.meta, MetaKeys.activeTimer);
    return json == null ? null : ActiveTimer.fromJson(json);
  }

  Future<void> saveActiveTimer(ActiveTimer? timer) => timer == null
      ? _db.meta.delete(MetaKeys.activeTimer)
      : _db.meta.put(MetaKeys.activeTimer, jsonEncode(timer.toJson()));

  Future<void> resetStats() => saveStats(UserStats.empty);
}
