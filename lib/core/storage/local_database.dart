import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box names. Records are stored as JSON strings rather than through generated
/// type adapters: the schema stays inspectable, migrations are ordinary Dart,
/// and the build has no code-generation step to keep in sync.
abstract final class Boxes {
  static const boards = 'boards_v1';
  static const cards = 'cards_v1';
  static const sessions = 'sessions_v1';

  /// Singletons: user stats, the active timer, schema version.
  static const meta = 'meta_v1';

  static const all = <String>[boards, cards, sessions, meta];
}

abstract final class MetaKeys {
  static const stats = 'user_stats';
  static const activeTimer = 'active_timer';
  static const schemaVersion = 'schema_version';
  static const seeded = 'seeded';
}

/// Opens and owns the Hive boxes.
///
/// Everything is opened once during startup so that no screen ever awaits a
/// box — reads are synchronous, which is what makes "no loading screens"
/// achievable.
class LocalDatabase {
  LocalDatabase._();

  static const int currentSchemaVersion = 1;

  static LocalDatabase? _instance;
  static LocalDatabase get instance {
    final db = _instance;
    if (db == null) {
      throw StateError('LocalDatabase.open() must complete before use.');
    }
    return db;
  }

  late final Box<String> boards;
  late final Box<String> cards;
  late final Box<String> sessions;
  late final Box<String> meta;

  static Future<LocalDatabase> open() async {
    if (_instance != null) return _instance!;

    await Hive.initFlutter();
    final db = LocalDatabase._();

    db.boards = await Hive.openBox<String>(Boxes.boards);
    db.cards = await Hive.openBox<String>(Boxes.cards);
    db.sessions = await Hive.openBox<String>(Boxes.sessions);
    db.meta = await Hive.openBox<String>(Boxes.meta);

    await db._migrate();

    _instance = db;
    return db;
  }

  Future<void> _migrate() async {
    final stored = int.tryParse(meta.get(MetaKeys.schemaVersion) ?? '') ?? 0;
    if (stored == currentSchemaVersion) return;

    // v0 → v1 is the initial install; future versions add cases here and
    // rewrite records in place before bumping the stored version.
    if (stored > currentSchemaVersion && kDebugMode) {
      debugPrint(
        'Momentum: data was written by a newer build '
        '(v$stored > v$currentSchemaVersion). Leaving it untouched.',
      );
      return;
    }

    await meta.put(MetaKeys.schemaVersion, currentSchemaVersion.toString());
  }

  /// Wipes user content. Settings live in SharedPreferences and survive.
  Future<void> clearAll() async {
    await Future.wait([
      boards.clear(),
      cards.clear(),
      sessions.clear(),
      meta.clear(),
    ]);
    await meta.put(MetaKeys.schemaVersion, currentSchemaVersion.toString());
  }

  Future<void> close() => Hive.close();
}

/// Decodes every value in a box, skipping records that fail to parse.
///
/// A single corrupt row should cost the user that row, not the whole board —
/// so failures are logged and dropped rather than thrown.
List<T> decodeBox<T>(
  Box<String> box,
  T Function(Map<String, dynamic>) fromJson, {
  String? label,
}) {
  final out = <T>[];
  for (final key in box.keys) {
    final raw = box.get(key);
    if (raw == null) continue;
    try {
      out.add(fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Momentum: dropped unreadable ${label ?? T} "$key": $e');
      }
    }
  }
  return out;
}

Map<String, dynamic>? decodeMeta(Box<String> box, String key) {
  final raw = box.get(key);
  if (raw == null) return null;
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
