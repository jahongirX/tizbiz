import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// '#F59E0B' / 'F59E0B' -> Color; null when not a 6/8-digit hex.
Color? parseHexColor(String? hex) {
  final h = hex?.trim().replaceFirst('#', '') ?? '';
  if (h.length != 6 && h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(h.length == 6 ? 0xFF000000 | v : v);
}

/// Small chip with a colour dot for a client category.
class CategoryDotChip extends StatelessWidget {
  const CategoryDotChip({super.key, required this.category});

  final ClientCategory category;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = parseHexColor(category.color) ?? c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(category.name, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// One row of the clients list.
class ClientTile extends ConsumerWidget {
  const ClientTile({super.key, required this.client, this.onTap});

  final Client client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final cl = client;
    final today = bizToday(ref.read(clockProvider), a);
    final stats = ['${cl.visits ?? 0} tashrif', if (cl.spentTiyin != null) Money.compact(cl.spentTiyin!)].join(' · ');
    final last = cl.lastVisit == null
        ? null
        : 'Oxirgi tashrif: ${UzDates.dayLabel(Dates.localDateOf(cl.lastVisit!, a?.timezone), today: today)}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: c.primarySoft,
        foregroundColor: c.primary,
        child: Text(cl.name.trim().isEmpty ? '?' : cl.name.trim()[0].toUpperCase()),
      ),
      title: Text(cl.name, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Phone.format(cl.phone)),
          Text(stats, style: t.bodySmall?.copyWith(color: c.textMuted)),
          if (last != null) Text(last, style: t.bodySmall?.copyWith(color: c.textMuted)),
          if (cl.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final cat in cl.categories) CategoryDotChip(category: cat)],
              ),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
