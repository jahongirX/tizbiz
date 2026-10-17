import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/staff_admin/actions.dart';
import 'package:tizbiz_biznes/features/staff_admin/form_support.dart';
import 'package:tizbiz_biznes/features/staff_admin/widgets/time_off_dialog.dart';
import 'package:tizbiz_biznes/shared/data/schedule_data.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Dam olish tab: upcoming list, past collapsed, add via [TimeOffDialog].
class TimeOffTab extends ConsumerWidget {
  const TimeOffTab({super.key, required this.staffId});

  final int staffId;

  Future<void> _add(BuildContext context, LocalDate today) async {
    final created = await TimeOffDialog.show(context, staffId: staffId, today: today);
    if (created != null && context.mounted) showAppSnack(context, "Dam olish qo'shildi");
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TimeOff t) async {
    final id = t.id;
    if (id == null) return;
    final ok = await confirmAction(
      context,
      title: "Dam olish o'chirilsinmi?",
      message: UzDates.weekdayDayMonth(t.date),
      confirmLabel: "O'chirish",
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(staffActionsProvider).deleteTimeOff(staffId, id);
      if (context.mounted) showAppSnack(context, "O'chirildi");
    } on Object catch (e) {
      reportForbidden(ref, e);
      if (context.mounted) showAppSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = bizToday(ref.read(clockProvider), ref.watch(activeBusinessProvider));
    final async = ref.watch(timeOffProvider(staffId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'time-off-add',
        onPressed: () => unawaited(_add(context, today)),
        icon: const Icon(Icons.add),
        label: const Text("Dam olish qo'shish"),
      ),
      body: AsyncBody<List<TimeOff>>(
        value: async,
        onRetry: () => ref.invalidate(timeOffProvider(staffId)),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          icon: Icons.beach_access_outlined,
          title: "Dam olish kunlari yo'q",
          message: "Ta'til yoki dam olish kunini qo'shsangiz, bu vaqtga bron qilinmaydi.",
        ),
        data: (list) {
          final upcoming = [for (final t in list) if (!t.date.isBefore(today)) t]..sort((a, b) => a.date.compareTo(b.date));
          final past = [for (final t in list) if (t.date.isBefore(today)) t]..sort((a, b) => b.date.compareTo(a.date));
          return RefreshIndicator(
            onRefresh: () => ref.refresh(timeOffProvider(staffId).future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (upcoming.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Kelgusi dam olish kunlari yo'q"),
                  ),
                for (final t in upcoming) _TimeOffTile(t: t, onDelete: () => unawaited(_delete(context, ref, t))),
                if (past.isNotEmpty)
                  ExpansionTile(
                    title: Text("O'tganlar (${past.length})"),
                    children: [
                      for (final t in past) _TimeOffTile(t: t, muted: true, onDelete: () => unawaited(_delete(context, ref, t))),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimeOffTile extends StatelessWidget {
  const _TimeOffTile({required this.t, required this.onDelete, this.muted = false});

  final TimeOff t;
  final VoidCallback onDelete;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final when = t.isFullDay
        ? "Kun bo'yi"
        : '${t.start?.format() ?? '00:00'} – ${t.end?.format() ?? '23:59'}';
    final reason = (t.reason ?? '').trim();
    return ListTile(
      leading: Icon(Icons.event_busy_outlined, color: muted ? c.textMuted : c.warning),
      title: Text(UzDates.weekdayDayMonth(t.date), style: muted ? TextStyle(color: c.textMuted) : null),
      subtitle: Text(reason.isEmpty ? when : '$when · $reason'),
      trailing: IconButton(
        tooltip: "O'chirish",
        icon: Icon(Icons.delete_outline, color: c.danger),
        onPressed: onDelete,
      ),
    );
  }
}
