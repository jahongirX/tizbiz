import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/timetable/layout.dart';
import 'package:tizbiz_biznes/features/timetable/providers.dart';
import 'package:tizbiz_biznes/features/timetable/widgets/day_grid.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/data/schedule_data.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/day_switcher.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Jadval: one day, one column per active staff (BIZNES-SPEC §9.3).
class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    if (a == null) return const Scaffold(body: SizedBox.shrink());
    final day = ref.watch(timetableDateProvider);
    final today = bizToday(ref.read(clockProvider), a);
    final filter = ref.watch(timetableStaffFilterProvider);
    final staffAsync = ref.watch(activeStaffProvider);
    final canManage = a.can(Permissions.appointmentsManage);
    final hasStaff = staffAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Jadval')),
      floatingActionButton: canManage && hasStaff
          ? FloatingActionButton.extended(
              heroTag: 'timetable-new',
              onPressed: () => unawaited(context.push(Routes.appointmentNew(date: day, staffId: filter))),
              icon: const Icon(Icons.add),
              label: const Text('Yangi yozuv'),
            )
          : null,
      body: PollWhileVisible(
        onTick: () => ref.invalidate(dayAppointmentsProvider(day)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DaySwitcher(
              date: day,
              today: today,
              onChanged: (d) => ref.read(timetableDateProvider.notifier).set(d),
            ),
            Expanded(
              child: AsyncBody<List<Staff>>(
                value: staffAsync,
                onRetry: () => ref.invalidate(staffListProvider),
                isEmpty: (list) => list.isEmpty,
                empty: EmptyView(
                  icon: Icons.people_outline,
                  title: "Hali xodim qo'shilmagan",
                  message: "Jadvalni ko'rish uchun avval ${a.engine.staffTerm.toLowerCase()}ni qo'shing.",
                  action: FilledButton.icon(
                    onPressed: () => context.go(Routes.staffNew),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text("Xodim qo'shish"),
                  ),
                ),
                data: (staff) => _TimetableBody(business: a, day: day, today: today, staff: staff, filter: filter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableBody extends ConsumerWidget {
  const _TimetableBody({required this.business, required this.day, required this.today, required this.staff, required this.filter});

  final ActiveBusiness business;
  final LocalDate day;
  final LocalDate today;
  final List<Staff> staff;
  final int? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final visible = filter == null ? staff : [for (final s in staff) if (s.id == filter) s];
    final shown = visible.isEmpty ? staff : visible;
    final apptsAsync = ref.watch(dayAppointmentsProvider(day));
    final canManage = business.can(Permissions.appointmentsManage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip(ref, 'Hammasi', null),
              for (final s in staff) _chip(ref, s.name, s.id),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),
        Expanded(
          child: AsyncBody<List<Appointment>>(
            value: apptsAsync,
            onRetry: () => ref.invalidate(dayAppointmentsProvider(day)),
            data: (appts) {
              final tz = business.timezone;
              final ids = {for (final s in shown) s.id};
              final byStaff = <int, List<Appointment>>{};
              for (final ap in appts) {
                if (ids.contains(ap.staffId)) byStaff.putIfAbsent(ap.staffId, () => []).add(ap);
              }
              final allHours = <WorkingHours>[];
              final columns = <StaffColumnData>[];
              for (final s in shown) {
                // Working-hours / time-off errors fall back silently (default range, no overlay).
                final hours = [
                  for (final h in ref.watch(workingHoursProvider(s.id)).value ?? const <WorkingHours>[])
                    if (h.weekday == day.weekday) h,
                ];
                final off = [
                  for (final t in ref.watch(timeOffProvider(s.id)).value ?? const <TimeOff>[])
                    if (t.date == day) t,
                ];
                allHours.addAll(hours);
                columns.add(StaffColumnData(staff: s, appointments: byStaff[s.id] ?? const [], hours: hours, timeOff: off));
              }
              final visibleAppts = [for (final l in byStaff.values) ...l];
              final range = visibleRange(day: day, hours: allHours, appts: visibleAppts, timezone: tz);
              final nowMin = day == today ? bizTime(ref.read(clockProvider)(), business).minutesOfDay : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (visibleAppts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text("Bu kunda yozuvlar yo'q",
                          textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 13)),
                    ),
                  Expanded(
                    child: DayGrid(
                      day: day,
                      columns: columns,
                      range: range,
                      business: business,
                      nowMin: nowMin,
                      onRefresh: () => ref.refresh(dayAppointmentsProvider(day).future),
                      onTapAppointment: (ap) => unawaited(context.push(Routes.appointment(ap.id))),
                      onTapEmpty: canManage
                          ? (s, time) => unawaited(context.push(Routes.appointmentNew(staffId: s.id, date: day, time: time)))
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(WidgetRef ref, String label, int? id) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: filter == id,
          onSelected: (_) => ref.read(timetableStaffFilterProvider.notifier).set(id),
        ),
      );
}
