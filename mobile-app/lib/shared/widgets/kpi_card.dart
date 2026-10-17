import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

/// One KPI tile: label, big value, optional sub line, icon and tone colour.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.sub, this.icon, this.tone});

  final String label;
  final String value;
  final String? sub;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final color = tone ?? c.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 6)],
                Expanded(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t.titleLarge?.copyWith(color: c.text)),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
