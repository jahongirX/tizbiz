import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The steps of the rental (wedding hall) flow, in order.
enum RentalStep { session, guests, date, confirm }

/// The step titles under the StepHeader.
String rentalStepTitle(RentalStep s) => switch (s) {
      RentalStep.session => 'Vaqt',
      RentalStep.guests => 'Mehmonlar',
      RentalStep.date => 'Sana',
      RentalStep.confirm => 'Tasdiqlash',
    };

/// Snackbar after a 409 on submit.
const String rentalConflictMessage = "Kechirasiz, bu sana band bo'ldi. Iltimos, boshqa sanani tanlang.";

/// Shown when the storefront has no hall (staff) or no hall service.
const String rentalNoHallMessage = "Zal resursi topilmadi. Iltimos, biznesga qo'ng'iroq qiling.";

/// The clock of this flow (tests override it to pin "today").
final rentalNowProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Today in the business timezone.
LocalDate rentalToday(DateTime Function() now, String? timezone) =>
    Dates.todayLocal(timezone: timezone, now: now());

/// The last bookable day (web CalendarStep HORIZON_DAYS).
LocalDate rentalHorizonEnd(LocalDate today) => today.addDays(RentalPricing.horizonDays);

/// The hall: the first active staff, else the first staff (web RentalEngineApp.vue:22-25).
Staff? rentalHall(StorefrontData s) {
  for (final m in s.staff) {
    if (m.isActive) return m;
  }
  return s.staff.isEmpty ? null : s.staff.first;
}

/// The hall package: the first active + online-bookable service, else the first active, else the first.
Service? rentalHallService(StorefrontData s) {
  for (final v in s.services) {
    if (v.isActive && v.onlineBookable) return v;
  }
  for (final v in s.services) {
    if (v.isActive) return v;
  }
  return s.services.isEmpty ? null : s.services.first;
}

const Object _keep = Object();

@immutable
final class RentalFlowState {
  const RentalFlowState({
    this.step = RentalStep.session,
    this.session,
    this.guests = RentalPricing.defaultGuests,
    this.date,
    required this.visibleMonth,
    this.notes = '',
    this.idempotencyKey,
    this.submitting = false,
    this.submitError,
  });

  final RentalStep step;
  final RentalSession? session;

  /// The raw stepper value; clamped on blur and on continue.
  final int guests;
  final LocalDate? date;

  /// The first of the month shown by the calendar.
  final LocalDate visibleMonth;
  final String notes;

  /// Created when entering confirm; cleared when the session or the date changes.
  final String? idempotencyKey;
  final bool submitting;

  /// The last submit failure that stays on the confirm step (403, 404, network, 422, 5xx).
  final Object? submitError;

  /// [guests] within RentalPricing.minGuests..maxGuests.
  int get clampedGuests => RentalPricing.clampGuests(guests);

  RentalFlowState copyWith({
    RentalStep? step,
    Object? session = _keep,
    int? guests,
    Object? date = _keep,
    LocalDate? visibleMonth,
    String? notes,
    Object? idempotencyKey = _keep,
    bool? submitting,
    Object? submitError = _keep,
  }) =>
      RentalFlowState(
        step: step ?? this.step,
        session: identical(session, _keep) ? this.session : session as RentalSession?,
        guests: guests ?? this.guests,
        date: identical(date, _keep) ? this.date : date as LocalDate?,
        visibleMonth: visibleMonth ?? this.visibleMonth,
        notes: notes ?? this.notes,
        idempotencyKey: identical(idempotencyKey, _keep) ? this.idempotencyKey : idempotencyKey as String?,
        submitting: submitting ?? this.submitting,
        submitError: identical(submitError, _keep) ? this.submitError : submitError,
      );
}

/// Family key = slug.
final rentalFlowProvider =
    NotifierProvider.autoDispose.family<RentalFlowController, RentalFlowState, String>(RentalFlowController.new);

class RentalFlowController extends Notifier<RentalFlowState> {
  RentalFlowController(this.slug);

  final String slug;

  late LocalDate _today;

  LocalDate get today => _today;

  /// The first of today's month (the calendar cannot go earlier).
  LocalDate get firstMonth => _today.firstOfMonth;

  /// The first of the horizon's month (the calendar cannot go later).
  LocalDate get lastMonth => rentalHorizonEnd(_today).firstOfMonth;

  @override
  RentalFlowState build() {
    final tz = ref.read(storefrontProvider(slug)).value?.business.timezone;
    _today = rentalToday(ref.read(rentalNowProvider), tz);
    return RentalFlowState(visibleMonth: _today.firstOfMonth);
  }

  /// Session step -> guests. Changing the session drops a picked date (it may be taken for the other one).
  void pickSession(RentalSession s) {
    final changed = state.session != s;
    state = state.copyWith(
      session: s,
      step: RentalStep.guests,
      date: changed ? null : _keep,
      idempotencyKey: changed ? null : _keep,
      submitError: null,
    );
  }

  /// The raw value (typing, ±); clamped by [clampGuests] / [submitGuests].
  void setGuests(int n) => state = state.copyWith(guests: n < 0 ? 0 : n);

  void stepGuests(int delta) => setGuests(RentalPricing.clampGuests(state.guests + delta));

  /// On blur.
  void clampGuests() {
    if (state.guests != state.clampedGuests) state = state.copyWith(guests: state.clampedGuests);
  }

