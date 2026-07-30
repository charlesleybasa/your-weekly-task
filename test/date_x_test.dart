import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/core/utils/date_x.dart';

void main() {
  group('DateX week boundaries', () {
    test('weekStart is the containing Monday', () {
      // 2026-07-30 is a Thursday.
      final thursday = DateTime(2026, 7, 30, 14, 33);
      expect(thursday.weekStart, DateTime(2026, 7, 27));
      expect(thursday.weekEnd, DateTime(2026, 8, 2));
    });

    test('a Monday is its own week start', () {
      final monday = DateTime(2026, 7, 27, 23, 59);
      expect(monday.weekStart, DateTime(2026, 7, 27));
    });

    test('a Sunday belongs to the week that began six days earlier', () {
      final sunday = DateTime(2026, 8, 2, 0, 1);
      expect(sunday.weekStart, DateTime(2026, 7, 27));
    });

    test('weekDays returns seven consecutive days, Monday first', () {
      final days = DateTime(2026, 7, 30).weekDays;
      expect(days, hasLength(7));
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
      for (var i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inDays, 1);
      }
    });
  });

  group('DateX.isoWeekNumber', () {
    test('matches known ISO week numbers', () {
      // 4 January is always in ISO week 1.
      expect(DateTime(2026, 1, 4).isoWeekNumber, 1);
      expect(DateTime(2026, 7, 30).isoWeekNumber, 31);
    });

    test('is stable across every day of a single week', () {
      final week = DateTime(2026, 7, 30).weekDays;
      final numbers = week.map((d) => d.isoWeekNumber).toSet();
      expect(numbers, hasLength(1));
    });
  });

  group('DateX day keys', () {
    test('dayKey is zero padded and round-trips', () {
      final date = DateTime(2026, 3, 7);
      expect(date.dayKey, '2026-03-07');
      expect(DateX.tryParseDayKey(date.dayKey), date);
    });

    test('tryParseDayKey rejects junk without throwing', () {
      expect(DateX.tryParseDayKey(null), isNull);
      expect(DateX.tryParseDayKey(''), isNull);
      expect(DateX.tryParseDayKey('not-a-date'), isNull);
    });

    test('daysUntil counts calendar days, ignoring time of day', () {
      final a = DateTime(2026, 7, 30, 23, 59);
      final b = DateTime(2026, 7, 31, 0, 1);
      expect(a.daysUntil(b), 1);
      expect(b.daysUntil(a), -1);
      expect(a.daysUntil(a), 0);
    });
  });

  group('DurationX formatting', () {
    test('clock pads minutes and seconds', () {
      expect(const Duration(minutes: 25).clock, '25:00');
      expect(const Duration(seconds: 9).clock, '00:09');
      expect(const Duration(hours: 1, minutes: 5).clock, '1:05:00');
    });

    test('compact reads naturally at each scale', () {
      expect(const Duration(seconds: 45).compact, '45s');
      expect(const Duration(minutes: 45).compact, '45m');
      expect(const Duration(hours: 2).compact, '2h');
      expect(const Duration(hours: 1, minutes: 30).compact, '1h 30m');
    });
  });
}
