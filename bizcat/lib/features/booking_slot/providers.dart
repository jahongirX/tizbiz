import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The four steps of the slot wizard, in order.
enum SlotStep { service, staff, datetime, confirm }

/// How many days the date strip offers, starting today (business local).
const int kSlotDayStrip = 14;

/// Snackbar shown when the chosen time was taken in the meantime (409).
const String kSlotTakenMessage = "Kechirasiz, bu vaqt band bo'ldi. Iltimos, boshqa vaqtni tanlang.";

/// Services a consumer can book online: active and online-bookable.
List<Service> bookableServices(StorefrontData s) =>
    [for (final x in s.services) if (x.isActive && x.onlineBookable) x];

/// Staff a consumer can pick: active.
List<Staff> activeStaff(StorefrontData s) => [for (final x in s.staff) if (x.isActive) x];

/// Name rule on the confirm step: empty is fine (the server keeps the account name); else 2..64.
String? validateSlotName(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (v.length < 2 || v.length > 64) return "Ism 2 dan 64 belgigacha bo'lishi kerak.";
  return null;
}

/// Name max length (confirm step).
const int kSlotNameMax = 64;

/// Notes limit (server side too).
const int kSlotNotesMax = 500;

const Object _keep = Object();

@immutable
final class SlotFlowState {
  const SlotFlowState({
    this.initialized = false,
    this.step = SlotStep.service,
    this.service,
    this.staff,
    required this.date,
    this.slot,
    this.name = '',
    this.notes = '',
    this.idempotencyKey,
    this.submitting = false,
    this.submitError,
  });

  /// False until [SlotFlowController.init] ran with the storefront.
  final bool initialized;
  final SlotStep step;
  final Service? service;
  final Staff? staff;

  /// Default `Dates.todayLocal(timezone: tz)`.
  final LocalDate date;
  final AvailabilitySlot? slot;
  final String name;
  final String notes;

  /// Created when entering confirm; cleared when service/staff/slot change.
  final String? idempotencyKey;
  final bool submitting;
  final Object? submitError;

  /// 1-based step number for [StepHeader].
  int get stepNumber => step.index + 1;

  SlotFlowState copyWith({
    bool? initialized,
    SlotStep? step,
    Object? service = _keep,
    Object? staff = _keep,
    LocalDate? date,
    Object? slot = _keep,
    String? name,
    String? notes,
    Object? idempotencyKey = _keep,
    bool? submitting,
    Object? submitError = _keep,
  }) =>
      SlotFlowState(
        initialized: initialized ?? this.initialized,
        step: step ?? this.step,
        service: identical(service, _keep) ? this.service : service as Service?,
        staff: identical(staff, _keep) ? this.staff : staff as Staff?,
        date: date ?? this.date,
        slot: identical(slot, _keep) ? this.slot : slot as AvailabilitySlot?,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        idempotencyKey: identical(idempotencyKey, _keep) ? this.idempotencyKey : idempotencyKey as String?,
        submitting: submitting ?? this.submitting,
        submitError: identical(submitError, _keep) ? this.submitError : submitError,
      );
}

/// Family key = slug. `init(storefront, {serviceId, staffId})` is called once after the
/// storefront loads.
final slotFlowProvider =
    NotifierProvider.autoDispose.family<SlotFlowController, SlotFlowState, String>(SlotFlowController.new);

class SlotFlowController extends Notifier<SlotFlowState> {
  SlotFlowController(this.slug);

  final String slug;

  List<Service> _services = const [];
  List<Staff> _staff = const [];
  String _tz = Dates.defaultTimezone;

  /// A rebook staff that waits for the service to be picked.
  Staff? _pendingStaff;

  /// Whether the staff step was skipped because only one active staff exists.
  bool _staffAutoPicked = false;

  @override
  SlotFlowState build() => SlotFlowState(date: Dates.todayLocal());

  /// The business timezone (after [init]).
  String get timezone => _tz;

  /// First day of the strip.
  LocalDate get today => Dates.todayLocal(timezone: _tz);

  /// Last day of the strip.
  LocalDate get lastDay => today.addDays(kSlotDayStrip - 1);

  /// Runs once; later calls are ignored. Invalid rebook ids are ignored silently.
  void init(StorefrontData storefront, {int? serviceId, int? staffId}) {
    if (state.initialized) return;
    _services = bookableServices(storefront);
    _staff = activeStaff(storefront);
    _tz = storefront.business.timezone;
    final service = _services.where((s) => s.id == serviceId).firstOrNull;
    final staff = _staff.where((s) => s.id == staffId).firstOrNull;
    final name = ref.read(currentConsumerProvider)?.name?.trim() ?? '';
    final base = SlotFlowState(initialized: true, date: today, name: name);
    if (service != null && staff != null) {
      _staffAutoPicked = _staff.length == 1;
      state = base.copyWith(step: SlotStep.datetime, service: service, staff: staff);
    } else if (service != null) {
      state = base;
      pickService(service);
    } else if (staff != null) {
      _pendingStaff = staff;
      state = base.copyWith(staff: staff);
    } else {
      state = base;
    }
  }

