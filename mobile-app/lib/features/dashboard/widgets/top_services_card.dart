import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Top xizmatlar": up to 10 rows with a bar proportional to revenue.
class TopServicesCard extends StatelessWidget {
  const TopServicesCard({super.key, required this.rows});

  final List<TopServiceRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = rows.take(10).toList();
    final max = top.fold<int>(0, (m, r) => r.revenueTiyin > m ? r.revenueTiyin : m);
    return SectionCard(
      title: 'Top xizmatlar',
      child: top.isEmpty
          ? Text("Bu davrda xizmatlar yo'q", style: TextStyle(color: c.textMuted))
          : Column(
              children: [
                for (final r in top)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${r.count} ta', style: TextStyle(color: c.textMuted, fontSize: 12)),
                            const SizedBox(width: 12),
                            Text(Money.format(r.revenueTiyin), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: max <= 0 ? 0 : r.revenueTiyin / max,
                            minHeight: 6,
                            color: c.primary,
                            backgroundColor: c.surface2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
