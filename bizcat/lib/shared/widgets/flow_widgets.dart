import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Step dots (done = indigo, todo = border) + `<step>-qadam / <total> · <title>`.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.total, required this.title});

  /// 1-based.
  final int step;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? scheme.primary : scheme.outline,
                    borderRadius: BorderRadius.circular(BzRadius.pill),
                  ),
                ),
              ),
              if (i < total) const SizedBox(width: BzSpace.xs),
            ],
          ],
        ),
        const SizedBox(height: BzSpace.s),
        Text('$step-qadam / $total · $title', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 40 px logo + name + subtitle, for flow and checkout tops.
class BusinessMiniHeader extends StatelessWidget {
  const BusinessMiniHeader({super.key, required this.name, this.logo, this.brandColor, this.subtitle});

  final String name;
  final String? logo;
  final String? brandColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        BizLogo(url: logo, name: name, size: 40, brandColor: brandColor),
        const SizedBox(width: BzSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

/// One label/value row of a [SummaryCard].
class SummaryRow {
  const SummaryRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;

  /// `titleMedium` with a top divider (totals).
  final bool emphasize;
}

/// White card of label (muted, left) / value (indigo bold, right) rows.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.rows});

  final List<SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.l, vertical: BzSpace.s),
        child: Column(
          children: [
            for (final r in rows) ...[
              if (r.emphasize) const Divider(height: BzSpace.l),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BzSpace.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(r.label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: BzSpace.m),
                    Flexible(
                      child: Text(
                        r.value,
                        textAlign: TextAlign.end,
                        style: (r.emphasize ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
