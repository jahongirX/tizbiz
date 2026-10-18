import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Consumer-facing appointment status label (Bizcat wording).
String appointmentStatusLabel(AppointmentStatus s) => switch (s) {
  AppointmentStatus.pending => 'Kutilmoqda',
  AppointmentStatus.confirmed => 'Tasdiqlangan',
  AppointmentStatus.arrived => 'Jarayonda',
  AppointmentStatus.completed => 'Yakunlandi',
  AppointmentStatus.noShow => 'Kelmadi',
  AppointmentStatus.canceled => 'Bekor qilingan',
  AppointmentStatus.unknown => "Noma'lum",
};

/// Consumer-facing order status label (never "Yetkazildi": there is no delivery).
String orderStatusLabel(OrderStatus s) => switch (s) {
  OrderStatus.newOrder => 'Yangi',
  OrderStatus.confirmed => 'Tasdiqlangan',
  OrderStatus.preparing => 'Tayyorlanmoqda',
  OrderStatus.ready => 'Tayyor',
  OrderStatus.delivered => 'Topshirildi',
  OrderStatus.cancelled => 'Bekor qilingan',
  OrderStatus.unknown => "Noma'lum",
};

(Color, Color) _appointmentColors(AppointmentStatus s) => switch (s) {
  AppointmentStatus.pending => (BzColors.warning, BzColors.warningBg),
  AppointmentStatus.confirmed || AppointmentStatus.arrived => (BzColors.indigo, BzColors.indigo50),
  AppointmentStatus.completed => (BzColors.success, BzColors.successBg),
  AppointmentStatus.noShow => (BzColors.danger, BzColors.dangerBg),
  AppointmentStatus.canceled || AppointmentStatus.unknown => (BzColors.neutral, BzColors.neutralBg),
};

(Color, Color) _orderColors(OrderStatus s) => switch (s) {
  OrderStatus.newOrder => (BzColors.warning, BzColors.warningBg),
  OrderStatus.confirmed || OrderStatus.preparing => (BzColors.indigo, BzColors.indigo50),
  OrderStatus.ready || OrderStatus.delivered => (BzColors.success, BzColors.successBg),
  OrderStatus.cancelled || OrderStatus.unknown => (BzColors.neutral, BzColors.neutralBg),
};

/// A pill with fg/bg colors and a `labelSmall` label.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.foreground, required this.background});

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(BzRadius.pill)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground)),
    );
  }
}

/// Appointment status pill (consumer labels).
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip(this.status, {super.key});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _appointmentColors(status);
    return StatusPill(label: appointmentStatusLabel(status), foreground: fg, background: bg);
  }
}

/// Order status pill (consumer labels).
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _orderColors(status);
    return StatusPill(label: orderStatusLabel(status), foreground: fg, background: bg);
  }
}
