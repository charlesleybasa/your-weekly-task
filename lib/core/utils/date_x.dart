import 'package:intl/intl.dart';

/// Date helpers. The whole app treats a "day" as a local midnight-anchored
/// [DateTime]; storing anything else makes week maths and streaks unreliable.
extension DateX on DateTime {
  /// Midnight local time, the canonical key for a day.
  DateTime get dayStart => DateTime(year, month, day);

  DateTime get dayEnd => DateTime(year, month, day, 23, 59, 59, 999);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());

  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));

  /// Monday 00:00 of the containing week. ISO-8601 week convention.
  DateTime get weekStart {
    final d = dayStart;
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  /// The seven days of the containing week, Monday first.
  List<DateTime> get weekDays {
    final start = weekStart;
    return List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// ISO-8601 week number (1–53).
  int get isoWeekNumber {
    // Thursday of the current week determines the ISO year.
    final thursday = weekStart.add(const Duration(days: 3));
    final firstThursday = DateTime(thursday.year, 1, 4).weekStart
        .add(const Duration(days: 3));
    // Use UTC-normalised difference so DST transitions cannot shift the count.
    final diff = DateTime.utc(thursday.year, thursday.month, thursday.day)
        .difference(
          DateTime.utc(
            firstThursday.year,
            firstThursday.month,
            firstThursday.day,
          ),
        )
        .inDays;
    return (diff ~/ 7) + 1;
  }

  /// Whole days between two calendar dates, DST-safe.
  int daysUntil(DateTime other) =>
      DateTime.utc(other.year, other.month, other.day)
          .difference(DateTime.utc(year, month, day))
          .inDays;

  /// Stable key for map lookups and persistence: `2026-07-30`.
  String get dayKey =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  String get weekKey => weekStart.dayKey;

  // ---- Formatting ----
  String get shortDayName => DateFormat.E().format(this); // Mon
  String get fullDayName => DateFormat.EEEE().format(this); // Monday
  String get dayNumber => DateFormat.d().format(this); // 30
  String get monthShort => DateFormat.MMM().format(this); // Jul
  String get monthDay => DateFormat.MMMd().format(this); // Jul 30
  String get timeOfDayLabel => DateFormat.jm().format(this); // 4:05 PM

  /// "Today" / "Yesterday" / "Jul 30" — used in activity feeds.
  String get relativeDayLabel {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    final delta = DateTime.now().dayStart.daysUntil(dayStart);
    if (delta == 1) return 'Tomorrow';
    if (delta > 1 && delta < 7) return fullDayName;
    return monthDay;
  }

  static DateTime? tryParseDayKey(String? key) {
    if (key == null || key.isEmpty) return null;
    return DateTime.tryParse(key)?.dayStart;
  }
}

extension DurationX on Duration {
  /// `25:00` or `1:05:00` — the timer readout.
  String get clock {
    final h = inHours;
    final m = inMinutes.remainder(60);
    final s = inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// `45m`, `1h 30m`, `2h` — compact human label for estimates and totals.
  String get compact {
    if (inMinutes < 1) return '${inSeconds}s';
    final h = inHours;
    final m = inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Decimal hours, for statistics ("4.2 hours focused").
  double get hoursDecimal => inSeconds / 3600.0;
}
