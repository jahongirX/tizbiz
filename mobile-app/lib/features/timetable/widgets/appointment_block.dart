import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One appointment inside a staff column (positioned by the grid).
class AppointmentBlock extends StatelessWidget {
  const AppointmentBlock({super.key, required this.appointment, required this.business, required this.height, this.onTap});

  final Appointment appointment;
  final ActiveBusiness business;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = c.appointmentStatus(appointment.status);
    final a = appointment;
    final start = a.startLocal(business.timezone).hhmm;
    final rental = business.engine.isRental;
    final title = rental ? '$start ${rentalSessionLabel(a, business)}' : '$start ${a.serviceName ?? ''}'.trim();
    final sub = [
      if ((a.clientName ?? '').isNotEmpty) a.clientName!,
      if (rental && (a.guests ?? 0) > 0) '${a.guests} mehmon',
    ].join(' · ');
    final compact = height < 40;
    final block = Material(
      color: s.bg,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: s.fg, width: 3))),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 2 : 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: s.fg, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
              ),
              if (!compact && sub.isNotEmpty)
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 11, height: 1.2),
                ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: '$title ${a.status.label}',
      child: a.status == AppointmentStatus.canceled ? Opacity(opacity: 0.5, child: block) : block,
    );
  }
}
