import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/dashboard/providers.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/appointments_bar_chart.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/orders_summary_section.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/revenue_chart.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/staff_load_card.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/today_card.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/top_services_card.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/kpi_card.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kRentalRevenueNote = "Ijara daromadi mehmonlar soniga ko'paytirilmagan (xizmat narxi bo'yicha).";

/// Bosh sahifa (BIZNES-SPEC §9.2).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref, ActiveBusiness a, DayRange range) async {
    final futures = <Future<Object?>>[
      if (a.hasAppointments) ref.refresh(todayAppointmentsProvider.future),
      if (a.hasAppointments) ref.refresh(analyticsProvider(range).future),
      if (a.hasOrders) ref.refresh(ordersSummaryProvider(range).future),
    ];
    // Errors are rendered by each section; the indicator only waits.
    await Future.wait([for (final f in futures) f.then<Object?>((v) => v, onError: (Object _) => null)]);
  }

  void _poll(WidgetRef ref, ActiveBusiness a, DateRangeValue range) {
    if (a.hasAppointments) ref.invalidate(todayAppointmentsProvider);
    final today = bizToday(ref.read(clockProvider), a);
    if (a.hasOrders && !range.to.isBefore(today)) ref.invalidate(ordersSummaryProvider(range.key));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    if (a == null) return const Scaffold(body: LoadingView());
    final c = AppColors.of(context);
    final range = ref.watch(dashboardRangeProvider);
    final today = bizToday(ref.read(clockProvider), a);
    final muted = TextStyle(fontSize: 12, color: c.textMuted);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(UzDates.weekdayDayMonth(today), style: muted),
          ],
        ),
      ),
      body: PollWhileVisible(
        onTick: () => _poll(ref, a, range),
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref, a, range.key),
          child: MaxWidth(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (a.hasAppointments)
                  const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: TodayCard()),
                const SizedBox(height: 16),
                PeriodChips(
                  value: range,
                  presets: const [PeriodPreset.last7, PeriodPreset.last30, PeriodPreset.last90, PeriodPreset.custom],
                  onChanged: ref.read(dashboardRangeProvider.notifier).set,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Text('Hisobot kunlari UTC bo\'yicha hisoblanadi.', style: muted),
                ),
                if (a.hasAppointments) _AnalyticsSection(range: range.key),
                if (a.hasOrders)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: OrdersSummarySection(range: range.key, compact: a.hasAppointments),
                  ),
                if (a.engine == Engine.rental)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(kRentalRevenueNote, style: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsSection extends ConsumerWidget {
  const _AnalyticsSection({required this.range});

  final DayRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(analyticsProvider(range));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AsyncBody<AnalyticsOverview>(
        value: value,
        expand: false,
        onRetry: () => ref.invalidate(analyticsProvider(range)),
        isEmpty: (o) => o.appointments.total == 0,
        empty: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: EmptyView(icon: Icons.insights_outlined, title: "Bu davrda ma'lumot yo'q"),
        ),
        data: (o) => _AnalyticsContent(o: o),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.o});

  final AnalyticsOverview o;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 112,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            KpiCard(label: 'Daromad', value: Money.compact(o.revenueTiyin), icon: Icons.payments_outlined, tone: c.success),
            KpiCard(label: 'Yozuvlar', value: '${o.appointments.total}', icon: Icons.event_note_outlined),
            KpiCard(
              label: 'Kelmadi',
              value: '${o.noShowRate.toStringAsFixed(1)}%',
              icon: Icons.person_off_outlined,
              tone: c.danger,
            ),
            KpiCard(
              label: 'Yangi mijozlar',
              value: '${o.clientsNew}',
              sub: 'jami ${o.clientsTotal}',
              icon: Icons.person_add_alt_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(title: 'Kunlik daromad', child: RevenueChart(series: o.series)),
        const SizedBox(height: 12),
        SectionCard(title: 'Kunlik yozuvlar', child: AppointmentsBarChart.fromSeries(o.series)),
        const SizedBox(height: 12),
        TopServicesCard(rows: o.topServices),
        const SizedBox(height: 12),
        StaffLoadCard(rows: o.staffLoad),
      ],
    );
  }
}
