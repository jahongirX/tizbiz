import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One row of the appointments list.
class AppointmentTile extends ConsumerWidget {
  const AppointmentTile({super.key, required this.appointment, this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final ap = appointment;
    final tz = a?.timezone ?? Dates.defaultTimezone;
    final rental = a?.engine == Engine.rental;
    final subtitle = [
      if ((ap.serviceName ?? '').isNotEmpty) ap.serviceName!,
      if ((ap.staffName ?? '').isNotEmpty) ap.staffName!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        [
                          if (rental && a != null) rentalSessionLabel(ap, a),
                          UzDates.timeRange(ap.startLocal(tz), ap.endLocal(tz)),
                        ].join(' · '),
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      AppointmentStatusBadge(ap.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (ap.clientName ?? '').isEmpty ? 'Mijoz' : ap.clientName!,
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((ap.clientPhone ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        PhoneLink(ap.clientPhone, style: t.bodySmall),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle, style: t.bodySmall?.copyWith(color: c.textMuted)),
                    ),
                  if (rental && (ap.guests ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${ap.guests} mehmon', style: t.bodySmall?.copyWith(color: c.textMuted)),
                    ),
                ],
              ),
            ),
            if (ap.requiresDeposit)
              Tooltip(
                message: "Oldindan to'lov kutilmoqda",
                child: Icon(Icons.payments_outlined, color: c.warning, size: 20),
              )
            else if (ap.paid && (ap.depositTiyin ?? 0) > 0)
              Tooltip(
                message: "Oldindan to'lov to'langan",
                child: Icon(Icons.check_circle_outline, color: c.success, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
