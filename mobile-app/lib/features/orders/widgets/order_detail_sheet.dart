import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/orders/providers.dart';
import 'package:tizbiz_biznes/features/orders/widgets/status_picker_sheet.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Order details over the board (there is no GET /v1/orders/{id}). Watches the merged board list,
/// so a status change shows immediately.
class OrderDetailSheet extends ConsumerWidget {
  const OrderDetailSheet({super.key, required this.initial, required this.onStatus});

  final Order initial;

  /// Applies a status change (the board does the optimistic update and the snack).
  final Future<void> Function(Order order, OrderStatus next) onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final list = ref.watch(boardOrdersProvider).value;
    var o = initial;
    for (final x in list ?? const <Order>[]) {
      if (x.id == initial.id) o = x;
    }
    final busy = ref.watch(orderOverridesProvider.notifier).isPending(o.id);
    final today = bizToday(ref.read(clockProvider), a);
    final next = o.status.next;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Text('Buyurtma #${o.id}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              OrderStatusBadge(o.status),
            ],
          ),
          if (o.createdAt != null)
            Text(
              UzDates.dateTime(Dates.toBizLocal(o.createdAt!, a?.timezone), today: today),
              style: t.bodySmall?.copyWith(color: c.textMuted),
            ),
          const SizedBox(height: 12),
          Text((o.customerName ?? '').isEmpty ? 'Mijoz' : o.customerName!, style: t.titleSmall),
          if ((o.customerPhone ?? '').isNotEmpty) PhoneLink(o.customerPhone),
          Text('Manba: ${sourceLabel(o.source)}', style: t.bodySmall?.copyWith(color: c.textMuted)),
          const Divider(height: 24),
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(i.name)),
                  const SizedBox(width: 8),
                  Text('${i.qty} × ${Money.format(i.priceTiyin)}', style: t.bodySmall?.copyWith(color: c.textMuted)),
                  const SizedBox(width: 8),
                  Text(Money.format(i.totalTiyin), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (o.items.isEmpty) Text("Mahsulotlar ro'yxati yo'q", style: t.bodySmall?.copyWith(color: c.textMuted)),
          const Divider(height: 24),
          Row(
            children: [
              Text('Jami', style: t.titleSmall),
              const Spacer(),
              Text(Money.format(o.totalTiyin), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          if ((o.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Izoh', style: t.labelLarge),
            Text(o.note!.trim()),
          ],
          const SizedBox(height: 20),
          if (next != null)
            FilledButton(onPressed: busy ? null : () => onStatus(o, next), child: Text(o.status.nextActionLabel)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final s = await showOrderStatusPicker(context, o.status);
                    if (s != null) await onStatus(o, s);
                  },
            icon: const Icon(Icons.swap_horiz),
            label: const Text("Holatni o'zgartirish"),
          ),
          if (o.status != OrderStatus.cancelled && o.status != OrderStatus.delivered) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.danger),
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirmCancelOrder(context)) await onStatus(o, OrderStatus.cancelled);
                    },
              child: const Text('Bekor qilish'),
            ),
          ],
        ],
      ),
    );
  }
}
