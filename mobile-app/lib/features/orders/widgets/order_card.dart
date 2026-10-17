import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Napoleon torti ×2", first [max] items, plus "+N ta".
String orderItemsSummary(Order o, {int max = 3}) {
  final shown = [for (final i in o.items.take(max)) '${i.name} ×${i.qty}'];
  final total = o.itemsCount > o.items.length ? o.itemsCount : o.items.length;
  final more = total - shown.length;
  return [...shown, if (more > 0) '+$more ta'].join(', ');
}

/// One order on the board.
class OrderCard extends ConsumerWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onNext,
    required this.onPickStatus,
    this.busy = false,
  });

  final Order order;
  final VoidCallback onTap;
  final VoidCallback onNext;
  final VoidCallback onPickStatus;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final o = order;
    final today = bizToday(ref.read(clockProvider), a);
    final created = o.createdAt == null
        ? null
        : UzDates.dateTime(Dates.toBizLocal(o.createdAt!, a?.timezone), today: today);
    final next = o.status.next;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('#${o.id}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (o.customerName ?? '').isEmpty ? 'Mijoz' : o.customerName!,
                      style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Amallar',
                    enabled: !busy,
                    onSelected: (_) => onPickStatus(),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'status', child: Text("Holatni o'zgartirish"))],
                  ),
                ],
              ),
              if (created != null) Text(created, style: t.bodySmall?.copyWith(color: c.textMuted)),
              const SizedBox(height: 6),
              if (o.items.isNotEmpty || o.itemsCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(orderItemsSummary(o), style: t.bodyMedium),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Text(Money.format(o.totalTiyin), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(999)),
                      child: Text(sourceLabel(o.source), style: t.labelSmall?.copyWith(color: c.textMuted)),
                    ),
                    const Spacer(),
                    if (next != null)
                      FilledButton(onPressed: busy ? null : onNext, child: Text(o.status.nextActionLabel)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
