import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/money/providers.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Signed amount text: refunds are negative.
String transactionAmount(FinanceTransaction t) =>
    t.type == 'refund' ? '−${Money.format(t.amountTiyin.abs())}' : Money.format(t.amountTiyin);

/// One payment row of the finance list.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.tx});

  final FinanceTransaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final a = ref.watch(activeBusinessProvider);
    final today = bizToday(ref.read(clockProvider), a);
    final at = tx.createdAt;
    final date = at == null ? '' : UzDates.dateTime(Dates.toBizLocal(at, a?.timezone), today: today);
    final amountColor = switch (tx.type) {
      'refund' => c.danger,
      'deposit' => c.success,
      _ => c.text,
    };
    final (statusBg, statusFg) = switch (tx.status) {
      'paid' => (c.success.withValues(alpha: 0.14), c.success),
      'refunded' || 'canceled' => (c.dangerSoft, c.danger),
      _ => (c.surface2, c.textMuted),
    };
    final details = [tx.serviceName, tx.typeLabel, providerLabel(tx.provider)]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final id = tx.appointmentId;
    return ListTile(
      onTap: id == null ? null : () => unawaited(context.push(Routes.appointment(id))),
      leading: CircleAvatar(
        backgroundColor: c.surface2,
        child: Icon(
          switch (tx.type) {
            'refund' => Icons.undo,
            'float' => Icons.percent,
            _ => Icons.payments_outlined,
          },
          color: amountColor,
          size: 20,
        ),
      ),
      title: Text(tx.clientName ?? 'Mijoz', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (date.isNotEmpty) Text(date, style: TextStyle(fontSize: 12, color: c.textMuted)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(transactionAmount(tx), style: TextStyle(fontWeight: FontWeight.w700, color: amountColor)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
            child: Text(tx.statusLabel, style: TextStyle(fontSize: 11, color: statusFg, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
