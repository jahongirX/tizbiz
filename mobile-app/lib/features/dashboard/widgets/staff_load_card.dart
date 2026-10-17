import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Xodimlar yuki": appointments and revenue per staff member.
class StaffLoadCard extends StatelessWidget {
  const StaffLoadCard({super.key, required this.rows});

  final List<StaffLoadRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SectionCard(
      title: 'Xodimlar yuki',
      child: rows.isEmpty
          ? Text("Bu davrda ma'lumot yo'q", style: TextStyle(color: c.textMuted))
          : Column(
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: c.primarySoft,
                          child: Text(
                            r.name.isEmpty ? '?' : r.name.characters.first.toUpperCase(),
                            style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${r.count} ta', style: TextStyle(color: c.textMuted, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text(Money.format(r.revenueTiyin), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
