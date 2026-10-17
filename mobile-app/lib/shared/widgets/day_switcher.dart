import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// `‹  Shanba, 17 oktabr  ›` with a "Bugun" chip and a calendar button.
class DaySwitcher extends StatelessWidget {
  const DaySwitcher({super.key, required this.date, required this.today, required this.onChanged});

  final LocalDate date;
  final LocalDate today;
  final ValueChanged<LocalDate> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 2, 12, 31),
      locale: const Locale('uz'),
    );
    if (picked != null) onChanged(LocalDate.fromDateTime(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isToday = date == today;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Oldingi kun',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(date.addDays(-1)),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pick(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  UzDates.weekdayDayMonth(date),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Keyingi kun',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(date.addDays(1)),
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            label: const Text('Bugun'),
            selected: isToday,
            onSelected: isToday ? null : (_) => onChanged(today),
          ),
          IconButton(
            tooltip: 'Sanani tanlash',
            icon: Icon(Icons.calendar_month_outlined, color: c.textMuted),
            onPressed: () => _pick(context),
          ),
        ],
      ),
    );
  }
}
