import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Report period presets (relative to the business-local today).
enum PeriodPreset {
  today('Bugun'),
  week('Bu hafta'),
  month('Bu oy'),
  last7('7 kun'),
  last30('30 kun'),
  last90('90 kun'),
  prevMonth("O'tgan oy"),
  custom('Boshqa davr');

  const PeriodPreset(this.label);

  final String label;

  /// The range of a preset: today; week = Monday..today; month = 1st..today; lastN = today-(N-1)..today;
  /// prevMonth = the whole previous month. [custom] returns today..today (pick a range instead).
  DateRangeValue range(LocalDate today) {
    final (from, to) = switch (this) {
      PeriodPreset.today => (today, today),
      PeriodPreset.week => (today.mondayOfWeek, today),
      PeriodPreset.month => (today.firstOfMonth, today),
      PeriodPreset.last7 => (today.addDays(-6), today),
      PeriodPreset.last30 => (today.addDays(-29), today),
      PeriodPreset.last90 => (today.addDays(-89), today),
      PeriodPreset.prevMonth => (today.firstOfMonth.addMonths(-1), today.firstOfMonth.addDays(-1)),
      PeriodPreset.custom => (today, today),
    };
    return DateRangeValue(from: from, to: to, preset: this);
  }
}

/// A closed range of business-local days plus the preset it came from.
@immutable
final class DateRangeValue {
  const DateRangeValue({required this.from, required this.to, this.preset = PeriodPreset.custom});

  factory DateRangeValue.preset(PeriodPreset preset, LocalDate today) => preset.range(today);

  final LocalDate from;
  final LocalDate to;
  final PeriodPreset preset;

  /// Number of days, inclusive.
  int get days => from.daysUntil(to) + 1;

  /// Record for provider family keys: `({LocalDate from, LocalDate to})`.
  ({LocalDate from, LocalDate to}) get key => (from: from, to: to);

  /// '17 okt – 24 okt' (or one day '17 okt').
  String get label =>
      from == to ? UzDates.dayMonthShort(from) : '${UzDates.dayMonthShort(from)} – ${UzDates.dayMonthShort(to)}';

  @override
  bool operator ==(Object other) =>
      other is DateRangeValue && other.from == from && other.to == to && other.preset == preset;

  @override
  int get hashCode => Object.hash(from, to, preset);

  @override
  String toString() => 'DateRangeValue(${from.toIso()}..${to.toIso()}, ${preset.name})';
}

/// Horizontal chips of [presets]; [PeriodPreset.custom] opens a date range picker (max [maxDays]).
class PeriodChips extends ConsumerWidget {
  const PeriodChips({
    super.key,
    required this.value,
    required this.presets,
    required this.onChanged,
    this.maxDays = 366,
  });

  final DateRangeValue value;
  final List<PeriodPreset> presets;
  final ValueChanged<DateRangeValue> onChanged;
  final int maxDays;

  Future<void> _pickCustom(BuildContext context, LocalDate today) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 3),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(value.from.year, value.from.month, value.from.day),
        end: DateTime(value.to.year, value.to.month, value.to.day),
      ),
      locale: const Locale('uz'),
      helpText: 'Davrni tanlang',
      saveText: 'Tanlash',
    );
    if (picked == null || !context.mounted) return;
    final range = DateRangeValue(
      from: LocalDate.fromDateTime(picked.start),
      to: LocalDate.fromDateTime(picked.end),
    );
    if (range.days > maxDays) {
      showAppSnack(context, 'Davr $maxDays kundan oshmasligi kerak', error: true);
      return;
    }
    onChanged(range);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = bizToday(ref.read(clockProvider), ref.watch(activeBusinessProvider));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final p in presets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p == PeriodPreset.custom && value.preset == PeriodPreset.custom ? value.label : p.label),
                selected: value.preset == p,
                onSelected: (_) {
                  if (p == PeriodPreset.custom) {
                    _pickCustom(context, today);
                  } else {
                    onChanged(p.range(today));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
