import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Greeting, date and today's counters (from /v1/me/stats today).
class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.firstName,
    required this.today,
    required this.stats,
    required this.timezone,
  });

  final String firstName;
  final LocalDate today;

  /// Null while loading or on error.
  final MeStats? stats;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = stats;
    final next = s?.todayNextAt;
    final nextText = s == null
        ? ''
        : next == null
            ? "Bugun boshqa yozuv yo'q"
            : 'Keyingi: ${Dates.toBizLocal(next, timezone).hhmm}';
    Widget counter(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(firstName.isEmpty ? 'Salom' : 'Salom, $firstName', style: Theme.of(context).textTheme.titleLarge),
          Text(UzDates.weekdayDayMonth(today), style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 12),
          Row(
            children: [
              counter('Bugun', s == null ? '—' : '${s.todayTotal} ta'),
              const SizedBox(width: 8),
              counter('Yakunlandi', s == null ? '—' : '${s.todayCompleted} ta'),
              const SizedBox(width: 8),
              counter('Bugungi daromadim', s == null ? '—' : Money.compact(s.earningsTiyin)),
            ],
          ),
          if (nextText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: c.textMuted),
                const SizedBox(width: 6),
                Text(nextText),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
