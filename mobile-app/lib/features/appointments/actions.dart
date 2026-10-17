import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Appointment mutations (BIZNES-SPEC §9.4). Screens await them and show errors themselves.
class AppointmentActions {
  AppointmentActions(this.ref);

  final Ref ref;

  ApiClient get _api => ref.read(apiClientProvider);

  void _bump() {
    bump(ref, appointmentsRevisionProvider);
    bump(ref, clientsRevisionProvider);
  }

  /// PATCH /v1/appointments/{id} {"status": next}.
  Future<Appointment> setStatus(int id, AppointmentStatus next) async {
    final saved = await _api.patch<Appointment>(
      Endpoints.appointment(id),
      body: {'status': next.wire},
      decode: (d) => Appointment.fromJson(JsonRead.object(d)),
    );
    _bump();
    return saved;
  }

  /// POST /v1/appointments (admin mode) with an Idempotency-Key; 201 new, 200 replay.
  Future<ApiResponse<Appointment>> create(AdminBookingRequest req, String idempotencyKey) async {
    final res = await _api.request<Appointment>(
      'POST',
      Endpoints.appointments,
      body: req.toJson(),
      decode: (d) => Appointment.fromJson(JsonRead.object(d)),
      idempotencyKey: idempotencyKey,
    );
    _bump();
    return res;
  }

  /// POST /v1/payments/deposit (Payme only, stable key `dep-<id>-payme`, no token).
  Future<DepositCheckout> depositLink(int appointmentId) => _api.post<DepositCheckout>(
    Endpoints.paymentsDeposit,
    body: {'appointment_id': appointmentId, 'provider': PaymentProvider.payme.wire},
    decode: (d) => DepositCheckout.fromJson(JsonRead.object(d)),
    idempotencyKey: Idempotency.deposit(appointmentId),
    auth: RequestAuth.none,
  );
}

final appointmentActionsProvider = Provider<AppointmentActions>(AppointmentActions.new);
