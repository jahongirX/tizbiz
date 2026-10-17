import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// '4,7' (one decimal, decimal comma).
String formatRating(double avg) => avg.toStringAsFixed(1).replaceAll('.', ',');

/// 5 stars (filled/half/empty), indigo on border color. Never apricot or gold.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.size = 16});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value.clamp(0, 5).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            v >= i ? Icons.star : (v >= i - 0.5 ? Icons.star_half : Icons.star_border),
            size: size,
            color: v >= i - 0.5 ? scheme.primary : scheme.outline,
          ),
      ],
    );
  }
}

/// `★ 4,7 (15)`; `count == 0` -> `Yangi`. Indigo star and text.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.avg, required this.count, this.compact = false});

  final double avg;
  final int count;

  /// Hides the count.
  final bool compact;

  /// The badge text without the star: '4,7 (15)', '4,7' (compact) or 'Yangi'.
  static String label(double avg, int count, {bool compact = false}) {
    if (count <= 0) return 'Yangi';
    return compact ? formatRating(avg) : '${formatRating(avg)} ($count)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final style = (compact ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)?.copyWith(color: color);
    return Semantics(
      label: count <= 0 ? 'Yangi' : '★ ${label(avg, count, compact: compact)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[Icon(Icons.star, size: compact ? 14 : 16, color: color), const SizedBox(width: 2)],
          Text(label(avg, count, compact: compact), style: style),
        ],
      ),
    );
  }
}

/// Big average, stars, `<count> ta sharh` and the 5..1 distribution bars.
class RatingSummaryView extends StatelessWidget {
  const RatingSummaryView({super.key, required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.count == 0 ? '—' : formatRating(summary.avg),
              style: theme.textTheme.displaySmall?.copyWith(fontSize: 40, fontWeight: FontWeight.w700),
            ),
            RatingStars(value: summary.avg),
            const SizedBox(height: BzSpace.xs),
            Text('${summary.count} ta sharh', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(width: BzSpace.xl),
        Expanded(
          child: Column(
            children: [
              for (var n = 5; n >= 1; n--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 14, child: Text('$n', style: theme.textTheme.labelMedium)),
                      const SizedBox(width: BzSpace.s),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(BzRadius.pill),
                          child: LinearProgressIndicator(
                            value: summary.share(n),
                            minHeight: 6,
                            color: scheme.primary,
                            backgroundColor: scheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: BzSpace.s),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${summary.distribution[n] ?? 0}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
