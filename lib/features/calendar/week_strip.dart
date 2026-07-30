import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../state/cards_controller.dart';
import '../../widgets/pressable.dart';

/// The seven-day strip. There is no month view anywhere in the app — a week is
/// the only planning horizon, and offering a month would quietly invite the
/// endless backlog the product is built to avoid.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.onSelect,
    this.compact = false,
  });

  final DateTime weekStart;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final days = weekStart.weekDays;
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DayCell(
                day: day,
                selected: selectedDay != null && selectedDay!.isSameDay(day),
                compact: compact,
                onTap: () => onSelect(day),
              ),
            ),
          ),
      ],
    );
  }
}

/// Locale-safe truncation: some locales abbreviate weekday names to fewer than
/// three characters, so a blind `substring(0, 3)` would throw.
String _abbreviate(String value, int max) =>
    value.length <= max ? value : value.substring(0, max);

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final motion = context.motion;
    final (total, done) = ref.watch(dayTallyProvider(day.dayKey));
    final isToday = day.isToday;
    final allDone = total > 0 && done == total;

    final fg = selected
        ? colors.onPrimary
        : isToday
            ? colors.primaryText
            : colors.textPrimary;

    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brMd,
      minSize: 48,
      semanticLabel: '${day.fullDayName} ${day.dayNumber}, '
          '$total task${total == 1 ? '' : 's'}, $done done'
          '${isToday ? ', today' : ''}',
      child: AnimatedContainer(
        duration: motion.base,
        curve: motion.decelerate,
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : isToday
                  ? colors.primarySoft
                  : colors.surface,
          borderRadius: AppGeometry.brMd,
          border: Border.all(
            color: selected
                ? colors.primary
                : isToday
                    ? colors.primary.withValues(alpha: 0.45)
                    : colors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _abbreviate(day.shortDayName, compact ? 1 : 3),
              style: context.text.labelSmall?.copyWith(
                color: selected
                    ? colors.onPrimary.withValues(alpha: 0.85)
                    : colors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              day.dayNumber,
              style: (compact ? context.text.titleMedium : context.text.titleLarge)
                  ?.copyWith(color: fg),
            ),
            const SizedBox(height: 5),
            // Task load indicator. Uses shape as well as colour — a filled
            // check for a cleared day, dots for outstanding work.
            SizedBox(
              height: 8,
              child: total == 0
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (selected ? colors.onPrimary : colors.border)
                            .withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                    )
                  : allDone
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 9,
                          color: selected ? colors.onPrimary : colors.success,
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < (total > 3 ? 3 : total); i++)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colors.onPrimary
                                      : i < done
                                          ? colors.success
                                          : colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
