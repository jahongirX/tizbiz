import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Staff status changes of own bookings (`status.staffNext`: never canceled).
class MyAppointmentActions {
  MyAppointmentActions(this._ref);

  final Ref _ref;

  /// PATCH /v1/me/appointments/{id} {"status": next.wire} -> Appointment. Bumps appointments
  /// (and clients: CRM counters change on completion).
  Future<Appointment> setStatus(int id, AppointmentStatus next) async {
    final a = await _ref.read(apiClientProvider).patch<Appointment>(Endpoints.meAppointment(id),
        body: {'status': next.wire}, decode: (d) => Appointment.fromJson(JsonRead.object(d)));
    bump(_ref, appointmentsRevisionProvider);
    bump(_ref, clientsRevisionProvider);
    return a;
  }
}

final myAppointmentActionsProvider = Provider<MyAppointmentActions>(MyAppointmentActions.new);
