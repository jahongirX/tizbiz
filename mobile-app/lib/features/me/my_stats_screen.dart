import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/me/not_linked.dart';
import 'package:tizbiz_biznes/features/me/providers.dart';
import 'package:tizbiz_biznes/features/me/widgets/earnings_chart.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/kpi_card.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Statistikam": own KPIs, daily earnings chart and status breakdown for a period.
class MyStatsScreen extends ConsumerWidget {
  const MyStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = Text('Statistikam');
    final a = ref.watch(activeBusinessProvider);
    if (a == null || !a.hasStaffProfile) {
      return Scaffold(appBar: AppBar(title: title), body: const StaffNotLinkedView());
    }
    final range = ref.watch(myStatsRangeProvider);
    final value = ref.watch(myStatsProvider(range.key));
    if (isMeNotLinked(value.error) && !value.hasValue) {
      return Scaffold(appBar: AppBar(title: title), body: const MeNotLinkedView());
    }
    return Scaffold(
      appBar: AppBar(title: title),
      body: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: PeriodChips(
                value: range,
                presets: kMyStatsPresets,
                onChanged: ref.read(myStatsRangeProvider.notifier).set,
              ),
            ),
            Expanded(
              child: AsyncBody<MeStats>(
                value: value,
                onRetry: () => ref.invalidate(myStatsProvider(range.key)),
                data: (s) => RefreshIndicator(
                  onRefresh: () => ref.refresh(myStatsProvider(range.key).future),
                  child: _StatsBody(stats: s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final MeStats stats;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = stats;
    final ap = s.appointments;
    final kpis = [
      KpiCard(label: 'Yakunlangan', value: '${ap.completed}', icon: Icons.check_circle_outline, tone: c.success),
      KpiCard(label: 'Tushum', value: Money.format(s.revenueTiyin), icon: Icons.payments_outlined),
      KpiCard(
        label: 'Ish haqim',
        value: Money.format(s.earningsTiyin),
        sub: 'komissiya ${s.commissionPercent}%',
        icon: Icons.account_balance_wallet_outlined,
        tone: c.success,
      ),
      KpiCard(label: 'Mijozlar', value: '${s.clientsServed}', icon: Icons.people_outline),
      KpiCard(label: 'Kelmadi', value: '${ap.noShow}', icon: Icons.person_off_outlined, tone: c.warning),
      KpiCard(label: 'Bekor qilingan', value: '${ap.canceled}', icon: Icons.cancel_outlined, tone: c.danger),
    ];
    final breakdown = [
      (AppointmentStatus.pending, ap.pending),
      (AppointmentStatus.confirmed, ap.confirmed),
      (AppointmentStatus.arrived, ap.arrived),
      (AppointmentStatus.completed, ap.completed),
      (AppointmentStatus.noShow, ap.noShow),
      (AppointmentStatus.canceled, ap.canceled),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 600 ? 3 : 2;
          final w = (box.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final k in kpis) SizedBox(width: w, child: k)],
          );
        }),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Kunlik ish haqi',
          child: isSeriesEmpty(s.series)
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text("Bu davrda yakunlangan yozuvlar yo'q",
                      textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                )
              : EarningsChart(series: s.series),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Holatlar bo\'yicha (jami ${ap.total})',
          child: Column(
            children: [
              for (final (st, n) in breakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: c.appointmentStatus(st).fg, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(st.label)),
                      Text('$n', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Ish haqi = yakunlangan xizmatlar narxi × komissiya %.',
            style: TextStyle(color: c.textMuted, fontSize: 12)),
      ],
    );
  }
}
