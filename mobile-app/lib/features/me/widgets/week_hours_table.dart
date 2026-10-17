import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// '09:00 – 13:00, 14:00 – 20:00' of one ISO weekday, or null when it is a day off.
String? weekdayIntervals(List<WorkingHours> hours, int weekday) {
  final rows = [for (final h in hours) if (h.weekday == weekday) h]
    ..sort((a, b) => a.start.minutesOfDay.compareTo(b.start.minutesOfDay));
  if (rows.isEmpty) return null;
  return rows.map((h) => '${h.start.format()} – ${h.end.format()}').join(', ');
}

/// Dushanba..Yakshanba with the working intervals; today's row highlighted.
class WeekHoursTable extends StatelessWidget {
  const WeekHoursTable({super.key, required this.hours, required this.todayWeekday});

  final List<WorkingHours> hours;
  final int todayWeekday;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        for (var wd = 1; wd <= 7; wd++)
          Builder(builder: (context) {
            final text = weekdayIntervals(hours, wd);
            final isToday = wd == todayWeekday;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isToday ? c.primarySoft : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(UzDates.weekdayLong(wd),
                        style: TextStyle(fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  Expanded(
                    child: Text(
                      text ?? 'Dam olish kuni',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: text == null ? c.textMuted : c.text),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
