import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/features/appointments/widgets/appointment_tile.dart';
import 'package:tizbiz_biznes/features/appointments/widgets/filters_sheet.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Navbatlar / Qabullar / Ijaralar list (BIZNES-SPEC §9.4).
class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key, this.initialStaffId});

  final int? initialStaffId;

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  late bool _seeded = widget.initialStaffId == null;

  @override
  void initState() {
    super.initState();
    if (!_seeded) _seed(widget.initialStaffId);
  }

  @override
  void didUpdateWidget(AppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStaffId != widget.initialStaffId) _seed(widget.initialStaffId);
  }

  /// Providers cannot be modified while the tree builds: seed the staff filter right after.
  void _seed(int? staffId) {
    Future.microtask(() {
      if (!mounted) return;
      ref.read(appointmentsFilterProvider.notifier).setStaff(staffId);
      setState(() => _seeded = true);
    });
  }

  void _openNew() => unawaited(context.push(Routes.appointmentNew()));

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(activeBusinessProvider);
    final canManage = a?.can(Permissions.appointmentsManage) ?? false;
    final filter = ref.watch(appointmentsFilterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(a?.appointmentsTerm ?? 'Navbatlar')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'appointments-new',
              onPressed: _openNew,
              icon: const Icon(Icons.add),
              label: const Text('Yangi'),
            )
          : null,
      body: Column(
        children: [
          const AppointmentsFilterBar(),
          Expanded(
            child: !_seeded
                ? const SkeletonList()
                : PollWhileVisible(
                    onTick: () => ref.invalidate(appointmentsListProvider(filter.query)),
                    child: _List(filter: filter, canManage: canManage, onNew: _openNew),
                  ),
          ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.filter, required this.canManage, required this.onNew});

  final AppointmentsFilter filter;
  final bool canManage;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final tz = a?.timezone ?? Dates.defaultTimezone;
    final today = bizToday(ref.read(clockProvider), a);
    final value = ref.watch(appointmentsListProvider(filter.query));
    final c = AppColors.of(context);
    Future<void> refresh() => ref.refresh(appointmentsListProvider(filter.query).future);
    return AsyncBody<List<Appointment>>(
      value: value,
      loading: const SkeletonList(),
      onRetry: () => ref.invalidate(appointmentsListProvider(filter.query)),
      isEmpty: (list) => list.isEmpty,
      empty: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 48),
            EmptyView(
              icon: Icons.event_busy,
              title: "Bu davrda yozuvlar yo'q",
              action: canManage ? FilledButton(onPressed: onNew, child: const Text('Yangi yozuv')) : null,
            ),
          ],
        ),
      ),
      data: (list) {
        final shown = filterAppointmentsByText(list, filter.text);
        final groups = groupAppointmentsByDay(shown, tz);
        return RefreshIndicator(
          onRefresh: refresh,
          child: shown.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 48),
                    EmptyView(
                      icon: Icons.search_off,
                      title: 'Hech narsa topilmadi',
                      message: "Qidiruv so'zini o'zgartiring.",
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: c.surface2,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            '${UzDates.dayLabel(g.day, today: today)} · ${g.items.length}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: c.textMuted),
                          ),
                        ),
                        for (final ap in g.items) ...[
                          AppointmentTile(
                            appointment: ap,
                            onTap: () => unawaited(context.push(Routes.appointment(ap.id))),
                          ),
                          Divider(height: 1, color: c.border),
                        ],
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}
