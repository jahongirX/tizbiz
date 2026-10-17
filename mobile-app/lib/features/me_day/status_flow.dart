import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/me_day/actions.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Asks for "Kelmadi" confirmation. False = the user backed out.
Future<bool> confirmStaffStatus(BuildContext context, AppointmentStatus next) async {
  if (next != AppointmentStatus.noShow) return true;
  return confirmAction(context,
      title: 'Mijoz kelmadimi?', message: 'Yozuv "Kelmadi" deb belgilanadi.', confirmLabel: 'Kelmadi', destructive: true);
}

/// Sends the status change; on error shows a snack (409: the server text) and returns null.
/// [onConflict] runs after a 409 (refetch).
Future<Appointment?> sendStaffStatus(
  BuildContext context,
  WidgetRef ref,
  int id,
  AppointmentStatus next, {
  VoidCallback? onConflict,
}) async {
  try {
    final a = await ref.read(myAppointmentActionsProvider).setStatus(id, next);
    if (context.mounted) showAppSnack(context, 'Holat: ${next.label}');
    return a;
  } catch (e) {
    if (!context.mounted) return null;
    if (e is ApiException && e.isConflict) {
      showAppSnack(context, e.detail.trim().isNotEmpty ? e.detail : e.message, error: true);
      onConflict?.call();
    } else {
      showAppSnack(context, errorText(e), error: true);
    }
    return null;
  }
}
