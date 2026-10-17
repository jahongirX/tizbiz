import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/dashboard/providers.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/appointments_bar_chart.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/kpi_card.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Buyurtmalar": order KPIs of the period; [compact] (medical) shows only the KPI row.
class OrdersSummarySection extends ConsumerWidget {
  const OrdersSummarySection({super.key, required this.range, this.compact = false});

  final DayRange range;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final value = ref.watch(ordersSummaryProvider(range));
    return SectionCard(
      title: 'Buyurtmalar',
      trailing: TextButton(onPressed: () => context.go(Routes.orders), child: const Text('Buyurtmalar taxtasi')),
      child: AsyncBody<OrdersSummary>(
        value: value,
        expand: false,
        onRetry: () => ref.invalidate(ordersSummaryProvider(range)),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: compact ? 4 : 2,
                mainAxisExtent: 112,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                KpiCard(label: 'Buyurtmalar', value: '${s.count}'),
                KpiCard(label: 'Summa', value: Money.compact(s.totalTiyin)),
                KpiCard(label: 'Yangi', value: '${s.countOf(OrderStatus.newOrder)}', tone: c.primary),
                KpiCard(label: 'Bekor qilingan', value: '${s.countOf(OrderStatus.cancelled)}', tone: c.danger),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 16),
              Text('Kunlik summa', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (s.count == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text("Bu davrda buyurtmalar yo'q",
                      textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                )
              else
                AppointmentsBarChart(
                  points: [for (final d in s.daily) (date: d.date, value: d.totalTiyin)],
                  formatValue: Money.format,
                  formatAxis: (v) => Money.compact(v, withCurrency: false),
                  color: c.success,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