  /// -> staff step; auto-picks and skips to datetime when exactly 1 active staff (or a rebook
  /// staff waits).
  void pickService(Service s) {
    final pending = _pendingStaff;
    _pendingStaff = null;
    final next = state.copyWith(service: s, slot: null, idempotencyKey: null, submitError: null);
    if (_staff.length == 1) {
      _staffAutoPicked = true;
      state = next.copyWith(staff: _staff.first, step: SlotStep.datetime);
    } else if (pending != null) {
      _staffAutoPicked = false;
      state = next.copyWith(staff: pending, step: SlotStep.datetime);
    } else {
      _staffAutoPicked = false;
      state = next.copyWith(step: SlotStep.staff);
    }
  }

  /// -> datetime.
  void pickStaff(Staff m) {
    state = state.copyWith(staff: m, slot: null, idempotencyKey: null, submitError: null, step: SlotStep.datetime);
  }

  void pickDate(LocalDate d) {
    if (d.isBefore(today) || d.isAfter(lastDay)) return;
    if (d == state.date) return;
    state = state.copyWith(date: d, slot: null, idempotencyKey: null, submitError: null);
  }

  /// -> confirm, with a fresh idempotency key.
  void pickSlot(AvailabilitySlot slot) {
    state = state.copyWith(
      slot: slot,
      idempotencyKey: Idempotency.newKey(),
      submitError: null,
      step: SlotStep.confirm,
    );
  }

  /// The previous step. Returns false on the first step (the caller pops).
  bool back() {
    if (state.submitting) return true;
    switch (state.step) {
      case SlotStep.service:
        return false;
      case SlotStep.staff:
        state = state.copyWith(step: SlotStep.service, submitError: null);
      case SlotStep.datetime:
        state = state.copyWith(
          step: _staffAutoPicked ? SlotStep.service : SlotStep.staff,
          slot: null,
          idempotencyKey: null,
          submitError: null,
        );
      case SlotStep.confirm:
        state = state.copyWith(step: SlotStep.datetime, slot: null, idempotencyKey: null, submitError: null);
    }
    return true;
  }

  void setName(String v) => state = state.copyWith(name: v);

  void setNotes(String v) => state = state.copyWith(notes: v);

  /// Clears the alert shown under the form.
  void clearError() => state = state.copyWith(submitError: null);

  /// The availability key for the current service/staff/date (null before both are picked).
  ({int staffId, int serviceId, LocalDate date})? get availabilityKey {
    final s = state.service;
    final m = state.staff;
    if (s == null || m == null) return null;
    return (staffId: m.id, serviceId: s.id, date: state.date);
  }

  /// POST /v1/consumer/appointments. Success -> the appointment (bookings revision bumped).
  /// Failures set [SlotFlowState.submitError] and adjust the step (409/400 -> datetime).
  Future<Appointment?> submit() async {
    final s = state;
    final service = s.service;
    final staff = s.staff;
    final slot = s.slot;
    if (s.submitting || service == null || staff == null || slot == null) return null;
    final key = s.idempotencyKey ?? Idempotency.newKey();
    final notes = s.notes.trim();
    final name = s.name.trim();
    // Read before the await: the flow may be disposed (user left) before the server answers.
    final revision = ref.read(bookingsRevisionProvider.notifier);
    state = s.copyWith(submitting: true, submitError: null, idempotencyKey: key);
    try {
      final res = await ref.read(apiProvider).request<Appointment>(
            'POST',
            Endpoints.consumerAppointments,
            body: ConsumerBookingRequest.slot(
              staffId: staff.id,
              serviceId: service.id,
              startsAt: slot.startUtc,
              notes: notes.isEmpty ? null : notes,
              name: name.isEmpty ? null : name,
            ).toJson(),
            idempotencyKey: key,
            decode: (d) => Appointment.fromJson(JsonRead.object(d)),
          );
      revision.bump();
      if (!ref.mounted) return res.data;
      state = state.copyWith(submitting: false);
      return res.data;
    } on Object catch (e) {
      if (!ref.mounted) return null;
      final availability = (staffId: staff.id, serviceId: service.id, date: state.date);
      if (e is ApiException && e.isConflict) {
        state = state.copyWith(
          submitting: false,
          submitError: null,
          slot: null,
          idempotencyKey: null,
          step: SlotStep.datetime,
        );
        ref.invalidate(slotAvailabilityProvider(availability));
        showSnack(kSlotTakenMessage);
      } else if (e is ApiException && e.status == 400) {
        state = state.copyWith(
          submitting: false,
          submitError: e,
          slot: null,
          idempotencyKey: null,
          step: SlotStep.datetime,
        );
        ref.invalidate(slotAvailabilityProvider(availability));
      } else {
        // 403/404 (closed or gone), 422 (fields), network/5xx (retry keeps the key).
        state = state.copyWith(submitting: false, submitError: e);
      }
      return null;
    }
  }
}

/// GET /v1/staff/{id}/availability?date=&service_id= (no token).
final slotAvailabilityProvider =
    FutureProvider.autoDispose.family<Availability, ({int staffId, int serviceId, LocalDate date})>((ref, k) {
  return ref.read(apiProvider).get<Availability>(
        Endpoints.availability(k.staffId),
        query: ApiQuery.availability(date: k.date, serviceId: k.serviceId),
        auth: RequestAuth.none,
        decode: (d) => Availability.fromJson(JsonRead.object(d)),
      );
});
