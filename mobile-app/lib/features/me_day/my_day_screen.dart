import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/me_day/not_linked.dart';
import 'package:tizbiz_biznes/features/me_day/providers.dart';
import 'package:tizbiz_biznes/features/me_day/status_flow.dart';
import 'package:tizbiz_biznes/features/me_day/widgets/my_appointment_card.dart';
import 'package:tizbiz_biznes/features/me_day/widgets/today_header.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_biznes/shared/widgets/stale_banner.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Mening kunim": the staff member's own bookings (today / tomorrow / week) with status buttons.
class MyDayScreen extends ConsumerWidget {
  const MyDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    if (a == null || !a.hasStaffProfile) {
      return Scaffold(appBar: AppBar(title: const Text('Mening kunim')), body: const StaffNotLinkedView());
    }
    return _MyDayBody(active: a);
  }
}

class _MyDayBody extends ConsumerStatefulWidget {
  const _MyDayBody({required this.active});

  final ActiveBusiness active;

  @override
  ConsumerState<_MyDayBody> createState() => _MyDayBodyState();
}

class _MyDayBodyState extends ConsumerState<_MyDayBody> {
  /// Optimistic statuses by appointment id (reverted on error, dropped after the refetch).
  final Map<int, AppointmentStatus> _optimistic = {};
  final Set<int> _busy = {};

  void _reload(({LocalDate from, LocalDate to}) range) {
    ref.invalidate(myAppointmentsProvider(range));
    ref.invalidate(myTodayStatsProvider);
  }

  Future<void> _setStatus(Appointment appt, AppointmentStatus next, ({LocalDate from, LocalDate to}) range) async {
    if (_busy.contains(appt.id)) return;
    if (!await confirmStaffStatus(context, next) || !mounted) return;
    setState(() {
      _optimistic[appt.id] = next;
      _busy.add(appt.id);
    });
    final saved = await sendStaffStatus(context, ref, appt.id, next, onConflict: () => _reload(range));
    if (!mounted) return;
    setState(() {
      _busy.remove(appt.id);
      if (saved == null) _optimistic.remove(appt.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    final c = AppColors.of(context);
    final today = ref.watch(myTodayProvider);
    final view = ref.watch(myDayRangeProvider);
    final range = myDayRangeFor(view, today);
    final list = ref.watch(myAppointmentsProvider(range));
    final stats = ref.watch(myTodayStatsProvider);
    final session = ref.watch(sessionProvider);
    final fullName = session is SessionSignedIn ? session.session.user.name.trim() : '';
    final firstName = fullName.isEmpty ? '' : fullName.split(RegExp(r'\s+')).first;

    // Drop optimistic values the server already reflects.
    final items = list.value;
    if (items != null && _optimistic.isNotEmpty) {
      for (final appt in items) {
        if (_optimistic[appt.id] == appt.status && !_busy.contains(appt.id)) _optimistic.remove(appt.id);
      }
    }

    if (isNotLinkedError(list.error) && !list.hasValue) {
      return Scaffold(appBar: AppBar(title: const Text('Mening kunim')), body: const NotLinkedFromError());
    }

    final hasData = list.hasValue && list.requireValue.isNotEmpty;
    final emptyTitle = switch (view) {
      MyDayView.today => "Bugun yozuvlar yo'q",
      MyDayView.tomorrow => "Ertaga yozuvlar yo'q",
      MyDayView.week => "Bu hafta yozuvlar yo'q",
    };

    Widget card(Appointment appt) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: MyAppointmentCard(
            appointment: appt,
            active: a,
            status: _optimistic[appt.id],
            busy: _busy.contains(appt.id),
            onTap: () => unawaited(context.push(Routes.myAppointment(appt.id))),
            onStatus: (next) => _setStatus(appt, next, range),
          ),
        );

    List<Widget> rows(List<Appointment> appts) {
      if (view != MyDayView.week) return [for (final x in appts) card(x)];
      final out = <Widget>[];
      LocalDate? day;
      for (final x in appts) {
        final d = x.startLocal(a.timezone).date;
        if (d != day) {
          day = d;
          out.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(UzDates.dayLabel(d, today: today),
                style: TextStyle(fontWeight: FontWeight.w700, color: c.textMuted)),
          ));
        }
        out.add(card(x));
      }
      return out;
    }

    return PollWhileVisible(
      onTick: () => _reload(range),
      child: Scaffold(
        appBar: AppBar(title: const Text('Mening kunim')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myTodayStatsProvider);
            final _ = await ref.refresh(myAppointmentsProvider(range).future);
          },
          child: MaxWidth(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: TodayHeader(firstName: firstName, today: today, stats: stats.value, timezone: a.timezone),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: SegmentedButton<MyDayView>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: MyDayView.today, label: Text('Bugun')),
                        ButtonSegment(value: MyDayView.tomorrow, label: Text('Ertaga')),
                        ButtonSegment(value: MyDayView.week, label: Text('Hafta')),
                      ],
                      selected: {view},
                      onSelectionChanged: (s) => ref.read(myDayRangeProvider.notifier).set(s.first),
                    ),
                  ),
                ),
                if (hasData) ...[
                  if (list.isLoading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
                  if (list.hasError && !list.isLoading)
                    SliverToBoxAdapter(child: StaleBanner(error: list.error!, onRetry: () => _reload(range))),
                  SliverList.list(children: [...rows(list.requireValue), const SizedBox(height: 24)]),
                ] else
                  SliverFillRemaining(
                    child: AsyncBody<List<Appointment>>(
                      value: list,
                      loading: const SkeletonList(count: 4),
                      onRetry: () => _reload(range),
                      isEmpty: (l) => l.isEmpty,
                      empty: EmptyView(icon: Icons.free_breakfast_outlined, title: emptyTitle),
                      data: (_) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
