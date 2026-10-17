import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/shared/widgets/star_rating.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Big average, stars, "N ta sharh" and 5..1 distribution bars.
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({super.key, required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  summary.count == 0 ? '—' : summary.avg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                ),
                StarRating(value: summary.avg, size: 18),
                const SizedBox(height: 4),
                Text('${summary.count} ta sharh', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (var s = 5; s >= 1; s--)
                    Padding(
                      key: ValueKey('rating-bar-$s'),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 12, child: Text('$s', style: TextStyle(fontSize: 12, color: c.textMuted))),
                          const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: summary.share(s),
                                minHeight: 6,
                                color: AppColors.star,
                                backgroundColor: c.surface2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${summary.distribution[s] ?? 0}',
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 12, color: c.textMuted),
                            ),
                          ),
                        ],
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
