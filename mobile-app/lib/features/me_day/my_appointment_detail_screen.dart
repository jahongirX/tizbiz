import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/me_day/not_linked.dart';
import 'package:tizbiz_biznes/features/me_day/providers.dart';
import 'package:tizbiz_biznes/features/me_day/status_flow.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/info_row.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/money_text.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One own booking (staff): time, client, service, notes and the staff status buttons.
class MyAppointmentDetailScreen extends ConsumerStatefulWidget {
  const MyAppointmentDetailScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  ConsumerState<MyAppointmentDetailScreen> createState() => _MyAppointmentDetailScreenState();
}

class _MyAppointmentDetailScreenState extends ConsumerState<MyAppointmentDetailScreen> {
  bool _busy = false;

  Future<void> _setStatus(AppointmentStatus next) async {
    if (_busy) return;
    if (!await confirmStaffStatus(context, next) || !mounted) return;
    setState(() => _busy = true);
    await sendStaffStatus(context, ref, widget.appointmentId, next,
        onConflict: () => ref.invalidate(myAppointmentProvider(widget.appointmentId)));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = Text('Yozuv #${widget.appointmentId}');
    final a = ref.watch(activeBusinessProvider);
    if (a == null || !a.hasStaffProfile) {
      return Scaffold(appBar: AppBar(title: title), body: const StaffNotLinkedView());
    }
    final value = ref.watch(myAppointmentProvider(widget.appointmentId));
    if (isNotLinkedError(value.error) && !value.hasValue) {
      return Scaffold(appBar: AppBar(title: title), body: const NotLinkedFromError());
    }
    return Scaffold(
      appBar: AppBar(title: title),
      body: AsyncBody<Appointment>(
        value: value,
        onRetry: () => ref.invalidate(myAppointmentProvider(widget.appointmentId)),
        data: (appt) => RefreshIndicator(
          onRefresh: () => ref.refresh(myAppointmentProvider(widget.appointmentId).future),
          child: MaxWidth(child: _Details(appt: appt, active: a, busy: _busy, onStatus: _setStatus)),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.appt, required this.active, required this.busy, required this.onStatus});

  final Appointment appt;
  final ActiveBusiness active;
  final bool busy;
  final ValueChanged<AppointmentStatus> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final today = bizToday(ref.read(clockProvider), active);
    final start = appt.startLocal(active.timezone);
    final end = appt.endLocal(active.timezone);
    final minutes = appt.serviceDuration ?? appt.duration.inMinutes;
    final next = appt.status.staffNext;
    final notes = appt.notes?.trim();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(UzDates.dayLabel(start.date, today: today),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  AppointmentStatusBadge(appt.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(UzDates.timeRange(start, end), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (active.engine.isRental) ...[
                const SizedBox(height: 4),
                Text(rentalSessionLabel(appt, active), style: TextStyle(color: c.textMuted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Mijoz',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'Ism', value: Text(appt.clientName ?? '—')),
              InfoRow(label: 'Telefon', value: PhoneLink(appt.clientPhone)),
              if ((appt.guests ?? 0) > 0) InfoRow(label: 'Mehmonlar', value: Text('${appt.guests} kishi')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Xizmat',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'Nomi', value: Text(appt.serviceName ?? '—')),
              InfoRow(label: 'Davomiyligi', value: Text(UzDates.duration(minutes))),
              if (appt.servicePriceTiyin != null) InfoRow(label: 'Narxi', value: MoneyText(appt.servicePriceTiyin)),
              for (final i in appt.items)
                InfoRow(label: i.qty > 1 ? '${i.name} × ${i.qty}' : i.name, value: MoneyText(i.totalTiyin)),
              if ((appt.depositTiyin ?? 0) > 0)
                InfoRow(
                  label: 'Depozit',
                  value: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoneyText(appt.depositTiyin),
                      const SizedBox(width: 6),
                      Text(appt.paid ? "(to'langan)" : "(to'lanmagan)",
                          style: TextStyle(color: appt.paid ? c.success : c.warning)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(title: 'Izoh', child: Text(notes)),
        ],
        const SizedBox(height: 16),
        if (next.isEmpty)
          Center(child: Text('Bu yozuv yakunlangan', style: TextStyle(color: c.textMuted)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in next)
                s == AppointmentStatus.noShow
                    ? OutlinedButton(
                        onPressed: busy ? null : () => onStatus(s),
                        style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                        child: Text(s.actionLabel),
                      )
                    : FilledButton(onPressed: busy ? null : () => onStatus(s), child: Text(s.actionLabel)),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
