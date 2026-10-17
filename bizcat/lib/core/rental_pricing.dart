import 'package:tizbiz_core/tizbiz_core.dart';

/// The web's rental display estimate (apps/booking RentalEngineApp.vue, GuestCountStep.vue).
/// The server stores no rental price.
abstract final class RentalPricing {
  static const int seatsPerTable = 10, minGuests = 30, maxGuests = 1000, guestStep = 10, defaultGuests = 100;

  /// Web CalendarStep HORIZON_DAYS; the booked-days default range.
  static const int horizonDays = 120;

  /// morning 1 500 000 tiyin (15 000 so'm), evening 2 500 000 tiyin (25 000 so'm) per guest.
  static int perGuestTiyin(RentalSession s) => switch (s) {
        RentalSession.morning => 1500000,
        RentalSession.evening => 2500000,
      };

  static int tables(int guests) => (guests / seatsPerTable).ceil();

  static int totalTiyin(RentalSession s, int guests) => perGuestTiyin(s) * guests;

  /// To [minGuests]..[maxGuests].
  static int clampGuests(int g) => g < minGuests ? minGuests : (g > maxGuests ? maxGuests : g);

  static String title(RentalSession s) => switch (s) {
        RentalSession.morning => 'Ertalab',
        RentalSession.evening => 'Kechqurun',
      };

  static String subtitle(RentalSession s) => switch (s) {
        RentalSession.morning => 'Kunduzgi bazm · ${hours(s)}',
        RentalSession.evening => "Kechki to'y · ${hours(s)}",
      };

  static String hours(RentalSession s) => switch (s) {
        RentalSession.morning => '10:00–16:00',
        RentalSession.evening => '18:00–23:00',
      };

  /// From an appointment's business-local start/end: 10-16 -> morning; start 18 -> evening;
  /// 10-23 (full day) and anything else -> null.
  static RentalSession? sessionOf(Appointment a, String timezone) {
    final start = a.startLocal(timezone);
    final end = a.endLocal(timezone);
    if (start.hour == 18) return RentalSession.evening;
    if (start.hour == 10 && end.hour == 16) return RentalSession.morning;
    return null;
  }
}
