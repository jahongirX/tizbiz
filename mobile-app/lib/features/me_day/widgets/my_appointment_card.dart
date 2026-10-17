import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Time, client, service" card of one own booking with the staff status buttons.
class MyAppointmentCard extends StatelessWidget {
  const MyAppointmentCard({
    super.key,
    required this.appointment,
    required this.active,
    this.status,
    this.busy = false,
    this.onTap,
    this.onStatus,
  });

  final Appointment appointment;
  final ActiveBusiness active;

  /// Optimistic status (overrides `appointment.status`).
  final AppointmentStatus? status;
  final bool busy;
  final VoidCallback? onTap;
  final ValueChanged<AppointmentStatus>? onStatus;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = appointment;
    final st = status ?? a.status;
    final start = a.startLocal(active.timezone);
    final end = a.endLocal(active.timezone);
    final minutes = a.serviceDuration ?? a.duration.inMinutes;
    final notes = a.notes?.trim();
    final next = st.staffNext;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(UzDates.timeRange(start, end),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  AppointmentStatusBadge(st),
                ],
              ),
              const SizedBox(height: 8),
              Text(a.clientName ?? 'Mijoz', style: const TextStyle(fontWeight: FontWeight.w600)),
              if ((a.clientPhone ?? '').isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.call_outlined, size: 16, color: c.textMuted),
                    const SizedBox(width: 4),
                    PhoneLink(a.clientPhone),
                  ],
                ),
              const SizedBox(height: 4),
              Text('${a.serviceName ?? 'Xizmat'} · ${UzDates.duration(minutes)}', style: TextStyle(color: c.textMuted)),
              if (active.engine.isRental) ...[
                const SizedBox(height: 4),
                Text(
                  [rentalSessionLabel(a, active), if ((a.guests ?? 0) > 0) '${a.guests} mehmon'].join(' · '),
                  style: TextStyle(color: c.textMuted),
                ),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              if (next.isNotEmpty && onStatus != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in next)
                      s == AppointmentStatus.noShow
                          ? OutlinedButton(
                              onPressed: busy ? null : () => onStatus!(s),
                              style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                              child: Text(s.actionLabel),
                            )
                          : s == AppointmentStatus.completed
                              ? FilledButton(onPressed: busy ? null : () => onStatus!(s), child: Text(s.actionLabel))
                              : FilledButton.tonal(onPressed: busy ? null : () => onStatus!(s), child: Text(s.actionLabel)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
