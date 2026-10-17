import 'package:bizcat/core/errors.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The key of a calendar day cell, for tests: `rental-day-2026-11-14`.
ValueKey<String> rentalDayKey(LocalDate d) => ValueKey('rental-day-${d.toIso()}');

/// `Oktabr 2026` (capitalized month + year).
String rentalMonthTitle(LocalDate month) {
  final m = UzDates.monthFull(month.month);
  final cap = m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
  return '$cap ${month.year}';
}

/// A session-aware month calendar (port of web CalendarStep.vue).
class RentalCalendar extends StatelessWidget {
  const RentalCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.lastDay,
    required this.session,
    required this.booked,
    required this.selected,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onRetry,
  });

  /// The first of the visible month.
  final LocalDate month;
  final LocalDate today;

  /// today + horizon.
  final LocalDate lastDay;
  final RentalSession session;
  final AsyncValue<BookedDays> booked;
  final LocalDate? selected;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<LocalDate> onPick;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loading = booked.isLoading && !booked.hasValue;
    final error = booked.hasError && !booked.isLoading ? booked.error : null;
    final days = booked.value ?? const BookedDays();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BzSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Oldingi oy',
                  onPressed: canPrev ? onPrev : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    rentalMonthTitle(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Keyingi oy',
                  onPressed: canNext ? onNext : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: BzSpace.s),
            if (error != null)
              _InlineError(message: isOffline(error) ? "Internet aloqasi yo'q" : errorText(error), onRetry: onRetry)
            else
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: loading ? 0.4 : 1,
                    child: IgnorePointer(
                      ignoring: loading,
                      child: _MonthGrid(
                        month: month,
                        today: today,
                        lastDay: lastDay,
                        session: session,
                        booked: days,
                        selected: selected,
                        onPick: onPick,
                      ),
                    ),
                  ),
                  if (loading)
                    Semantics(
                      label: 'Yuklanmoqda...',
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: BzSpace.m),
            Divider(height: 1, color: scheme.outline),
            const SizedBox(height: BzSpace.m),
            const _Legend(),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.lastDay,
    required this.session,
    required this.booked,
    required this.selected,
    required this.onPick,
  });

  final LocalDate month;
  final LocalDate today;
  final LocalDate lastDay;
  final RentalSession session;
  final BookedDays booked;
  final LocalDate? selected;
  final ValueChanged<LocalDate> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = month.firstOfMonth;
    final lead = first.weekday - 1; // Monday first
    final count = first.lastOfMonth.day;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++)
        _DayCell(
          date: LocalDate(first.year, first.month, d),
          today: today,
          lastDay: lastDay,
          session: session,
          booked: booked,
          selected: selected,
          onPick: onPick,
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in UzDates.weekdaysMin)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: BzSpace.s),
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(padding: const EdgeInsets.all(2), child: cells[r * 7 + c]),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.lastDay,
    required this.session,
    required this.booked,
    required this.selected,
    required this.onPick,
  });

  final LocalDate date;
  final LocalDate today;
  final LocalDate lastDay;
  final RentalSession session;
  final BookedDays booked;
  final LocalDate? selected;
  final ValueChanged<LocalDate> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outOfRange = date.isBefore(today) || date.isAfter(lastDay);
    final taken = !outOfRange && booked.isTaken(date, session);
    final isSelected = !outOfRange && !taken && selected == date;
    final isToday = date == today;
    final enabled = !outOfRange && !taken;

    final Color bg;
    final Color fg;
    if (isSelected) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (taken) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    } else {
      bg = Colors.transparent;
      fg = outOfRange ? scheme.onSurfaceVariant.withValues(alpha: 0.45) : scheme.onSurface;
    }

    final label = '${UzDates.dayMonthYear(date)}, '
        '${taken ? 'band' : outOfRange ? 'mavjud emas' : isSelected ? 'tanlangan' : "bo'sh"}';

    return Semantics(
      button: enabled,
      enabled: enabled,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        key: rentalDayKey(date),
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BzRadius.s),
          side: isToday && !isSelected ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onPick(date) : null,
          child: Center(
            child: Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                decoration: taken ? TextDecoration.lineThrough : null,
                decorationColor: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: BzSpace.l,
      runSpacing: BzSpace.s,
      alignment: WrapAlignment.center,
      children: [
        _LegendItem(color: Colors.transparent, border: scheme.outline, label: "Bo'sh"),
        _LegendItem(color: scheme.surfaceContainerHighest, border: scheme.outline, label: 'Band'),
        _LegendItem(color: scheme.primary, label: 'Tanlangan'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: BzSpace.xs + 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(BzSpace.l),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(BzRadius.m),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(height: BzSpace.s),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: BzSpace.s),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}
