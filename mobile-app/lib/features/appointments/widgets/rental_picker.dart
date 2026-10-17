import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Rental session choice: a [RentalSession] or the full day (null).
typedef RentalChoice = ({RentalSession? session});

/// Date strip with booked-day marks (fully booked days disabled, partly booked days dotted) and
/// the session selector "Ertalab / Kechqurun / Kun bo'yi" with taken sessions disabled.
class RentalPicker extends ConsumerWidget {
  const RentalPicker({
    super.key,
    required this.slug,
    required this.today,
    required this.date,
    required this.choice,
    required this.onDate,
    required this.onChoice,
    this.errorMessage,
  });

  final String slug;
  final LocalDate today;
  final LocalDate date;

  /// null = not chosen yet.
  final RentalChoice? choice;
  final ValueChanged<LocalDate> onDate;
  final ValueChanged<RentalChoice> onChoice;
  final String? errorMessage;

  static const int days = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final value = ref.watch(bookedDaysProvider(slug));
    final booked = value.value ?? const BookedDays();
    bool taken(RentalSession? s) => booked.isTaken(date, s);
    Future<void> openCalendar() async {
      final picked = await showDatePicker(
        context: context,
        locale: const Locale('uz'),
        initialDate: date.toUtcMidnight(),
        firstDate: today.toUtcMidnight(),
        lastDate: today.addDays(days).toUtcMidnight(),
        selectableDayPredicate: (d) => !booked.isFullyBooked(LocalDate.fromDateTime(d)),
      );
      if (picked != null) onDate(LocalDate.fromDateTime(picked));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(UzDates.weekdayDayMonth(date), style: t.titleSmall)),
            IconButton(tooltip: 'Kalendar', onPressed: openCalendar, icon: const Icon(Icons.calendar_month_outlined)),
          ],
        ),
        if (value.isLoading && !value.hasValue) const LinearProgressIndicator(minHeight: 2),
        if (value.hasError && !value.hasValue)
          Text("Band kunlar yuklanmadi. Saqlashda server tekshiradi.", style: t.bodySmall?.copyWith(color: c.warning)),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final d = today.addDays(i);
              final full = booked.isFullyBooked(d);
              final partly = !full && (booked.booked[d]?.isNotEmpty ?? false);
              final selected = d == date;
              return Semantics(
                selected: selected,
                label:
                    '${UzDates.dayMonth(d)}${full
                        ? ', band'
                        : partly
                        ? ', qisman band'
                        : ''}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: full ? null : () => onDate(d),
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(
                      color: selected ? c.primary : (full ? c.surface2 : c.surface),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? c.primary : c.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          UzDates.weekdayMin(d.weekday),
                          style: t.labelSmall?.copyWith(color: selected ? Colors.white : c.textMuted),
                        ),
                        Text(
                          '${d.day}',
                          style: t.titleSmall?.copyWith(
                            color: selected ? Colors.white : (full ? c.textMuted : c.text),
                            decoration: full ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                          child: partly
                              ? Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle),
                                  ),
                                )
                              : Text(
                                  UzDates.monthShort(d.month),
                                  style: t.labelSmall?.copyWith(
                                    fontSize: 8,
                                    color: selected ? Colors.white : c.textMuted,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text('Seans', style: t.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in [RentalSession.morning, RentalSession.evening, null])
              ChoiceChip(
                label: Text(s?.label ?? "Kun bo'yi"),
                selected: choice != null && choice!.session == s,
                onSelected: taken(s) ? null : (_) => onChoice((session: s)),
              ),
          ],
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(errorMessage!, style: t.bodySmall?.copyWith(color: c.danger)),
          ),
      ],
    );
  }
}