  /// Guests step -> date (clamped).
  void submitGuests() {
    if (state.session == null) {
      state = state.copyWith(step: RentalStep.session);
      return;
    }
    state = state.copyWith(guests: state.clampedGuests, step: RentalStep.date, idempotencyKey: null);
  }

  /// Date step -> confirm with a new Idempotency-Key.
  void pickDate(LocalDate d) {
    if (d.isBefore(_today) || d.isAfter(rentalHorizonEnd(_today))) return;
    state = state.copyWith(
      date: d,
      visibleMonth: d.firstOfMonth,
      step: RentalStep.confirm,
      idempotencyKey: Idempotency.newKey(),
      submitError: null,
    );
  }

  bool get canPrevMonth => state.visibleMonth.isAfter(firstMonth);

  bool get canNextMonth => state.visibleMonth.isBefore(lastMonth);

  void prevMonth() {
    if (canPrevMonth) state = state.copyWith(visibleMonth: state.visibleMonth.addMonths(-1).firstOfMonth);
  }

  void nextMonth() {
    if (canNextMonth) state = state.copyWith(visibleMonth: state.visibleMonth.addMonths(1).firstOfMonth);
  }

  void setNotes(String v) => state = state.copyWith(notes: v);

  /// The previous step. Returns false on the first step (the caller pops the route).
  bool back() {
    if (state.submitting) return true;
    final prev = switch (state.step) {
      RentalStep.session => null,
      RentalStep.guests => RentalStep.session,
      RentalStep.date => RentalStep.guests,
      RentalStep.confirm => RentalStep.date,
    };
    if (prev == null) return false;
    state = state.copyWith(step: prev, submitError: null);
    return true;
  }

  /// POST /v1/consumer/appointments (rental body) with the Idempotency-Key.
  ///
  /// Success -> bumps the bookings revision and returns the appointment (the screen navigates).
  /// 409 / 400 -> snackbar, the date and the key are cleared, back to the date step, booked days refetched.
  /// Anything else -> [RentalFlowState.submitError] (a network retry reuses the same key).
  Future<Appointment?> submit(StorefrontData s) async {
    if (state.submitting) return null;
    final hall = rentalHall(s);
    final service = rentalHallService(s);
    final session = state.session;
    final date = state.date;
    if (hall == null || service == null) {
      state = state.copyWith(submitError: const _NoHall());
      return null;
    }
    if (session == null) {
      state = state.copyWith(step: RentalStep.session);
      return null;
    }
    if (date == null) {
      state = state.copyWith(step: RentalStep.date);
      return null;
    }
    final key = state.idempotencyKey ?? Idempotency.newKey();
    final guests = state.clampedGuests;
    final notes = state.notes.trim();
    // Read before the await: the flow may be disposed (user left) before the server answers.
    final revision = ref.read(bookingsRevisionProvider.notifier);
    state = state.copyWith(submitting: true, submitError: null, idempotencyKey: key, guests: guests);

    try {
      final res = await ref.read(apiProvider).request<Appointment>(
            'POST',
            Endpoints.consumerAppointments,
            body: ConsumerBookingRequest.rental(
              staffId: hall.id,
              serviceId: service.id,
              date: date,
              session: session,
              guests: guests,
              notes: notes.isEmpty ? null : notes,
            ).toJson(),
            idempotencyKey: key,
            decode: (d) => Appointment.fromJson(JsonRead.object(d)),
          );
      revision.bump();
      if (!ref.mounted) return res.data;
      state = state.copyWith(submitting: false);
      return res.data;
    } on ApiException catch (e) {
      if (!ref.mounted) return null;
      if (e.isConflict || e.status == 400) {
        showSnack(e.isConflict ? rentalConflictMessage : e.message);
        state = state.copyWith(
          submitting: false,
          date: null,
          idempotencyKey: null,
          step: RentalStep.date,
          submitError: null,
        );
        ref.invalidate(bookedDaysProvider(slug));
        return null;
      }
      state = state.copyWith(submitting: false, submitError: e);
      return null;
    } on Object catch (e) {
      if (!ref.mounted) return null;
      state = state.copyWith(submitting: false, submitError: e);
      return null;
    }
  }
}

/// A submit attempted without a hall resource.
final class _NoHall implements Exception {
  const _NoHall();

  @override
  String toString() => rentalNoHallMessage;
}

/// Whether [e] is the "no hall resource" submit error.
bool isRentalNoHall(Object? e) => e is _NoHall;

/// GET Endpoints.siteBookedDays(slug)?from=today&to=today+horizon (business-local days), no token.
/// `{"booked": {"YYYY-MM-DD": ["morning","evening"]}}`; `{}` / `[]` when empty.
final bookedDaysProvider = FutureProvider.autoDispose.family<BookedDays, String>((ref, slug) async {
  final store = await ref.watch(storefrontProvider(slug).future);
  final today = rentalToday(ref.read(rentalNowProvider), store.business.timezone);
  return ref.read(apiProvider).get<BookedDays>(
        Endpoints.siteBookedDays(slug),
        query: ApiQuery.localDays(from: today, to: rentalHorizonEnd(today)),
        auth: RequestAuth.none,
        decode: (d) {
          final m = JsonRead.objectOrNull(d);
          return m == null ? const BookedDays() : BookedDays.fromJson(m);
        },
      );
});
