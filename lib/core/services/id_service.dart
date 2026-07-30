import 'package:uuid/uuid.dart';

/// Single id source. v4 UUIDs — ids must be stable across devices for a future
/// export/import round-trip, so nothing derived from local counters.
abstract final class Ids {
  static const _uuid = Uuid();

  static String next() => _uuid.v4();
}
