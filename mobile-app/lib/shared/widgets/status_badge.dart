import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.colors});

  final String label;
  final StatusColors colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(color: colors.fg, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
        ),
      );
}

/// Appointment status pill (`Kutilmoqda`, `Tasdiqlangan`, ...), web `.badge.*` colours.
class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge(this.status, {super.key});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) =>
      _Badge(label: status.label, colors: AppColors.of(context).appointmentStatus(status));
}

/// Order status pill (`Yangi`, `Tayyorlanmoqda`, ...), board colours with a 15% background.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) =>
      _Badge(label: status.label, colors: AppColors.of(context).orderStatusBadge(status));
}
