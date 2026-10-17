import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/dashboard/providers.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const _live = {AppointmentStatus.pending, AppointmentStatus.confirmed, AppointmentStatus.arrived};

/// Counters of today's appointments.
typedef TodayCounts = ({int total, int waiting, int completed, int noShow});

TodayCounts todayCounts(List<Appointment> list) => (
      total: list.length,
      waiting: list.where((x) => _live.contains(x.status)).length,
      completed: list.where((x) => x.status == AppointmentStatus.completed).length,
      noShow: list.where((x) => x.status == AppointmentStatus.noShow).length,
    );

/// The next [limit] live (pending / confirmed / arrived) appointments that have not ended yet.
List<Appointment> nextLive(List<Appointment> list, DateTime now, {int limit = 3}) {
  final live = [
    for (final x in list)
      if (_live.contains(x.status) && x.endsAt.isAfter(now)) x,
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return live.take(limit).toList();
}

/// "Bugun": today's counters and the next live appointments.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(todayAppointmentsProvider);
    return SectionCard(
      title: 'Bugun',
      trailing: TextButton(onPressed: () => context.go(Routes.appointments), child: const Text('Barchasi')),
      child: AsyncBody<List<Appointment>>(
        value: value,
        expand: false,
        onRetry: () => ref.invalidate(todayAppointmentsProvider),
        data: (list) => _TodayContent(list: list),
      ),
    );
  }
}

class _TodayContent extends ConsumerWidget {
  const _TodayContent({required this.list});

  final List<Appointment> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final a = ref.watch(activeBusinessProvider);
    final counts = todayCounts(list);
    final next = nextLive(list, ref.read(clockProvider)());
    Widget counter(String label, int n, Color color) => Expanded(
          child: Column(
            children: [
              Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textMuted)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            counter('Jami', counts.total, c.text),
            counter('Kutilayotgan', counts.waiting, c.warning),
            counter('Yakunlangan', counts.completed, c.success),
            counter('Kelmadi', counts.noShow, c.danger),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Bugun yozuvlar yo'q", textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
          )
        else if (next.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Bugun boshqa kutilayotgan yozuv yo'q",
                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
          )
        else
          for (final x in next)
            if (a != null) _NextTile(appt: x, business: a),
      ],
    );
  }
}

class _NextTile extends StatelessWidget {
  const _NextTile({required this.appt, required this.business});

  final Appointment appt;
  final ActiveBusiness business;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final time = UzDates.timeRange(bizTime(appt.startsAt, business), bizTime(appt.endsAt, business));
    final sub = [appt.serviceName, appt.staffName].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => unawaited(context.push(Routes.appointment(appt.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.clientName ?? 'Mijoz', maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppointmentStatusBadge(appt.status),
          ],
        ),
      ),
    );
  }
}
